#!/usr/bin/env bash
set -euo pipefail

release_tag="${RELEASE_TAG:?RELEASE_TAG is required}"
candidate_sha="${GITHUB_SHA:?GITHUB_SHA is required}"
assets_dir="${RELEASE_ASSETS_DIR:?RELEASE_ASSETS_DIR is required}"
notes_file="${RELEASE_NOTES_FILE:?RELEASE_NOTES_FILE is required}"

[[ "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]] || {
  echo "Invalid release tag: $release_tag" >&2
  exit 64
}
[[ "$candidate_sha" =~ ^[0-9a-f]{40}$ ]] || {
  echo "GITHUB_SHA must be a full lowercase Git SHA" >&2
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
gh release create "$release_tag" "${assets[@]}" \
  --target "$candidate_sha" \
  --title "RedCode IM $release_tag" \
  --notes-file "$notes_file" \
  "${prerelease_args[@]}"
