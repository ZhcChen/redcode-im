#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-wasm-builder.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT
bin_dir="$temp_dir/bin"
mkdir -p "$bin_dir"

cat >"$bin_dir/uname" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == -s ]]; then printf '%s\n' "${WASM_TEST_OS:-Linux}";
elif [[ "$1" == -m ]]; then printf '%s\n' "${WASM_TEST_ARCH:-x86_64}";
else exit 64; fi
SH

cat >"$bin_dir/rustc" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == --print && "$2" == sysroot ]]; then printf '%s\n' /fixture/rust;
elif [[ "$1" == --version ]]; then printf 'rustc %s (fixture)\n' "${WASM_TEST_RUST_VERSION:-1.94.0}";
else exit 64; fi
SH

cat >"$bin_dir/wasm-pack" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == --version ]]; then
  printf 'wasm-pack %s\n' "${WASM_TEST_WASM_PACK_VERSION:-0.15.0}"
elif [[ "$1" == build ]]; then
  printf '%s\n' "$*" >"${WASM_TEST_BUILD_LOG:?}"
else
  exit 64
fi
SH
chmod +x "$bin_dir/uname" "$bin_dir/rustc" "$bin_dir/wasm-pack"

run_case() {
  local name="$1"
  local expected="$2"
  local expected_message="$3"
  shift 3
  : >"$temp_dir/build.log"
  set +e
  env PATH="$bin_dir:$PATH" WASM_TEST_BUILD_LOG="$temp_dir/build.log" "$@" \
    "$root_dir/scripts/build-e2ee-wasm.sh" >"$temp_dir/$name.log" 2>&1
  local status=$?
  set -e
  if [[ "$expected" == pass ]]; then
    [[ "$status" == 0 && -s "$temp_dir/build.log" ]]
  else
    [[ "$status" != 0 && ! -s "$temp_dir/build.log" ]]
    grep -Fq -- "$expected_message" "$temp_dir/$name.log"
  fi
  echo "[wasm-builder-test] $name: $expected"
}

run_case darwin fail "canonical Linux x86_64 builder" WASM_TEST_OS=Darwin
run_case arm64 fail "canonical Linux x86_64 builder" WASM_TEST_ARCH=arm64
run_case wrong-rust fail "requires rustc 1.94.0" WASM_TEST_RUST_VERSION=1.93.0
run_case wrong-wasm-pack fail "requires wasm-pack 0.15.0" WASM_TEST_WASM_PACK_VERSION=0.14.0
run_case canonical pass ""
grep -q -- '--target web' "$temp_dir/build.log"
grep -q -- '--release' "$temp_dir/build.log"
grep -q 'h5-app/src/e2ee/core-wasm' "$temp_dir/build.log"
echo "[wasm-builder-test] 5 个 platform/version 场景全部通过"
