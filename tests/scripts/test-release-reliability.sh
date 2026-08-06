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
  'api --include')
    if [[ "$*" != *'--method DELETE'* ]]; then
      if [[ "${RELEASE_TEST_GH_API_MODE:-normal}" == error ]]; then
        printf 'HTTP/2 500 Internal Server Error\n\n{"message":"fixture failure"}\n'
        exit 1
      fi
      if [[ "$state" == missing ]]; then
        printf 'HTTP/2 404 Not Found\n\n{"message":"Not Found"}\n'
        exit 1
      fi
      [[ "$state" == draft ]] && draft=true || draft=false
      body_json="$(jq -Rs . <"${RELEASE_TEST_GH_BODY:?}")"
      printf 'HTTP/2 200 OK\nETag: %s\n\n' "$(cat "${RELEASE_TEST_GH_ETAG:?}")"
      printf '{"draft":%s,"id":%s,"tag_name":"%s","target_commitish":"%s","body":%s}\n' \
        "$draft" \
        "$(cat "${RELEASE_TEST_GH_ID:?}")" \
        "$(cat "${RELEASE_TEST_GH_TAG:?}")" \
        "$(cat "${RELEASE_TEST_GH_TARGET:?}")" \
        "$body_json"
      exit 0
    fi
    delete_count_file="${RELEASE_TEST_GH_DELETE_COUNT:?}"
    delete_count=$(( $(cat "$delete_count_file") + 1 ))
    printf '%s\n' "$delete_count" >"$delete_count_file"
    mode="${RELEASE_TEST_GH_DELETE_MODE:-success}"
    if [[ "$mode" == publish-before-delete ]]; then
      printf 'published\n' >"$state_file"
      printf '"published-etag"\n' >"${RELEASE_TEST_GH_ETAG:?}"
      printf 'HTTP/2 400 Bad Request\n\n{"message":"etag changed"}\n'
      exit 45
    fi
    if [[ "$mode" == draft-etag-changed ]]; then
      printf '"changed-draft-etag"\n' >"${RELEASE_TEST_GH_ETAG:?}"
      printf 'HTTP/2 400 Bad Request\n\n{"message":"etag changed"}\n'
      exit 45
    fi
    if [[ "$mode" == fail || ( "$mode" == fail-twice && "$delete_count" -le 2 ) ]]; then
      printf 'HTTP/2 503 Service Unavailable\n\n{"message":"retry"}\n'
      exit 43
    fi
    [[ "$state" == draft ]]
    [[ "$*" == *"If-Match: $(cat "${RELEASE_TEST_GH_ETAG:?}")"* ]]
    [[ "$*" == *"releases/$(cat "${RELEASE_TEST_GH_ID:?}")"* ]]
    printf 'missing\n' >"$state_file"
    printf 'HTTP/2 204 No Content\n\n'
    ;;
  'release create')
    [[ "$state" == missing ]] || exit 1
    tag="$3"
    notes_file=''
    candidate=''
    while (( $# > 0 )); do
      if [[ "$1" == --notes-file ]]; then notes_file="$2"; break; fi
      if [[ "$1" == --target ]]; then candidate="$2"; fi
      shift
    done
    cp "$notes_file" "${RELEASE_TEST_GH_BODY:?}"
    printf '%s\n' "$tag" >"${RELEASE_TEST_GH_TAG:?}"
    printf '%s\n' "$candidate" >"${RELEASE_TEST_GH_TARGET:?}"
    printf '1001\n' >"${RELEASE_TEST_GH_ID:?}"
    printf '"draft-etag"\n' >"${RELEASE_TEST_GH_ETAG:?}"
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
    printf '"published-etag"\n' >"${RELEASE_TEST_GH_ETAG:?}"
    [[ "${RELEASE_TEST_GH_EDIT_MODE:-success}" == success ]] || exit 44
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
gh_tag="$temp_dir/gh-tag"
gh_target="$temp_dir/gh-target"
gh_id="$temp_dir/gh-id"
gh_etag="$temp_dir/gh-etag"
gh_upload_count="$temp_dir/gh-upload-count"
gh_delete_count="$temp_dir/gh-delete-count"
common_release_env=(
  "PATH=$bin_dir:$PATH"
  "RELEASE_TEST_GH_LOG=$gh_log"
  "RELEASE_TAG=v9.9.9-f6test"
  "GITHUB_SHA=1111111111111111111111111111111111111111"
  "RELEASE_ASSETS_DIR=$temp_dir/assets"
  "RELEASE_NOTES_FILE=$temp_dir/notes.md"
  "RELEASE_OWNER_TOKEN=run-100-attempt-1"
  "RELEASE_DELETE_RETRY_DELAY_SECONDS=0"
  "GITHUB_REPOSITORY=ZhcChen/redcode-im"
  "RELEASE_TEST_GH_STATE=$gh_state"
  "RELEASE_TEST_GH_BODY=$gh_body"
  "RELEASE_TEST_GH_TAG=$gh_tag"
  "RELEASE_TEST_GH_TARGET=$gh_target"
  "RELEASE_TEST_GH_ID=$gh_id"
  "RELEASE_TEST_GH_ETAG=$gh_etag"
  "RELEASE_TEST_GH_UPLOAD_COUNT=$gh_upload_count"
  "RELEASE_TEST_GH_DELETE_COUNT=$gh_delete_count"
)

: >"$gh_log"
printf 'missing\n' >"$gh_state"
printf '0\n' >"$gh_upload_count"
printf '0\n' >"$gh_delete_count"
set +e
env "${common_release_env[@]}" RELEASE_OWNER_TOKEN= GITHUB_ACTIONS= \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
ownerless_status=$?
set -e
[[ "$ownerless_status" == 64 ]]
[[ ! -s "$gh_log" ]]
echo "[release-reliability-test] direct invocation requires explicit owner: fail closed"

printf 'published\n' >"$gh_state"
: >"$gh_body"
printf 'v9.9.9-f6test\n' >"$gh_tag"
printf '1111111111111111111111111111111111111111\n' >"$gh_target"
printf '1001\n' >"$gh_id"
printf '"published-etag"\n' >"$gh_etag"
printf '0\n' >"$gh_upload_count"
printf '0\n' >"$gh_delete_count"
: >"$gh_log"
set +e
env "${common_release_env[@]}" \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
existing_status=$?
set -e
[[ "$existing_status" != 0 ]]
grep -Eq '^api --include .*repos/ZhcChen/redcode-im/releases/tags/v9\.9\.9-f6test$' "$gh_log"
! grep -q 'release create' "$gh_log"
echo "[release-reliability-test] existing Release immutable: fail closed"

: >"$gh_log"
printf 'missing\n' >"$gh_state"
printf '0\n' >"$gh_upload_count"
env "${common_release_env[@]}" \
  "$root_dir/scripts/release/create-github-release.sh"
grep -Eq '^release create v9\.9\.9-f6test .*--draft' "$gh_log"
[[ "$(grep -c '^release upload ' "$gh_log")" == 2 ]]
grep -Fxq 'release edit v9.9.9-f6test --repo ZhcChen/redcode-im --draft=false' "$gh_log"
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
grep -Eq '^api --include --method DELETE .*If-Match: .*repos/ZhcChen/redcode-im/releases/1001$' "$gh_log"
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
[[ "$(grep -c '^api --include --method DELETE ' "$gh_log")" == 3 ]]
echo "[release-reliability-test] cleanup failure preserves owned draft: pass"

: >"$gh_log"
printf '0\n' >"$gh_upload_count"
env "${common_release_env[@]}" RELEASE_OWNER_TOKEN=run-101-attempt-1 \
  "$root_dir/scripts/release/create-github-release.sh"
[[ "$(cat "$gh_state")" == published ]]
[[ "$(grep -c '^api --include --method DELETE ' "$gh_log")" == 1 ]]
grep -Eq '^release create v9\.9\.9-f6test .*--draft' "$gh_log"
[[ "$(grep -c '^release upload ' "$gh_log")" == 2 ]]
grep -Fxq 'release edit v9.9.9-f6test --repo ZhcChen/redcode-im --draft=false' "$gh_log"
echo "[release-reliability-test] orphan owned draft recovers across runs: pass"

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
! grep -q '^api --include --method DELETE ' "$gh_log"
[[ "$(cat "$gh_state")" == draft ]]
echo "[release-reliability-test] existing foreign draft immutable: fail closed"

: >"$gh_log"
printf 'missing\n' >"$gh_state"
printf '0\n' >"$gh_upload_count"
printf '0\n' >"$gh_delete_count"
set +e
env "${common_release_env[@]}" RELEASE_TEST_GH_API_MODE=error \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
api_error_status=$?
set -e
[[ "$api_error_status" != 0 ]]
! grep -Eq '^release (create|upload|edit) |^api --include --method DELETE ' "$gh_log"
echo "[release-reliability-test] release lookup API error: fail closed"

: >"$gh_log"
printf 'missing\n' >"$gh_state"
printf '0\n' >"$gh_upload_count"
printf '0\n' >"$gh_delete_count"
env "${common_release_env[@]}" RELEASE_TEST_GH_EDIT_MODE=success-timeout \
  "$root_dir/scripts/release/create-github-release.sh"
[[ "$(cat "$gh_state")" == published ]]
[[ "$(grep -c '^release edit ' "$gh_log")" == 1 ]]
[[ "$(grep -c '^api --include ' "$gh_log")" == 2 ]]
! grep -q '^api --include --method DELETE ' "$gh_log"
echo "[release-reliability-test] ambiguous publish confirms server success: pass"

: >"$gh_log"
printf 'draft\n' >"$gh_state"
printf '"draft-etag"\n' >"$gh_etag"
printf '0\n' >"$gh_upload_count"
printf '0\n' >"$gh_delete_count"
env "${common_release_env[@]}" RELEASE_TEST_GH_DELETE_MODE=fail-twice \
  "$root_dir/scripts/release/create-github-release.sh"
[[ "$(cat "$gh_state")" == published ]]
[[ "$(grep -c '^api --include --method DELETE ' "$gh_log")" == 3 ]]
grep -Eq '^release create v9\.9\.9-f6test .*--draft' "$gh_log"
echo "[release-reliability-test] transient draft delete recovers in bounded retry: pass"

: >"$gh_log"
printf 'draft\n' >"$gh_state"
printf '"draft-etag"\n' >"$gh_etag"
printf '0\n' >"$gh_upload_count"
printf '0\n' >"$gh_delete_count"
set +e
env "${common_release_env[@]}" RELEASE_TEST_GH_DELETE_MODE=publish-before-delete \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
race_status=$?
set -e
[[ "$race_status" != 0 ]]
[[ "$(cat "$gh_state")" == published ]]
[[ "$(grep -c '^api --include --method DELETE ' "$gh_log")" == 1 ]]
! grep -Eq '^release (create|upload|edit) ' "$gh_log"
echo "[release-reliability-test] draft publish race preserves release: fail closed"

: >"$gh_log"
printf 'draft\n' >"$gh_state"
printf '"draft-etag"\n' >"$gh_etag"
printf '0\n' >"$gh_upload_count"
printf '0\n' >"$gh_delete_count"
set +e
env "${common_release_env[@]}" RELEASE_TEST_GH_DELETE_MODE=draft-etag-changed \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
etag_race_status=$?
set -e
[[ "$etag_race_status" != 0 ]]
[[ "$(cat "$gh_state")" == draft ]]
[[ "$(grep -c '^api --include --method DELETE ' "$gh_log")" == 1 ]]
! grep -Eq '^release (create|upload|edit) ' "$gh_log"
echo "[release-reliability-test] draft ETag conflict is not retried: fail closed"

: >"$gh_log"
printf 'draft\n' >"$gh_state"
printf '"draft-etag"\n' >"$gh_etag"
printf '%s\n' \
  '<!-- redcode-release-candidate:1111111111111111111111111111111111111111 -->' \
  '<!-- redcode-release-transaction:v1 repository=ZhcChen/redcode-im tag=v9.9.9-f6test candidate=1111111111111111111111111111111111111111 -->' \
  >"$gh_body"
printf '2222222222222222222222222222222222222222\n' >"$gh_target"
set +e
env "${common_release_env[@]}" \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
target_status=$?
set -e
[[ "$target_status" != 0 ]]
! grep -q '^api --include --method DELETE ' "$gh_log"
[[ "$(cat "$gh_state")" == draft ]]
echo "[release-reliability-test] mismatched target draft immutable: fail closed"

: >"$gh_log"
printf 'draft\n' >"$gh_state"
printf '1111111111111111111111111111111111111111\n' >"$gh_target"
printf '%s\n' \
  '<!-- redcode-release-candidate:2222222222222222222222222222222222222222 -->' \
  '<!-- redcode-release-transaction:v1 repository=ZhcChen/redcode-im tag=v9.9.9-f6test candidate=2222222222222222222222222222222222222222 -->' \
  >"$gh_body"
set +e
env "${common_release_env[@]}" \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
candidate_status=$?
set -e
[[ "$candidate_status" != 0 ]]
! grep -q '^api --include --method DELETE ' "$gh_log"
[[ "$(cat "$gh_state")" == draft ]]
echo "[release-reliability-test] different candidate draft immutable: fail closed"

: >"$gh_log"
printf 'draft\n' >"$gh_state"
printf '%s\n' \
  '<!-- redcode-release-candidate:1111111111111111111111111111111111111111 -->' \
  '<!-- redcode-release-transaction:v1 repository=ZhcChen/redcode-im tag=v9.9.9-f6test candidate=1111111111111111111111111111111111111111 -->' \
  >"$gh_body"
printf '"draft-etag"\n' >"$gh_etag"
printf '0\n' >"$gh_delete_count"
set +e
env "${common_release_env[@]}" RELEASE_TEST_GH_DELETE_MODE=fail \
  "$root_dir/scripts/release/create-github-release.sh" >/dev/null 2>&1
retry_status=$?
set -e
[[ "$retry_status" != 0 ]]
[[ "$(grep -c '^api --include --method DELETE ' "$gh_log")" == 3 ]]
! grep -Eq '^release (create|upload|edit) ' "$gh_log"
[[ "$(cat "$gh_state")" == draft ]]
echo "[release-reliability-test] orphan cleanup retry exhaustion: fail closed"
