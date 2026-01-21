#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  echo "Env file already exists: $ENV_FILE"
  exit 0
fi

read -r -p "TG_BOT_TOKEN: " token
read -r -p "TG_CHAT_ID: " chat_id

if [[ -z "$token" || -z "$chat_id" ]]; then
  echo "ERROR: TG_BOT_TOKEN and TG_CHAT_ID are required" >&2
  exit 1
fi

cat > "$ENV_FILE" <<EOF_ENV
TG_BOT_TOKEN=$token
TG_CHAT_ID=$chat_id
EOF_ENV

chmod 600 "$ENV_FILE"
echo "Env file written: $ENV_FILE"
