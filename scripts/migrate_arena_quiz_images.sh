#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL_FILE="$ROOT_DIR/supabase/migrations/20260303100001_002_arena.sql"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

BUCKET_PATH="ss:///quiz-images/seed"

python3 - <<'PY' "$SQL_FILE" > "$TMP_DIR/mapping.tsv"
import re
import sys
from pathlib import Path

sql = Path(sys.argv[1]).read_text()
pattern = re.compile(r"\('(?P<url>https://images\.unsplash\.com/[^']+)',\s*'[^']+',\s*'(?P<name>[^']+)',\s*true\)")

def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug

for match in pattern.finditer(sql):
    url = match.group("url")
    name = match.group("name")
    slug = slugify(name)
    print(f"{name}\t{slug}\t{url}")
PY

while IFS=$'\t' read -r item_name slug url; do
    target_file="$TMP_DIR/${slug}.jpg"
    echo "Downloading $item_name"
    if ! curl -fL --retry 3 --retry-all-errors --connect-timeout 10 --max-time 30 \
        -A "Mozilla/5.0" \
        "$url" \
        -o "$target_file"; then
        echo "FAILED_DOWNLOAD $item_name $url" | tee -a "$TMP_DIR/failed.log"
        continue
    fi

    echo "Uploading $item_name"
    if ! supabase --experimental storage cp \
        "$target_file" \
        "$BUCKET_PATH/${slug}.jpg" \
        --linked \
        >/dev/null; then
        echo "FAILED_UPLOAD $item_name $url" | tee -a "$TMP_DIR/failed.log"
        continue
    fi

    printf '%s\t%s\t%s\n' "$item_name" "$slug" "$url" | tee -a "$TMP_DIR/uploaded.tsv" >/dev/null
done < "$TMP_DIR/mapping.tsv"

uploaded_count=0
failed_count=0

if [[ -f "$TMP_DIR/uploaded.tsv" ]]; then
    uploaded_count="$(wc -l < "$TMP_DIR/uploaded.tsv" | tr -d ' ')"
fi

if [[ -f "$TMP_DIR/failed.log" ]]; then
    failed_count="$(wc -l < "$TMP_DIR/failed.log" | tr -d ' ')"
fi

echo "Arena quiz image migration upload complete."
echo "Uploaded: $uploaded_count"
echo "Failed: $failed_count"

if [[ -f "$TMP_DIR/failed.log" ]]; then
    echo
    echo "Failures:"
    cat "$TMP_DIR/failed.log"
fi
