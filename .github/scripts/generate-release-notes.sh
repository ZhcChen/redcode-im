#!/usr/bin/env bash

set -euo pipefail

release_tag="${RELEASE_TAG:-${1:-}}"
github_repository="${GITHUB_REPOSITORY:-${2:-}}"
assets_dir="${3:-.artifacts/publish-assets}"
output_path="${4:-.artifacts/release-notes.md}"

if [[ -z "${release_tag}" ]]; then
  echo "Missing release tag. Provide RELEASE_TAG or argv[1]." >&2
  exit 1
fi

if [[ -z "${github_repository}" ]]; then
  echo "Missing GitHub repository. Provide GITHUB_REPOSITORY or argv[2]." >&2
  exit 1
fi

release_base_url="https://github.com/${github_repository}/releases/download/${release_tag}"

declare -a asset_names=()
known_assets=""

shopt -s nullglob
for asset_path in "${assets_dir}"/*; do
  if [[ -f "${asset_path}" ]]; then
    asset_names+=("$(basename "${asset_path}")")
  fi
done
shopt -u nullglob

if (( ${#asset_names[@]} > 0 )); then
  IFS=$'\n' asset_names=($(printf '%s\n' "${asset_names[@]}" | sort))
fi

asset_url() {
  local file_name="$1"
  printf '%s/%s' "${release_base_url}" "${file_name// /%20}"
}

mark_known() {
  known_assets+="$1"$'\n'
}

is_known_asset() {
  local file_name="$1"
  grep -Fqx "${file_name}" <<< "${known_assets}"
}

append_if_present() {
  local prefix="$1"
  local label="$2"
  local file_name="$3"

  if [[ -n "${file_name}" ]]; then
    printf -- '%s- [%s](%s)\n' "${prefix}" "${label}" "$(asset_url "${file_name}")"
    mark_known "${file_name}"
  fi
}

find_first_match() {
  local pattern="$1"
  local asset_name

  if (( ${#asset_names[@]} == 0 )); then
    return 1
  fi

  for asset_name in "${asset_names[@]}"; do
    if [[ "${asset_name}" == ${pattern} ]]; then
      printf '%s\n' "${asset_name}"
      return 0
    fi
  done

  return 1
}

find_previous_stable_tag() {
  local current_index=0
  local stable_tags=()
  local tag

  while IFS= read -r tag; do
    stable_tags+=("${tag}")
  done < <(git tag --list 'v*.*.*' --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)

  for tag in "${stable_tags[@]}"; do
    if [[ "${tag}" == "${release_tag}" ]]; then
      if (( current_index + 1 < ${#stable_tags[@]} )); then
        printf '%s\n' "${stable_tags[$((current_index + 1))]}"
      fi
      return 0
    fi
    ((current_index += 1))
  done

  return 0
}

android_apk="$(find_first_match 'redcode-im-app-android-release.apk' || true)"
android_aab="$(find_first_match 'redcode-im-app-android-release.aab' || true)"

api_linux_x86_64_bin="$(find_first_match 'redcode-im-api-linux-x86_64' || true)"
api_linux_x86_64_archive="$(find_first_match 'redcode-im-api-linux-x86_64.binary.tar.gz' || true)"
api_linux_x86_64_docker="$(find_first_match 'redcode-im-api-linux-x86_64.docker.tar.gz' || true)"
api_linux_x86_64_sha256="$(find_first_match 'redcode-im-api-linux-x86_64.sha256' || true)"

api_linux_arm64_bin="$(find_first_match 'redcode-im-api-linux-arm64' || true)"
api_linux_arm64_archive="$(find_first_match 'redcode-im-api-linux-arm64.binary.tar.gz' || true)"
api_linux_arm64_docker="$(find_first_match 'redcode-im-api-linux-arm64.docker.tar.gz' || true)"
api_linux_arm64_sha256="$(find_first_match 'redcode-im-api-linux-arm64.sha256' || true)"

{
  printf '## 下载\n\n'

  if [[ -n "${android_apk}" || -n "${android_aab}" ]]; then
    printf '### Android\n'
    append_if_present '' 'APK 安装包' "${android_apk}"
    append_if_present '' 'AAB 发布包' "${android_aab}"
    printf '\n'
  fi

  if [[ -n "${api_linux_x86_64_bin}" || -n "${api_linux_x86_64_archive}" || -n "${api_linux_x86_64_docker}" || -n "${api_linux_x86_64_sha256}" || -n "${api_linux_arm64_bin}" || -n "${api_linux_arm64_archive}" || -n "${api_linux_arm64_docker}" || -n "${api_linux_arm64_sha256}" ]]; then
    printf '### API\n'

    if [[ -n "${api_linux_x86_64_bin}" || -n "${api_linux_x86_64_archive}" || -n "${api_linux_x86_64_docker}" || -n "${api_linux_x86_64_sha256}" ]]; then
      printf -- '- Linux x86_64\n'
      append_if_present '  ' '可执行文件' "${api_linux_x86_64_bin}"
      append_if_present '  ' 'Binary 压缩包' "${api_linux_x86_64_archive}"
      append_if_present '  ' 'Docker 镜像包' "${api_linux_x86_64_docker}"
      append_if_present '  ' 'SHA256 校验' "${api_linux_x86_64_sha256}"
    fi

    if [[ -n "${api_linux_arm64_bin}" || -n "${api_linux_arm64_archive}" || -n "${api_linux_arm64_docker}" || -n "${api_linux_arm64_sha256}" ]]; then
      printf -- '- Linux arm64\n'
      append_if_present '  ' '可执行文件' "${api_linux_arm64_bin}"
      append_if_present '  ' 'Binary 压缩包' "${api_linux_arm64_archive}"
      append_if_present '  ' 'Docker 镜像包' "${api_linux_arm64_docker}"
      append_if_present '  ' 'SHA256 校验' "${api_linux_arm64_sha256}"
    fi

    printf '\n'
  fi

  unknown_written=0
  if (( ${#asset_names[@]} > 0 )); then
    for asset_name in "${asset_names[@]}"; do
      if ! is_known_asset "${asset_name}"; then
        if (( unknown_written == 0 )); then
          printf '### 其他产物\n'
          unknown_written=1
        fi
        printf -- '- [%s](%s)\n' "${asset_name}" "$(asset_url "${asset_name}")"
      fi
    done
  fi

  if (( unknown_written == 1 )); then
    printf '\n'
  fi

  previous_tag="$(find_previous_stable_tag)"
  if [[ -n "${previous_tag}" ]]; then
    printf '## 变更\n\n'
    printf -- '- [查看完整变更](https://github.com/%s/compare/%s...%s)\n' "${github_repository}" "${previous_tag}" "${release_tag}"
  fi
} > "${output_path}"

echo "Generated release notes at ${output_path}"
