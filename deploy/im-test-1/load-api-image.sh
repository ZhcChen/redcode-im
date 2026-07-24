#!/usr/bin/env bash

set -euo pipefail

archive_path="${1:-}"
target_image="${API_IMAGE_TARGET:-redcode-im-api:im-test-1}"

if [[ -z "${archive_path}" ]]; then
  echo "用法: $0 /path/to/redcode-im-api-linux-x86_64.docker.tar.gz" >&2
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
  printf '%s\n' "${load_output}" | sed -n 's/^Loaded image: //p' | tail -n 1
)"

if [[ -z "${loaded_image}" ]]; then
  echo "${load_output}" >&2
  echo "无法从 docker load 输出中识别镜像标签。" >&2
  exit 1
fi

docker tag "${loaded_image}" "${target_image}"

printf '已加载镜像: %s\n' "${loaded_image}"
printf '已重新标记: %s\n' "${target_image}"
