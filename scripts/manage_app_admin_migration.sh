#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATIONS_DIR="$ROOT_DIR/supabase/migrations"

usage() {
  cat <<'EOF'
Usage:
  scripts/manage_app_admin_migration.sh grant <user_uuid>
  scripts/manage_app_admin_migration.sh revoke <user_uuid>

Creates a timestamped migration that grants or revokes an app-admin entry in
public.app_admins. Review the generated SQL, then apply it with:

  supabase db push --linked --yes
EOF
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

ACTION="$1"
USER_UUID="$2"

case "$ACTION" in
  grant|revoke)
    ;;
  *)
    echo "Unsupported action: $ACTION" >&2
    usage
    exit 1
    ;;
esac

if [[ ! "$USER_UUID" =~ ^[0-9a-fA-F-]{36}$ ]]; then
  echo "Expected a UUID like xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" >&2
  exit 1
fi

TIMESTAMP="$(date +"%Y%m%d%H%M%S")"
SHORT_ID="${USER_UUID%%-*}"
FILENAME="${TIMESTAMP}_$(printf "%s" "$ACTION")_app_admin_${SHORT_ID}.sql"
FILEPATH="$MIGRATIONS_DIR/$FILENAME"

if [[ -e "$FILEPATH" ]]; then
  echo "Migration already exists: $FILEPATH" >&2
  exit 1
fi

if [[ "$ACTION" == "grant" ]]; then
  cat >"$FILEPATH" <<EOF
-- Grant app-admin access to a specific authenticated user.
INSERT INTO public.app_admins (user_id)
VALUES ('$USER_UUID')
ON CONFLICT (user_id) DO NOTHING;
EOF
else
  cat >"$FILEPATH" <<EOF
-- Revoke app-admin access from a specific authenticated user.
DELETE FROM public.app_admins
WHERE user_id = '$USER_UUID';
EOF
fi

echo "Created migration: $FILEPATH"
