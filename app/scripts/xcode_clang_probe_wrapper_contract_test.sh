#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/redcode-clang-wrapper-test.XXXXXX")"
LOG_FILE="$TMP_DIR/clang.log"
STUB_CLANG="$TMP_DIR/clang"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$STUB_CLANG" <<'STUB'
#!/bin/bash
printf '%s\n' "$@" >"${CLANG_STUB_LOG:?}"
STUB
chmod +x "$STUB_CLANG"

CLANG_STUB_LOG="$LOG_FILE" REDCODE_REAL_CLANG="$STUB_CLANG" \
    "$SCRIPT_DIR/xcode_clang_probe_wrapper.sh" -v -E -dM -arch arm64 /dev/null

if grep -Fxq -- "-v" "$LOG_FILE"; then
    echo "capability probe 不应向真实 clang 传递 -v" >&2
    exit 1
fi
grep -Fxq -- "-dM" "$LOG_FILE"
grep -Fxq -- "-arch" "$LOG_FILE"

CLANG_STUB_LOG="$LOG_FILE" REDCODE_REAL_CLANG="$STUB_CLANG" \
    "$SCRIPT_DIR/xcode_clang_probe_wrapper.sh" -v -c source.c

grep -Fxq -- "-v" "$LOG_FILE"
grep -Fxq -- "-c" "$LOG_FILE"
echo "ok - Xcode clang capability probe wrapper"
