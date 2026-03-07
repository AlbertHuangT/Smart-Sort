#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift_rpcs=$(
  rg --files -0 'Smart Sort' -g '*.swift' \
    | xargs -0 perl -0ne 'while (/rpc\s*\(\s*"([A-Za-z0-9_]+)"/g) { print lc($1), "\n"; }' \
    | sort -u
)

sql_functions=$(
  rg -n "create\s+or\s+replace\s+function" supabase/migrations -i \
    | sed -E 's/.*create[[:space:]]+or[[:space:]]+replace[[:space:]]+function[[:space:]]+((public\.)?[a-zA-Z0-9_]+).*/\1/I' \
    | sed 's/^public\.//' \
    | tr 'A-Z' 'a-z' \
    | sort -u
)

sql_signatures=$(
  rg -n "create\s+or\s+replace\s+function" supabase/migrations -i \
    | awk '
        {
          if (match($0, /function[[:space:]]+((public\.)?[A-Za-z0-9_]+)[[:space:]]*\(([^)]*)\)/)) {
            signature = substr($0, RSTART, RLENGTH)
            sub(/^.*function[[:space:]]+/, "", signature)
            name = signature
            sub(/[[:space:]]*\(.*/, "", name)
            gsub(/^public\./, "", name)

            params = signature
            sub(/^.*\(/, "", params)
            sub(/\).*/, "", params)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", params)

            arity = 0
            if (params != "") {
              arity = split(params, pieces, /,[[:space:]]*/)
            }

            printf "%s|%s|%s\n", tolower(name), arity, $0
          }
        }
      ' \
    | sort -u
)

overloaded_functions=$(
  printf "%s\n" "$sql_signatures" \
    | cut -d'|' -f1 \
    | sort \
    | uniq -d \
    || true
)

direct_table_access=$(
  rg --files -0 'Smart Sort' -g '*.swift' \
    | xargs -0 perl -0ne 'while (/\.from\s*\(\s*"([A-Za-z0-9_-]+)"/g) { print $1, "\n"; }' \
    | sort -u
)

high_risk_direct_table_access=$(
  rg --files -0 'Smart Sort' -g '*.swift' \
    | xargs -0 perl -0ne '
        while (/\.from\s*\(\s*"(profiles|user_community_memberships|event_registrations|user_achievements|community_events|credit_grants|arena_challenges|quiz_questions)"/g) {
          print "$ARGV:$1\n";
        }
      ' || true
)

set_diff() {
  comm -23 <(printf "%s\n" "$1" | sed '/^$/d' | sort -u) <(printf "%s\n" "$2" | sed '/^$/d' | sort -u)
}

echo "=== Backend Contract Check ==="
echo

echo "Swift RPC count: $(printf "%s\n" "$swift_rpcs" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "Supabase migration function count: $(printf "%s\n" "$sql_functions" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "Direct table access count: $(printf "%s\n" "$direct_table_access" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "Overloaded SQL function names: $(printf "%s\n" "$overloaded_functions" | sed '/^$/d' | wc -l | tr -d ' ')"
echo

echo "-- Swift RPCs missing in supabase/migrations --"
missing_in_sql="$(set_diff "$swift_rpcs" "$sql_functions" || true)"
if [[ -n "$missing_in_sql" ]]; then
  printf "%s\n" "$missing_in_sql"
else
  echo "(none)"
fi

echo
echo "-- SQL functions not called by any Swift RPC --"
unused_sql="$(set_diff "$sql_functions" "$swift_rpcs" || true)"
if [[ -n "$unused_sql" ]]; then
  printf "%s\n" "$unused_sql"
else
  echo "(none)"
fi

echo
echo "-- Direct table access in Swift --"
if [[ -n "$direct_table_access" ]]; then
  printf "%s\n" "$direct_table_access"
else
  echo "(none)"
fi

echo
echo "-- Overloaded SQL functions (manual signature review) --"
if [[ -n "$overloaded_functions" ]]; then
  while IFS= read -r fn; do
    [[ -z "$fn" ]] && continue
    printf "%s\n" "$fn"
    printf "%s\n" "$sql_signatures" | awk -F'|' -v fn="$fn" '$1 == fn { printf "  arity=%s  %s\n", $2, $3 }'
  done <<< "$overloaded_functions"
else
  echo "(none)"
fi

echo
echo "-- High-risk direct table access (should usually be RPC-backed) --"
if [[ -n "$high_risk_direct_table_access" ]]; then
  printf "%s\n" "$high_risk_direct_table_access"
else
  echo "(none)"
fi

echo
echo "Note: this script checks RPC-name drift, flags direct table access, and surfaces overloaded SQL functions for manual signature review. It still does not prove full signature compatibility or RLS safety."

if [[ -n "$missing_in_sql" || -n "$high_risk_direct_table_access" ]]; then
  exit 1
fi
