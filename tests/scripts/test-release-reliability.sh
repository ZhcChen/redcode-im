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
state_file="${RELEASE_TEST_GH_STATE:?}"
state="$(cat "$state_file")"
case "$1 $2" in
  'release view')
    [[ "$state" != missing ]] || exit 1
    if [[ "$*" == *'--json isDraft,body'* ]]; then
      [[ "$state" == draft ]] && printf 'true\n' || printf 'false\n'
      cat "${RELEASE_TEST_GH_BODY:?}"
    fi
    ;;
  'release create')
    [[ "$state" == missing ]] || exit 1
    notes_file=''
    while (( $# > 0 )); do
      if [[ "$1" == --notes-file ]]; then notes_file="$2"; break; fi
      shift
    done
    cp "$notes_file" "${RELEASE_TEST_GH_BODY:?}"
    printf 'draft\n' >"$state_file"
    ;;
  'release upload')
    count_file="${RELEASE_TEST_GH_UPLOAD_COUNT:?}"
    count=$(( $(cat "$count_file") + 1 ))
    printf '%s\n' "$count" >"$count_file"
    [[ "$count" != "${RELEASE_TEST_GH_FAIL_UPLOAD_AT:-0}" ]] || exit 42
    ;;
  'release edit')
    [[ "$state" == draft && "$*" == *'--draft=false'* ]]
    printf 'published\n' >"$state_file"
    ;;
  'release delete')
    [[ "$state" == draft ]]
    [[ "${RELEASE_TEST_GH_DELETE_MODE:-success}" == success ]] || exit 43
    printf 'missing\n' >"$state_file"
    ;;
  *) exit 70 ;;
esac
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
printf 'asset 2\n' >"$temp_dir/assets/app.sig"
printf 'notes\n' >"$temp_dir/notes.md"
gh_state="$temp_dir/gh-state"
gh_body="$temp_dir/gh-body"
gh_upload_count="$temp_dir/gh-upload-count"
common_release_env=(
  "PATH=$bin_dir:$PATH"
  "RELEASE_TEST_GH_LOG=$gh_log"
  "RELEASE_TAG=v9.9.9-f6test"
  "GITHUB_SHA=1111111111111111111111111111111111111111"
  "RELEASE_ASSETS_DIR=$temp_dir/assets"
  "RELEASE_NOTES_FILE=$temp_dir/notes.md"
  "RELEASE_OWNER_TOKEN=run-100-attempt-1"
  "RELEASE_TEST_GH_STATE=$gh_state"
  "RELEASE_TEST_GH_BODY=$gh_body"
  "RELEASE_TEST_GH_UPLOAD_COUNT=$gh_upload_count"
)

printf 'published\n' >"$gh_state"
: >"$gh_body"
printf '0\n' >"$gh_upload_count"
set +e
env "${common_release_env[@]}" \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
existing_status=$?
set -e
[[ "$existing_status" != 0 ]]
grep -Fxq 'release view v9.9.9-f6test' "$gh_log"
! grep -q 'release create' "$gh_log"
echo "[release-reliability-test] existing Release immutable: fail closed"

: >"$gh_log"
printf 'missing\n' >"$gh_state"
printf '0\n' >"$gh_upload_count"
env "${common_release_env[@]}" \
  "$root_dir/scripts/release/create-github-release.sh"
grep -Eq '^release create v9\.9\.9-f6test .*--draft' "$gh_log"
[[ "$(grep -c '^release upload ' "$gh_log")" == 2 ]]
grep -Fxq 'release edit v9.9.9-f6test --draft=false' "$gh_log"
[[ "$(cat "$gh_state")" == published ]]
! grep -q '^release delete ' "$gh_log"
echo "[release-reliability-test] draft upload and publish: pass"

: >"$gh_log"
printf 'missing\n' >"$gh_state"
printf '0\n' >"$gh_upload_count"
set +e
env "${common_release_env[@]}" RELEASE_TEST_GH_FAIL_UPLOAD_AT=2 \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
upload_status=$?
set -e
[[ "$upload_status" == 42 ]]
grep -Fxq 'release delete v9.9.9-f6test --yes' "$gh_log"
! grep -q -- '--cleanup-tag' "$gh_log"
[[ "$(cat "$gh_state")" == missing ]]

: >"$gh_log"
printf '0\n' >"$gh_upload_count"
env "${common_release_env[@]}" \
  "$root_dir/scripts/release/create-github-release.sh"
[[ "$(cat "$gh_state")" == published ]]
echo "[release-reliability-test] partial upload cleanup and same-tag retry: pass"

: >"$gh_log"
printf 'missing\n' >"$gh_state"
printf '0\n' >"$gh_upload_count"
set +e
env "${common_release_env[@]}" RELEASE_TEST_GH_FAIL_UPLOAD_AT=2 RELEASE_TEST_GH_DELETE_MODE=fail \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
cleanup_status=$?
set -e
[[ "$cleanup_status" == 42 ]]
[[ "$(cat "$gh_state")" == draft ]]
grep -Fxq 'release delete v9.9.9-f6test --yes' "$gh_log"
echo "[release-reliability-test] cleanup failure preserves owned draft: pass"

: >"$gh_log"
printf 'draft\n' >"$gh_state"
printf 'true\nforeign release\n' >"$gh_body"
printf '0\n' >"$gh_upload_count"
set +e
env "${common_release_env[@]}" \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
foreign_status=$?
set -e
[[ "$foreign_status" != 0 ]]
! grep -q '^release delete ' "$gh_log"
[[ "$(cat "$gh_state")" == draft ]]
echo "[release-reliability-test] existing foreign draft immutable: fail closed"
