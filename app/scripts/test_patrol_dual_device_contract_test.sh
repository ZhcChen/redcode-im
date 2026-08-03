#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/redcode-patrol-dual-contract.XXXXXX")"
FIXTURE_DIR="$TMP_DIR/app"
BIN_DIR="$TMP_DIR/bin"
RESULT_DIR="$TMP_DIR/results"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT
mkdir -p "$FIXTURE_DIR/patrol_test" "$FIXTURE_DIR/scripts" "$BIN_DIR"
touch "$FIXTURE_DIR/patrol_test/dual_device_chat_test.dart"
touch "$FIXTURE_DIR/patrol_test/group_chat_test.dart"
touch "$FIXTURE_DIR/patrol_test/contact_lifecycle_test.dart"
cp "$SCRIPT_DIR/xcode_clang_probe_wrapper.sh" "$FIXTURE_DIR/scripts/"

cat >"$BIN_DIR/xcrun" <<'STUB'
#!/bin/bash
set -euo pipefail
if [ "${STUB_MISSING_DEVICE:-}" = b ]; then
    echo '    iPhone A (device-a) (Booted)'
    exit 0
fi
cat <<DEVICES
== Devices ==
    iPhone A (device-a) (Booted)
    iPhone B (device-b) (Booted)
DEVICES
STUB

cat >"$BIN_DIR/lsof" <<'STUB'
#!/bin/bash
[ "${STUB_BUSY_PORT:-}" = "${2#*:}" ] && exit 0
exit 1
STUB

cat >"$BIN_DIR/patrol" <<'STUB'
#!/bin/bash
set -euo pipefail
role="" account="" marker="" target=""
previous=""
for arg in "$@"; do
    if [ "$previous" = -t ]; then target="$arg"; fi
    case "$arg" in
        DUAL_ROLE=*) role="${arg#*=}" ;;
        DUAL_ACCOUNT=*) account="${arg#*=}" ;;
        DUAL_MARKER=*) marker="${arg#*=}" ;;
    esac
    previous="$arg"
done
[ -n "$role" ] && [ -n "$account" ] && [ -n "$marker" ] && [ -n "$target" ]
if [ -n "${STUB_PID_DIR:-}" ]; then
    echo "$$" >"$STUB_PID_DIR/$role.pid"
fi
mkdir -p build/ios_results_1.xcresult
[ "${STUB_FAIL_BEFORE_READY_ROLE:-}" != "$role" ] || exit 8
echo "DUAL_IDENTITY role=$role account=$account marker=$marker prefix=${DUAL_IDENTITY_PREFIX:-dual}-$role- peer=peer"
echo "DUAL_READY role=$role account=$account marker=$marker"
echo "DUAL_TARGET target=$target"
[ "${STUB_FAIL_ROLE:-}" != "$role" ] || exit 9
if [ -n "${DUAL_COMPLETION_EVENT:-}" ]; then
    echo "$DUAL_COMPLETION_EVENT role=$role marker=$marker"
fi
if [ "${STUB_SLEEP_ROLE:-}" = "$role" ]; then
    sleep "${STUB_ROLE_SLEEP:-20}"
elif [ "$role" = b ]; then
    sleep "${STUB_B_SLEEP:-1}"
fi
STUB

chmod +x "$BIN_DIR"/*

run() {
    env PATH="$BIN_DIR:$PATH" PATROL_BIN=patrol XCRUN_BIN=xcrun LSOF_BIN=lsof \
        DUAL_SOURCE_DIR="$FIXTURE_DIR" DUAL_RESULT_ROOT="$RESULT_DIR" \
        DUAL_DEVICE_A=device-a DUAL_DEVICE_B=device-b \
        DUAL_ACCOUNT_A=account-a DUAL_ACCOUNT_B=account-b DUAL_PASSWORD=password \
        DUAL_READY_TIMEOUT_SECONDS=3 DUAL_RUN_TIMEOUT_SECONDS=4 \
        "$@" "$APP_DIR/scripts/test_patrol_dual_device.sh"
}

expect_failure() {
    local expected="$1"
    shift
    local output
    if output=$("$@" 2>&1); then
        echo "期望失败但命令成功: $expected" >&2
        exit 1
    fi
    [[ "$output" == *"$expected"* ]] || { echo "$output" >&2; exit 1; }
}

run env DUAL_MARKER=contract-pass
grep -Fq 'DUAL_IDENTITY role=a account=account-a' "$RESULT_DIR/contract-pass/a.log"
grep -Fq 'DUAL_IDENTITY role=b account=account-b' "$RESULT_DIR/contract-pass/b.log"
[ -d "$RESULT_DIR/contract-pass/a/ios_results_1.xcresult" ]
[ -d "$RESULT_DIR/contract-pass/b/ios_results_1.xcresult" ]
echo 'ok - 双角色隔离、日志和 xcresult 归档'

run env DUAL_MARKER=group-target DUAL_TEST_TARGET=patrol_test/group_chat_test.dart
grep -Fq 'DUAL_TARGET target=patrol_test/group_chat_test.dart' "$RESULT_DIR/group-target/a.log"
grep -Fq 'test_target=patrol_test/group_chat_test.dart' "$RESULT_DIR/group-target/run.env"
echo 'ok - 支持受控双设备测试目标'

run env DUAL_MARKER=group-complete DUAL_TEST_TARGET=patrol_test/group_chat_test.dart \
    DUAL_COMPLETION_EVENT=DUAL_GROUP_COMPLETE STUB_B_SLEEP=20 DUAL_RUN_TIMEOUT_SECONDS=2
grep -Fq 'DUAL_GROUP_COMPLETE role=b marker=group-complete' "$RESULT_DIR/group-complete/b.log"
echo 'ok - 业务完成标记可关闭卡住的 B 端 XCTest 收尾'

run env DUAL_MARKER=contact-target DUAL_TEST_TARGET=patrol_test/contact_lifecycle_test.dart DUAL_IDENTITY_PREFIX=contact
grep -Fq 'prefix=contact-a-' "$RESULT_DIR/contact-target/a.log"
grep -Fq 'identity_prefix=contact' "$RESULT_DIR/contact-target/run.env"
echo 'ok - 支持场景化身份前缀'

expect_failure '无效测试目标' run env DUAL_TEST_TARGET=../outside.dart
expect_failure '测试目标不存在' run env DUAL_TEST_TARGET=patrol_test/missing_test.dart
expect_failure '无效身份前缀' run env DUAL_IDENTITY_PREFIX='../contact'
expect_failure '无效完成事件' run env DUAL_COMPLETION_EVENT='../done'
echo 'ok - 拒绝越界或缺失测试目标'

expect_failure 'A/B 必须使用两个不同的 Simulator' run env DUAL_DEVICE_B=device-a
echo 'ok - 拒绝相同设备'

expect_failure 'B 设备未启动或不是 iOS Simulator' run env STUB_MISSING_DEVICE=b
echo 'ok - 拒绝缺失或未启动设备'

expect_failure '端口已占用: 19081' run env STUB_BUSY_PORT=19081
echo 'ok - 拒绝占用端口'

expect_failure 'B 未在限时内进入等待状态' run env STUB_FAIL_BEFORE_READY_ROLE=b DUAL_MARKER=b-fail
echo 'ok - B 启动失败可归因'

mkdir -p "$TMP_DIR/pids"
expect_failure 'A 执行失败或超时' run env STUB_SLEEP_ROLE=a STUB_ROLE_SLEEP=20 STUB_B_SLEEP=20 STUB_PID_DIR="$TMP_DIR/pids" DUAL_RUN_TIMEOUT_SECONDS=1 DUAL_MARKER=a-timeout
for pid_file in "$TMP_DIR/pids"/*.pid; do
    pid="$(cat "$pid_file")"
    if kill -0 "$pid" 2>/dev/null; then
        echo "超时后仍有残留进程: $pid" >&2
        exit 1
    fi
done
echo 'ok - A 超时会清理双方进程'

run env DUAL_MARKER=marker-one
run env DUAL_MARKER=marker-two
[ -f "$RESULT_DIR/marker-one/marker.txt" ] && [ -f "$RESULT_DIR/marker-two/marker.txt" ]
echo 'ok - 重复执行不复用 marker 和结果目录'
