#!/usr/bin/env bash
set -euo pipefail

release_tag="${RELEASE_TAG:?RELEASE_TAG is required}"
candidate_sha="${GITHUB_SHA:?GITHUB_SHA is required}"
assets_dir="${RELEASE_ASSETS_DIR:?RELEASE_ASSETS_DIR is required}"
notes_file="${RELEASE_NOTES_FILE:?RELEASE_NOTES_FILE is required}"
release_repository="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
delete_retry_count="${RELEASE_DELETE_RETRY_COUNT:-3}"
delete_retry_delay="${RELEASE_DELETE_RETRY_DELAY_SECONDS:-1}"

if [[ -n "${RELEASE_OWNER_TOKEN:-}" ]]; then
  release_owner="$RELEASE_OWNER_TOKEN"
elif [[ "${GITHUB_ACTIONS:-}" == true \
  && -n "${GITHUB_RUN_ID:-}" \
  && -n "${GITHUB_RUN_ATTEMPT:-}" ]]; then
  release_owner="${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
else
  echo "RELEASE_OWNER_TOKEN is required outside GitHub Actions" >&2
  exit 64
fi

[[ "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]] || {
  echo "Invalid release tag: $release_tag" >&2
  exit 64
}
[[ "$candidate_sha" =~ ^[0-9a-f]{40}$ ]] || {
  echo "GITHUB_SHA must be a full lowercase Git SHA" >&2
  exit 64
}
[[ "$release_owner" =~ ^[0-9A-Za-z._:-]+$ ]] || {
  echo "RELEASE_OWNER_TOKEN contains unsupported characters" >&2
  exit 64
}
[[ "$release_repository" =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]] || {
  echo "GITHUB_REPOSITORY must be an owner/repository pair" >&2
  exit 64
}
[[ "$delete_retry_count" =~ ^[1-5]$ ]] || {
  echo "RELEASE_DELETE_RETRY_COUNT must be between 1 and 5" >&2
  exit 64
}
[[ "$delete_retry_delay" =~ ^[0-9]+$ ]] || {
  echo "RELEASE_DELETE_RETRY_DELAY_SECONDS must be a non-negative integer" >&2
  exit 64
}
[[ -d "$assets_dir" && -f "$notes_file" ]] || {
  echo "Release assets and notes must exist" >&2
  exit 66
}

shopt -s nullglob
assets=("$assets_dir"/*)
(( ${#assets[@]} > 0 )) || {
  echo "Release assets are empty" >&2
  exit 66
}

prerelease_args=()
[[ "$release_tag" != *-* ]] || prerelease_args+=(--prerelease)
owner_marker="<!-- redcode-release-owner:${release_owner} -->"
candidate_marker="<!-- redcode-release-candidate:${candidate_sha} -->"
transaction_marker="<!-- redcode-release-transaction:v1 repository=${release_repository} tag=${release_tag} candidate=${candidate_sha} -->"
draft_notes="$(mktemp "${TMPDIR:-/tmp}/redcode-release-notes.XXXXXX")"
published=false
owns_current_draft=false
release_is_draft=''
release_state_id=''
release_state_etag=''
release_state_tag=''
release_state_target=''
release_state_body=''

load_release_state() {
  local response api_status headers body state
  if response="$(gh api --include \
      -H 'Accept: application/vnd.github+json' \
      "repos/${release_repository}/releases/tags/${release_tag}" 2>&1)"; then
    api_status=0
  else
    api_status=$?
  fi
  if (( api_status != 0 )); then
    if grep -Eq '^HTTP/[0-9.]+ 404([[:space:]]|$)' <<<"$response"; then
      return 4
    fi
    printf '%s\n' "$response" >&2
    return 2
  fi

  headers="$(awk 'BEGIN { done=0 } !done { print } /^\r?$/ { done=1 }' <<<"$response")"
  body="$(awk 'BEGIN { body=0 } body { print } /^\r?$/ { body=1 }' <<<"$response")"
  release_state_etag="$(sed -n 's/^[Ee][Tt][Aa][Gg]:[[:space:]]*//p' <<<"$headers" | tr -d '\r' | head -1)"
  [[ -n "$release_state_etag" ]] || {
    echo "Release state response is missing ETag" >&2
    return 2
  }
  state="$(jq -r '.draft, .id, .tag_name, .target_commitish, .body' <<<"$body")" || return 2
  release_is_draft="$(sed -n '1p' <<<"$state")"
  release_state_id="$(sed -n '2p' <<<"$state")"
  release_state_tag="$(sed -n '3p' <<<"$state")"
  release_state_target="$(sed -n '4p' <<<"$state")"
  release_state_body="$(sed '1,4d' <<<"$state")"
  [[ "$release_state_id" =~ ^[1-9][0-9]*$ ]] || {
    echo "Release state response has an invalid database ID" >&2
    return 2
  }
}

matches_stable_transaction() {
  [[ "$release_state_tag" == "$release_tag" ]] \
    && [[ "$release_state_target" == "$candidate_sha" ]] \
    && grep -Fqx "$transaction_marker" <<<"$release_state_body" \
    && grep -Fqx "$candidate_marker" <<<"$release_state_body"
}

delete_release_once() {
  local response api_status http_status
  if response="$(gh api --include --method DELETE \
      -H 'Accept: application/vnd.github+json' \
      -H "If-Match: ${release_state_etag}" \
      "repos/${release_repository}/releases/${release_state_id}" 2>&1)"; then
    return 0
  else
    api_status=$?
  fi
  http_status="$(sed -n 's#^HTTP/[0-9.]* \([0-9][0-9][0-9]\).*#\1#p' <<<"$response" | head -1)"
  case "$http_status" in
    408|429|5??)
      return 10
      ;;
    400|409|412)
      echo "Release $release_tag changed while deleting it (HTTP $http_status)" >&2
      return 20
      ;;
    *)
      printf '%s\n' "$response" >&2
      return 30
      ;;
  esac
}

delete_owned_draft() {
  local require_current_owner="${1:-false}" attempt delete_status
  for (( attempt = 1; attempt <= delete_retry_count; attempt++ )); do
    if ! load_release_state \
      || [[ "$release_is_draft" != true ]] \
      || ! matches_stable_transaction; then
      echo "Refusing to delete Release $release_tag after its draft identity changed" >&2
      return 1
    fi
    if [[ "$require_current_owner" == true ]] \
      && ! grep -Fqx "$owner_marker" <<<"$release_state_body"; then
      echo "Refusing to delete Release $release_tag without the current owner marker" >&2
      return 1
    fi
    if delete_release_once; then
      return 0
    else
      delete_status=$?
      (( delete_status == 10 )) || return 1
    fi
    (( attempt == delete_retry_count )) || sleep "$delete_retry_delay"
  done
  echo "Failed to delete owned draft Release $release_tag after $delete_retry_count attempts" >&2
  return 1
}

if load_release_state; then
  if [[ "$release_is_draft" != true ]] || ! matches_stable_transaction; then
    echo "Release $release_tag already exists and is immutable" >&2
    exit 1
  fi
  delete_owned_draft false || exit 1
else
  initial_state_status=$?
  if (( initial_state_status != 4 )); then
    echo "Unable to determine whether Release $release_tag exists" >&2
    exit 1
  fi
fi

cleanup() {
  local status=$?
  rm -f "$draft_notes"
  if [[ "$status" -ne 0 && "$published" != true && "$owns_current_draft" == true ]]; then
    if ! delete_owned_draft true; then
      echo "Failed to clean up owned draft Release $release_tag" >&2
    fi
  fi
  exit "$status"
}
trap cleanup EXIT

{
  cat "$notes_file"
  printf '\n%s\n%s\n%s\n' "$owner_marker" "$candidate_marker" "$transaction_marker"
} >"$draft_notes"

gh release create "$release_tag" \
  --repo "$release_repository" \
  --target "$candidate_sha" \
  --title "RedCode IM $release_tag" \
  --notes-file "$draft_notes" \
  --draft \
  "${prerelease_args[@]}"
owns_current_draft=true

for asset in "${assets[@]}"; do
  gh release upload "$release_tag" "$asset" --repo "$release_repository"
done

if gh release edit "$release_tag" --repo "$release_repository" --draft=false; then
  published=true
else
  edit_status=$?
  if load_release_state \
    && [[ "$release_is_draft" == false ]] \
    && matches_stable_transaction; then
    published=true
  else
    exit "$edit_status"
  fi
fi
