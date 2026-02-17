#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SUPABASE_MIGRATIONS_DIR="supabase/migrations"
APP_MIRROR_MIGRATIONS_DIR="The Trash/migrations"
STRICT_MODE=0

usage() {
  cat <<'EOF'
Usage: scripts/check_migration_mirror.sh [--strict]

Options:
  --strict  Exit with non-zero status if mirror drift is detected.
  -h, --help  Show this help.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --strict)
      STRICT_MODE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for cmd in find basename sort comm cmp mktemp wc; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 2
  fi
done

cleanup_files=()
register_tmp() {
  cleanup_files+=("$1")
}
cleanup() {
  if [[ ${#cleanup_files[@]} -gt 0 ]]; then
    rm -f "${cleanup_files[@]}"
  fi
}
trap cleanup EXIT

list_sql_files() {
  local source_dir="$1"
  find "$source_dir" -maxdepth 1 -type f -name '*.sql' -exec basename {} \; | sort
}

supabase_files="$(mktemp)"
register_tmp "$supabase_files"
list_sql_files "$SUPABASE_MIGRATIONS_DIR" > "$supabase_files"

mirror_files="$(mktemp)"
register_tmp "$mirror_files"
list_sql_files "$APP_MIRROR_MIGRATIONS_DIR" > "$mirror_files"

missing_in_mirror_file="$(mktemp)"
register_tmp "$missing_in_mirror_file"
comm -23 "$supabase_files" "$mirror_files" > "$missing_in_mirror_file"

extra_in_mirror_file="$(mktemp)"
register_tmp "$extra_in_mirror_file"
comm -13 "$supabase_files" "$mirror_files" > "$extra_in_mirror_file"

content_mismatch_file="$(mktemp)"
register_tmp "$content_mismatch_file"
while IFS= read -r migration_name; do
  supabase_path="$SUPABASE_MIGRATIONS_DIR/$migration_name"
  mirror_path="$APP_MIRROR_MIGRATIONS_DIR/$migration_name"
  if [[ -f "$mirror_path" ]] && ! cmp -s "$supabase_path" "$mirror_path"; then
    printf "%s\n" "$migration_name" >> "$content_mismatch_file"
  fi
done < "$supabase_files"

echo "=== Migration Mirror Check ==="
echo
echo "supabase/migrations SQL count: $(wc -l < "$supabase_files" | tr -d ' ')"
echo "The Trash/migrations SQL count: $(wc -l < "$mirror_files" | tr -d ' ')"
echo

drift_detected=0
print_diff() {
  local title="$1"
  local diff_file="$2"
  local fail_on_drift="${3:-0}"
  echo "-- $title --"
  if [[ -s "$diff_file" ]]; then
    cat "$diff_file"
    if [[ "$fail_on_drift" -eq 1 ]]; then
      drift_detected=1
    fi
  else
    echo "(none)"
  fi
  echo
}

print_diff "Missing in app mirror (present in supabase/migrations)" "$missing_in_mirror_file" 1
print_diff "Extra in app mirror (absent in supabase/migrations)" "$extra_in_mirror_file" 0
print_diff "Same-name migrations with different content" "$content_mismatch_file" 1

if [[ "$STRICT_MODE" -eq 1 && "$drift_detected" -eq 1 ]]; then
  echo "Strict mode enabled: mirror drift detected."
  exit 1
fi

if [[ "$STRICT_MODE" -eq 1 ]]; then
  echo "Strict mode enabled: mirror is in sync."
fi
