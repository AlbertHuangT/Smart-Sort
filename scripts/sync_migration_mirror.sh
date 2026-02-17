#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SUPABASE_MIGRATIONS_DIR="supabase/migrations"
APP_MIRROR_MIGRATIONS_DIR="The Trash/migrations"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: scripts/sync_migration_mirror.sh [--dry-run]

Options:
  --dry-run  Print actions without copying files.
  -h, --help Show this help.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
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

for cmd in find basename sort cmp cp mktemp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 2
  fi
done

list_sql_files() {
  local source_dir="$1"
  find "$source_dir" -maxdepth 1 -type f -name '*.sql' -exec basename {} \; | sort
}

supabase_files="$(mktemp)"
trap 'rm -f "$supabase_files"' EXIT
list_sql_files "$SUPABASE_MIGRATIONS_DIR" > "$supabase_files"

created_count=0
updated_count=0

while IFS= read -r migration_name; do
  src="$SUPABASE_MIGRATIONS_DIR/$migration_name"
  dst="$APP_MIRROR_MIGRATIONS_DIR/$migration_name"

  if [[ ! -f "$dst" ]]; then
    echo "ADD    $migration_name"
    created_count=$((created_count + 1))
    if [[ "$DRY_RUN" -eq 0 ]]; then
      cp "$src" "$dst"
    fi
    continue
  fi

  if ! cmp -s "$src" "$dst"; then
    echo "UPDATE $migration_name"
    updated_count=$((updated_count + 1))
    if [[ "$DRY_RUN" -eq 0 ]]; then
      cp "$src" "$dst"
    fi
  fi
done < "$supabase_files"

echo
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run complete."
else
  echo "Sync complete."
fi
echo "Added: $created_count"
echo "Updated: $updated_count"
