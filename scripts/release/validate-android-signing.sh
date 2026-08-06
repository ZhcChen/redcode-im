#!/usr/bin/env bash
set -euo pipefail

publish_release="${PUBLISH_RELEASE:-false}"

die() {
  printf '[android-signing] %s\n' "$*" >&2
  exit 1
}

[[ "$publish_release" == "true" || "$publish_release" == "false" ]] ||
  die "PUBLISH_RELEASE 必须是 true 或 false"

if [[ "$publish_release" == "false" ]]; then
  printf 'unsigned\n'
  exit 0
fi

missing=()
for name in \
  ANDROID_SIGNING_KEYSTORE_BASE64 \
  ANDROID_SIGNING_STORE_PASSWORD \
  ANDROID_SIGNING_KEY_ALIAS \
  ANDROID_SIGNING_KEY_PASSWORD; do
  [[ -n "${!name:-}" ]] || missing+=("$name")
done

if (( ${#missing[@]} > 0 )); then
  die "正式发布缺少 Android signing secrets：${missing[*]}"
fi

printf 'signed\n'
