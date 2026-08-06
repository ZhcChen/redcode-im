#!/usr/bin/env bash
set -euo pipefail

repository="${GITHUB_REPOSITORY:-ZhcChen/redcode-im}"
environment="${PRODUCTION_RELEASE_ENVIRONMENT:-production-release}"
expected_reviewer="${PRODUCTION_RELEASE_REVIEWER:-ZhcChen}"

[[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
  echo "Invalid GITHUB_REPOSITORY" >&2
  exit 64
}
[[ "$environment" == "production-release" ]] || {
  echo "Unexpected production environment" >&2
  exit 64
}
[[ "$expected_reviewer" =~ ^[A-Za-z0-9-]+$ ]] || {
  echo "Invalid production reviewer" >&2
  exit 64
}

environment_json="$(gh api "repos/${repository}/environments/${environment}")"
branches_json="$(gh api "repos/${repository}/environments/${environment}/deployment-branch-policies")"

jq -e \
  --arg environment "$environment" \
  --arg reviewer "$expected_reviewer" '
    .name == $environment and
    .deployment_branch_policy.protected_branches == false and
    .deployment_branch_policy.custom_branch_policies == true and
    ([.protection_rules[] | select(.type == "required_reviewers")] | length) == 1 and
    ([.protection_rules[] | select(.type == "required_reviewers")][0].reviewers | length) >= 1 and
    ([.protection_rules[] | select(.type == "required_reviewers")][0].reviewers
      | any(.type == "User" and .reviewer.login == $reviewer))
  ' >/dev/null <<<"$environment_json"

jq -e '
  .total_count == 1 and
  (.branch_policies | length) == 1 and
  .branch_policies[0].name == "main" and
  .branch_policies[0].type == "branch"
' >/dev/null <<<"$branches_json"

jq -n \
  --arg repository "$repository" \
  --argjson environment "$environment_json" \
  --argjson branches "$branches_json" '
  {
    schema: "redcode-production-environment-evidence/v1",
    repository: $repository,
    environment: $environment.name,
    environment_id: $environment.id,
    updated_at: $environment.updated_at,
    can_admins_bypass: $environment.can_admins_bypass,
    required_reviewers: [
      $environment.protection_rules[]
      | select(.type == "required_reviewers")
      | .reviewers[]
      | {type, login: .reviewer.login, id: .reviewer.id}
    ] | sort_by(.login),
    prevent_self_review: (
      [$environment.protection_rules[] | select(.type == "required_reviewers")][0]
      | .prevent_self_review
    ),
    deployment_branch_policy: $environment.deployment_branch_policy,
    allowed_branches: [
      $branches.branch_policies[] | {name, type}
    ] | sort_by(.name)
  }
'
