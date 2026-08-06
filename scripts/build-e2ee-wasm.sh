#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CARGO_HOME="${CARGO_HOME:-${HOME}/.cargo}"
RUST_SYSROOT="$(rustc --print sysroot)"

test "$(uname -s)" = "Linux" || {
  echo "E2EE WASM must be generated on the canonical Linux x86_64 builder" >&2
  exit 1
}
case "$(uname -m)" in
  x86_64 | amd64) ;;
  *)
    echo "E2EE WASM must be generated on the canonical Linux x86_64 builder" >&2
    exit 1
    ;;
esac
test "$(rustc --version | awk '{print $2}')" = "1.94.0" || {
  echo "E2EE WASM requires rustc 1.94.0" >&2
  exit 1
}
test "$(wasm-pack --version | awk '{print $2}')" = "0.15.0" || {
  echo "E2EE WASM requires wasm-pack 0.15.0" >&2
  exit 1
}

remap_flags=(
  "--remap-path-prefix=${ROOT_DIR}=/workspace"
  "--remap-path-prefix=${CARGO_HOME}=/cargo-home"
  "--remap-path-prefix=${RUST_SYSROOT}=/rust-toolchain"
)

RUSTFLAGS="${RUSTFLAGS:-} ${remap_flags[*]}" \
  wasm-pack build "${ROOT_DIR}/e2ee-core" \
    --target web \
    --release \
    --out-dir "${ROOT_DIR}/h5-app/src/e2ee/core-wasm"
