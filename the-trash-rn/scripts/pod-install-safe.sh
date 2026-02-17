#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"
LOG_FILE="${TMPDIR:-/tmp}/thetrash-pod-install.log"
MAX_ATTEMPTS="${POD_INSTALL_MAX_ATTEMPTS:-5}"

attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
  echo "[pod-install-safe] attempt ${attempt}/${MAX_ATTEMPTS}"
  if (cd "$IOS_DIR" && pod install 2>&1 | tee "$LOG_FILE"); then
    echo "[pod-install-safe] success"
    exit 0
  fi

  if grep -q "path name contains null byte" "$LOG_FILE"; then
    echo "[pod-install-safe] detected intermittent CocoaPods null-byte bug, retrying..."
    attempt=$((attempt + 1))
    sleep 1
    continue
  fi

  echo "[pod-install-safe] pod install failed for a non-null-byte reason. See: $LOG_FILE"
  exit 1
done

echo "[pod-install-safe] failed after ${MAX_ATTEMPTS} attempts. Last log: $LOG_FILE"
exit 1
