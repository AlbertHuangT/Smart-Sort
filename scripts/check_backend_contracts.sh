#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift_rpcs=$(rg -o 'rpc\("[a-zA-Z0-9_]+' -n 'The Trash' \
  | sed -E 's/.*rpc\("//' \
  | tr 'A-Z' 'a-z' \
  | sort -u)

sql_functions_supabase=$(rg -n "create\s+or\s+replace\s+function" supabase/migrations -i \
  | sed -E 's/.*create[[:space:]]+or[[:space:]]+replace[[:space:]]+function[[:space:]]+((public\.)?[a-zA-Z0-9_]+).*/\1/I' \
  | sed 's/^public\.//' \
  | tr 'A-Z' 'a-z' \
  | sort -u)

sql_functions_app_mirror=$(rg -n "create\s+or\s+replace\s+function" 'The Trash/migrations' -i \
  | sed -E 's/.*create[[:space:]]+or[[:space:]]+replace[[:space:]]+function[[:space:]]+((public\.)?[a-zA-Z0-9_]+).*/\1/I' \
  | sed 's/^public\.//' \
  | tr 'A-Z' 'a-z' \
  | sort -u)

# Helper to print sorted set difference A - B
set_diff() {
  comm -23 <(printf "%s\n" "$1" | sed '/^$/d' | sort -u) <(printf "%s\n" "$2" | sed '/^$/d' | sort -u)
}

echo "=== Backend Contract Check ==="
echo

echo "Swift RPC count: $(printf "%s\n" "$swift_rpcs" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "Supabase migration function count: $(printf "%s\n" "$sql_functions_supabase" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "App mirror migration function count: $(printf "%s\n" "$sql_functions_app_mirror" | sed '/^$/d' | wc -l | tr -d ' ')"
echo

echo "-- RPCs missing in supabase/migrations --"
missing_in_supabase=$(set_diff "$swift_rpcs" "$sql_functions_supabase" || true)
if [[ -n "${missing_in_supabase}" ]]; then
  printf "%s\n" "$missing_in_supabase"
else
  echo "(none)"
fi

echo
echo "-- RPCs missing in app mirror migrations (The Trash/migrations) --"
missing_in_app_mirror=$(set_diff "$swift_rpcs" "$sql_functions_app_mirror" || true)
if [[ -n "${missing_in_app_mirror}" ]]; then
  printf "%s\n" "$missing_in_app_mirror"
else
  echo "(none)"
fi

echo
echo "-- Mirror-only functions not used by current Swift RPC calls --"
unused_mirror=$(set_diff "$sql_functions_app_mirror" "$swift_rpcs" || true)
if [[ -n "${unused_mirror}" ]]; then
  printf "%s\n" "$unused_mirror"
else
  echo "(none)"
fi
