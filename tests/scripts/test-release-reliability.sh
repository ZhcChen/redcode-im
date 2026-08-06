#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-release-reliability.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT
bin_dir="$temp_dir/bin"
mkdir -p "$bin_dir"

cat >"$bin_dir/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${RELEASE_TEST_DOCKER_LOG:?}"
case "$1" in
  create) printf '%s\n' fixture-container ;;
  cp)
    [[ "${RELEASE_TEST_DOCKER_CP_MODE:-success}" == success ]] || exit 23
    printf 'api-binary\n' >"${3:?}"
    ;;
  rm) ;;
  save)
    while [[ "$1" != -o ]]; do shift; done
    printf 'docker-image\n' >"$2"
    ;;
  *) exit 70 ;;
esac
SH

cat >"$bin_dir/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${RELEASE_TEST_GH_LOG:?}"
if [[ "$1 $2" == "release view" ]]; then
  [[ "${RELEASE_TEST_GH_MODE:-missing}" == existing ]]
elif [[ "$1 $2" == "release create" ]]; then
  [[ "${RELEASE_TEST_GH_MODE:-missing}" == missing ]]
else
  exit 70
fi
SH
chmod +x "$bin_dir/docker" "$bin_dir/gh"

docker_log="$temp_dir/docker.log"
gh_log="$temp_dir/gh.log"
: >"$docker_log"
: >"$gh_log"

set +e
PATH="$bin_dir:$PATH" \
RELEASE_TEST_DOCKER_LOG="$docker_log" \
RELEASE_TEST_DOCKER_CP_MODE=fail \
API_RELEASE_IMAGE=fixture-image \
API_RELEASE_ARCH=x86_64 \
API_RELEASE_OUT="$temp_dir/api-failed" \
  "$root_dir/scripts/release/export-api-artifacts.sh" >/dev/null 2>&1
cp_status=$?
set -e
[[ "$cp_status" == 23 ]]
grep -Fxq 'rm -f fixture-container' "$docker_log"
echo "[release-reliability-test] docker cp failure trap: pass"

: >"$docker_log"
PATH="$bin_dir:$PATH" \
RELEASE_TEST_DOCKER_LOG="$docker_log" \
RELEASE_TEST_DOCKER_CP_MODE=success \
API_RELEASE_IMAGE=fixture-image \
API_RELEASE_ARCH=arm64 \
API_RELEASE_OUT="$temp_dir/api-success" \
  "$root_dir/scripts/release/export-api-artifacts.sh"
grep -Fxq 'rm fixture-container' "$docker_log"
test -s "$temp_dir/api-success/redcode-im-api-linux-arm64.binary.tar.gz"
test -s "$temp_dir/api-success/redcode-im-api-linux-arm64.docker.tar.gz"
test -s "$temp_dir/api-success/redcode-im-api-linux-arm64.sha256"
echo "[release-reliability-test] API export success cleanup: pass"

mkdir -p "$temp_dir/assets"
printf 'asset\n' >"$temp_dir/assets/app.bin"
printf 'notes\n' >"$temp_dir/notes.md"
common_release_env=(
  "PATH=$bin_dir:$PATH"
  "RELEASE_TEST_GH_LOG=$gh_log"
  "RELEASE_TAG=v9.9.9-f6test"
  "GITHUB_SHA=1111111111111111111111111111111111111111"
  "RELEASE_ASSETS_DIR=$temp_dir/assets"
  "RELEASE_NOTES_FILE=$temp_dir/notes.md"
)

set +e
env "${common_release_env[@]}" RELEASE_TEST_GH_MODE=existing \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
existing_status=$?
set -e
[[ "$existing_status" != 0 ]]
grep -Fxq 'release view v9.9.9-f6test' "$gh_log"
! grep -q 'release create' "$gh_log"
echo "[release-reliability-test] existing Release immutable: fail closed"

: >"$gh_log"
env "${common_release_env[@]}" RELEASE_TEST_GH_MODE=missing \
  "$root_dir/scripts/release/create-github-release.sh"
grep -q '^release create v9.9.9-f6test ' "$gh_log"
! grep -Eq 'delete-asset|release upload|--clobber|release edit' "$gh_log"
echo "[release-reliability-test] new Release create-only: pass"
