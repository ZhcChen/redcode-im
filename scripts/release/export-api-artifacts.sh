#!/usr/bin/env bash
set -euo pipefail

image="${API_RELEASE_IMAGE:?API_RELEASE_IMAGE is required}"
arch="${API_RELEASE_ARCH:?API_RELEASE_ARCH is required}"
out="${API_RELEASE_OUT:?API_RELEASE_OUT is required}"
container_id=""

cleanup_container() {
  local exit_code=$?
  trap - EXIT
  if [[ -n "$container_id" ]]; then
    docker rm -f "$container_id" >/dev/null 2>&1 || exit_code=1
  fi
  exit "$exit_code"
}
trap cleanup_container EXIT

[[ "$arch" =~ ^(x86_64|arm64)$ ]] || {
  echo "Unsupported API release architecture: $arch" >&2
  exit 64
}
[[ "$out" == /* ]] || {
  echo "API_RELEASE_OUT must be an absolute path" >&2
  exit 64
}

mkdir -p "$out"
container_id="$(docker create "$image")"
docker cp "$container_id:/app/redcode-im-api" "$out/redcode-im-api-linux-$arch"
docker rm "$container_id"
container_id=""
chmod +x "$out/redcode-im-api-linux-$arch"

tar -C "$out" -czf "$out/redcode-im-api-linux-$arch.binary.tar.gz" "redcode-im-api-linux-$arch"
docker save "$image" -o "$out/redcode-im-api-linux-$arch.docker.tar"
gzip -9 "$out/redcode-im-api-linux-$arch.docker.tar"
(
  cd "$out"
  sha256sum "redcode-im-api-linux-$arch.binary.tar.gz" \
    "redcode-im-api-linux-$arch.docker.tar.gz" >"redcode-im-api-linux-$arch.sha256"
)
