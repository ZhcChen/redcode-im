#!/usr/bin/env bash
set -euo pipefail

event_name="${EVENT_NAME:-}"
github_ref="${GITHUB_REF:-}"
github_sha="${GITHUB_SHA:-}"
input_release_tag="${INPUT_RELEASE_TAG:-}"
publish_release="${PUBLISH_RELEASE:-false}"
output_file="${GITHUB_OUTPUT:-}"

die() {
  printf '[release-inputs] %s\n' "$*" >&2
  exit 1
}

[[ "$github_sha" =~ ^[0-9a-f]{40}$ ]] || die "GITHUB_SHA 必须是完整小写 Git SHA"
[[ "$publish_release" == "true" || "$publish_release" == "false" ]] ||
  die "PUBLISH_RELEASE 必须是 true 或 false"

release_tag=""
case "$event_name" in
  push)
    [[ "$github_ref" =~ ^refs/tags/(v.+)$ ]] || die "push 只允许 v* tag ref"
    [[ "$publish_release" == "false" ]] || die "tag push 只构建候选，不允许发布"
    release_tag="${BASH_REMATCH[1]}"
    ;;
  workflow_dispatch)
    if [[ "$publish_release" == "true" ]]; then
      [[ "$github_ref" == "refs/heads/main" ]] || die "正式发布只允许从 main 手工触发"
      [[ -n "$input_release_tag" ]] || die "publish_release=true 时必须提供 release_tag"
      release_tag="$input_release_tag"
    elif [[ -n "$input_release_tag" ]]; then
      die "publish_release=false 时不得提供 release_tag"
    fi
    ;;
  *)
    die "不支持的事件：$event_name"
    ;;
esac

if [[ -n "$release_tag" ]]; then
  [[ "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]] ||
    die "release_tag 格式无效：$release_tag"
fi

if [[ "$publish_release" == "true" ]]; then
  git rev-parse --verify --quiet "refs/tags/${release_tag}^{commit}" >/dev/null ||
    die "release_tag 必须预先存在：$release_tag"
  tag_commit="$(git rev-parse "refs/tags/${release_tag}^{commit}")"
  [[ "$tag_commit" == "$github_sha" ]] ||
    die "release_tag 指向 $tag_commit，不是候选 $github_sha"
fi

if [[ -n "$output_file" ]]; then
  printf 'release_tag=%s\n' "$release_tag" >> "$output_file"
else
  printf 'release_tag=%s\n' "$release_tag"
fi
