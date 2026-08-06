#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root_dir/scripts/release/capture-production-environment.sh"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-production-environment.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$temp_dir/bin"

cat >"$temp_dir/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == api ]]
[[ "${PRODUCTION_ENV_GH_MODE:-success}" == success ]] || exit 1
if [[ "$2" == */deployment-branch-policies ]]; then
  branch="${PRODUCTION_ENV_BRANCH:-main}"
  printf '{"total_count":1,"branch_policies":[{"name":"%s","type":"branch"}]}\n' "$branch"
else
  reviewers='[{"type":"User","reviewer":{"login":"ZhcChen","id":23111450}}]'
  [[ "${PRODUCTION_ENV_REVIEWERS:-present}" == present ]] || reviewers='[]'
  printf '{"id":19387368785,"name":"production-release","updated_at":"2026-08-06T05:40:51Z","can_admins_bypass":true,"protection_rules":[{"type":"required_reviewers","prevent_self_review":false,"reviewers":%s},{"type":"branch_policy"}],"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}\n' "$reviewers"
fi
SH
chmod +x "$temp_dir/bin/gh"

run_case() {
  local name="$1" expected="$2"
  shift 2
  set +e
  env PATH="$temp_dir/bin:$PATH" "$@" "$script" >"$temp_dir/$name.json" 2>"$temp_dir/$name.err"
  status=$?
  set -e
  if [[ "$expected" == pass ]]; then
    [[ "$status" == 0 ]]
    jq -e '.environment == "production-release" and .allowed_branches == [{"name":"main","type":"branch"}]' \
      "$temp_dir/$name.json" >/dev/null
  else
    [[ "$status" != 0 ]]
  fi
  echo "[production-environment-test] $name: $expected"
}

run_case valid pass
run_case missing-reviewer fail PRODUCTION_ENV_REVIEWERS=missing
run_case wrong-branch fail PRODUCTION_ENV_BRANCH=feature
run_case api-failure fail PRODUCTION_ENV_GH_MODE=fail
bash -n "$script"
echo "[production-environment-test] 4 个 environment policy 场景全部通过"
