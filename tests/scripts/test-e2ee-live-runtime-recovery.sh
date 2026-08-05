#!/usr/bin/env bash
# 使用 fake Compose/API 验证 live 驱动在失败、INT、TERM 后恢复 plaintext。
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
driver="$root_dir/tests/scripts/run-e2ee-cross-client-live.sh"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-e2ee-recovery.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/jdk/bin"

cat >"$tmp_dir/bin/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state_file="${E2EE_FAKE_STATE:?}"
args="$*"
if [[ "$args" == *" ps --status running "* ]]; then
  printf 'redcode-dev-postgres\nredcode-dev-api\n'
elif [[ "$args" == *" exec -T postgres psql "* ]]; then
  input="$(cat)"
  if [[ "$input" == *"SET value = 'e2ee'"* ]]; then printf 'e2ee' >"$state_file"; else printf 'plaintext' >"$state_file"; fi
elif [[ "$args" == *" exec -T redis redis-cli "*" MONITOR"* ]]; then
  while :; do sleep 1; done
elif [[ "$args" == *" logs "* ]]; then
  :
else
  :
fi
SH
cat >"$tmp_dir/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="$(cat "${E2EE_FAKE_STATE:?}")"
if [[ "$*" == *"/healthz"* ]]; then printf 'ok'; else printf '{"message_runtime":{"server_storage_mode":"persist","content_audit_mode":"%s"}}' "$state"; fi
SH
cat >"$tmp_dir/bin/make" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${E2EE_FAKE_MAKE_MODE:?}" in
  success) printf '{"run_id":"fake"}' >"${E2EE_LIVE_EVIDENCE_PATH:?}" ;;
  failure) exit 23 ;;
  wait) while :; do sleep 1; done ;;
esac
SH
cat >"$tmp_dir/jdk/bin/java" <<'SH'
#!/usr/bin/env bash
echo 'openjdk version "21.0.1"' >&2
SH
chmod +x "$tmp_dir/bin/docker" "$tmp_dir/bin/curl" "$tmp_dir/bin/make" "$tmp_dir/jdk/bin/java"

export PATH="$tmp_dir/bin:$PATH"
export JAVA_HOME="$tmp_dir/jdk"
export E2EE_FAKE_STATE="$tmp_dir/state"
export E2EE_LIVE_EVIDENCE_PATH="$tmp_dir/evidence.json"

assert_plaintext() {
  [[ "$(cat "$E2EE_FAKE_STATE")" == "plaintext" ]] || {
    echo "runtime 未恢复 plaintext" >&2
    exit 1
  }
}

printf 'plaintext' >"$E2EE_FAKE_STATE"
export E2EE_FAKE_MAKE_MODE=failure
if "$driver" >"$tmp_dir/failure.log" 2>&1; then
  echo "故意失败路径应返回非零" >&2
  exit 1
fi
assert_plaintext

run_signal_case() {
  local signal="$1"
  printf 'plaintext' >"$E2EE_FAKE_STATE"
  export E2EE_FAKE_MAKE_MODE=wait
  node - "$driver" "$signal" "$E2EE_FAKE_STATE" "$tmp_dir/$signal.log" <<'NODE'
const { spawn } = require('node:child_process');
const { readFileSync, openSync, closeSync } = require('node:fs');

const [driver, signal, stateFile, logFile] = process.argv.slice(2);
const output = openSync(logFile, 'w');
const child = spawn(driver, [], {
  detached: true,
  env: process.env,
  stdio: ['ignore', output, output],
});

(async () => {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline && readFileSync(stateFile, 'utf8') !== 'e2ee') {
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  if (readFileSync(stateFile, 'utf8') !== 'e2ee') {
    process.kill(-child.pid, 'SIGKILL');
    throw new Error('driver did not enter e2ee runtime');
  }
  process.kill(-child.pid, `SIG${signal}`);
  await new Promise((resolve) => child.once('exit', resolve));
  closeSync(output);
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
NODE
  assert_plaintext
}

run_signal_case INT
run_signal_case TERM
echo "[e2ee-live-recovery] failure/INT/TERM 均恢复 persist/plaintext"
