#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

usage() {
  cat <<'USAGE'
Usage:
  scripts/notify_tg.sh --title "..." --message "..." [--project "..."] [--event "..."] [--dry-run]

Options:
  --title     Message title
  --message   Message body
  --project   Optional project name
  --event     Optional event name
  --dry-run   Print message without sending
USAGE
}

err() {
  echo "ERROR: $*" >&2
}

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
  fi
}

TITLE=""
MESSAGE=""
PROJECT=""
EVENT=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      TITLE="${2:-}"
      shift 2
      ;;
    --message)
      MESSAGE="${2:-}"
      shift 2
      ;;
    --project)
      PROJECT="${2:-}"
      shift 2
      ;;
    --event)
      EVENT="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      usage
      exit 2
      ;;
  esac

done

if [[ -z "$TITLE" && -z "$MESSAGE" ]]; then
  err "Missing --title or --message"
  usage
  exit 2
fi

if [[ ! -f "$ENV_FILE" ]]; then
  err "Missing .env. Please run scripts/setup_tg_env.sh first."
  err "Expected path: $ENV_FILE"
  exit 2
fi

load_env

if [[ -z "${TG_BOT_TOKEN:-}" || -z "${TG_CHAT_ID:-}" ]]; then
  err "TG_BOT_TOKEN or TG_CHAT_ID is not set"
  exit 2
fi

lines=()
if [[ -n "$TITLE" ]]; then
  lines+=("$TITLE")
fi
if [[ -n "$PROJECT" ]]; then
  lines+=("Project: $PROJECT")
fi
if [[ -n "$EVENT" ]]; then
  lines+=("Event: $EVENT")
fi
if [[ -n "$MESSAGE" ]]; then
  lines+=("")
  lines+=("$MESSAGE")
fi

text="$(printf "%s\n" "${lines[@]}")"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf "%s\n" "$text"
  exit 0
fi

api="https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage"
response="$(curl -sS -X POST "$api" \
  --data "chat_id=${TG_CHAT_ID}" \
  --data-urlencode "text=${text}")"

if echo "$response" | grep -q '"ok":true'; then
  exit 0
fi

err "Telegram API request failed"
err "$response"
exit 1
