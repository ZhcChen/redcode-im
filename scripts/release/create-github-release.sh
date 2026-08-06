#!/usr/bin/env bash
set -euo pipefail

release_tag="${RELEASE_TAG:?RELEASE_TAG is required}"
candidate_sha="${GITHUB_SHA:?GITHUB_SHA is required}"
assets_dir="${RELEASE_ASSETS_DIR:?RELEASE_ASSETS_DIR is required}"
notes_file="${RELEASE_NOTES_FILE:?RELEASE_NOTES_FILE is required}"
release_owner="${RELEASE_OWNER_TOKEN:-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}}"

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
[[ -d "$assets_dir" && -f "$notes_file" ]] || {
  echo "Release assets and notes must exist" >&2
  exit 66
}

if gh release view "$release_tag" >/dev/null 2>&1; then
  echo "Release $release_tag already exists and is immutable" >&2
  exit 1
fi

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
draft_notes="$(mktemp "${TMPDIR:-/tmp}/redcode-release-notes.XXXXXX")"
published=false

cleanup() {
  local status=$?
  rm -f "$draft_notes"
  if [[ "$status" -ne 0 && "$published" != true ]]; then
    local release_state
    release_state="$(gh release view "$release_tag" --json isDraft,body --jq '.isDraft, .body' 2>/dev/null || true)"
    if [[ "${release_state%%$'\n'*}" == true ]] \
      && grep -Fq "$owner_marker" <<<"$release_state" \
      && grep -Fq "$candidate_marker" <<<"$release_state"; then
      if ! gh release delete "$release_tag" --yes; then
        echo "Failed to clean up owned draft Release $release_tag" >&2
      fi
    else
      echo "Refusing to clean up Release $release_tag without matching draft markers" >&2
    fi
  fi
  exit "$status"
}
trap cleanup EXIT

{
  cat "$notes_file"
  printf '\n%s\n%s\n' "$owner_marker" "$candidate_marker"
} >"$draft_notes"

gh release create "$release_tag" \
  --target "$candidate_sha" \
  --title "RedCode IM $release_tag" \
  --notes-file "$draft_notes" \
  --draft \
  "${prerelease_args[@]}"

for asset in "${assets[@]}"; do
  gh release upload "$release_tag" "$asset"
done

gh release edit "$release_tag" --draft=false
published=true
