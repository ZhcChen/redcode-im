#!/bin/bash

set -euo pipefail

REAL_CLANG="${REDCODE_REAL_CLANG:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang}"
args=()
is_capability_probe=0

for arg in "$@"; do
    if [ "$arg" = "-dM" ]; then
        is_capability_probe=1
        break
    fi
done

for arg in "$@"; do
    if [ "$is_capability_probe" -eq 1 ] && [ "$arg" = "-v" ]; then
        continue
    fi
    args+=("$arg")
done

exec "$REAL_CLANG" "${args[@]}"
