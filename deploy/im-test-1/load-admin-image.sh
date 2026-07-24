#!/usr/bin/env bash

set -euo pipefail

archive_path="${1:-}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
env_file="${ADMIN_ENV_FILE:-${script_dir}/.env}"
target_image="${ADMIN_IMAGE_TARGET:-}"

if [[ -z "${target_image}" && -f "${env_file}" ]]; then
  target_image="$(sed -n 's/^ADMIN_IMAGE=//p' "${env_file}" | tail -n 1)"
fi

target_image="${target_image:-redcode-im-admin:im-test-1}"

if [[ -z "${archive_path}" ]]; then
  echo "用法: $0 /path/to/redcode-im-admin.docker.tar.gz" >&2
  exit 1
fi

if [[ ! -f "${archive_path}" ]]; then
  echo "找不到归档文件: ${archive_path}" >&2
  exit 1
fi

case "${archive_path}" in
  *.tar.gz|*.tgz)
    load_output="$(gzip -dc "${archive_path}" | docker load)"
    ;;
  *.tar)
    load_output="$(docker load -i "${archive_path}")"
    ;;
  *)
    echo "不支持的归档格式: ${archive_path}" >&2
    exit 1
    ;;
esac

loaded_image="$(
  printf '%s\n' "${load_output}" | sed -n \
    -e 's/^Loaded image: //p' \
    -e 's/^Loaded image ID: //p' | tail -n 1
)"

if [[ -z "${loaded_image}" ]]; then
  echo "${load_output}" >&2
  echo "无法从 docker load 输出中识别镜像标签。" >&2
  exit 1
fi

docker tag "${loaded_image}" "${target_image}"

printf '已加载镜像: %s\n' "${loaded_image}"
printf '已重新标记: %s\n' "${target_image}"
