#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture_dir="$root_dir/tests/fixtures/supply-chain"
check_script="$root_dir/scripts/supply-chain/check.sh"
evaluator="$root_dir/scripts/supply-chain/evaluate.ts"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-supply-chain.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin"

real_bun="$(command -v bun)"
case_count=0

assert_status() {
  local expected="$1"
  local label="$2"
  local log_file="$3"
  local status="$4"
  local expected_pattern="${5:-}"
  case_count=$((case_count + 1))
  if [[ "$expected" == "pass" && "$status" -ne 0 ]]; then
    echo "[supply-chain-test] $label 应通过" >&2
    cat "$log_file" >&2
    exit 1
  fi
  if [[ "$expected" == "fail" && "$status" -eq 0 ]]; then
    echo "[supply-chain-test] $label 应失败" >&2
    cat "$log_file" >&2
    exit 1
  fi
  if [[ -n "$expected_pattern" ]] && ! grep -E -q -- "$expected_pattern" "$log_file"; then
    echo "[supply-chain-test] $label 未命中预期错误：$expected_pattern" >&2
    cat "$log_file" >&2
    exit 1
  fi
  echo "[supply-chain-test] $label: $expected"
}

run_evaluator_case() {
  local label="$1"
  local report_name="$2"
  local exception_name="$3"
  local expected="$4"
  local expected_pattern="${5:-}"
  local sbom_name="${6:-sbom-pass.json}"
  local policy_name="${7:-policy.json}"
  local case_dir="$tmp_dir/evaluator-$case_count"
  local log_file="$case_dir/output.log"
  mkdir -p "$case_dir/reports"
  if [[ "$report_name" != "missing" ]]; then
    cp "$fixture_dir/$report_name" "$case_dir/reports/fixture-app.json"
  fi
  mkdir -p "$case_dir/sbom"
  if [[ "$sbom_name" != "missing" ]]; then
    cp "$fixture_dir/$sbom_name" "$case_dir/sbom/fixture-app.cdx.json"
  fi
  local exception_path="$exception_name"
  if [[ "$exception_path" != /* ]]; then
    exception_path="$fixture_dir/$exception_path"
  fi
  local policy_path="$policy_name"
  if [[ "$policy_path" != /* ]]; then
    policy_path="$fixture_dir/$policy_path"
  fi
  set +e
  (
    cd "$root_dir"
    "$real_bun" "$evaluator" \
      "$policy_path" \
      "$exception_path" \
      "$case_dir/reports" \
      "$case_dir/sbom" \
      "$root_dir" \
      "$case_dir/summary.json" \
      fixture-commit
  ) >"$log_file" 2>&1
  local status=$?
  set -e
  assert_status "$expected" "$label" "$log_file" "$status" "$expected_pattern"
  if [[ "$expected" == "pass" ]]; then
    jq -e '.verdict == "pass" and (.blocking_findings | length == 0)' \
      "$case_dir/summary.json" >/dev/null
  fi
}

make_exception_fixture() {
  local output_path="$1"
  local expires_at="$2"
  jq --arg expires_at "$expires_at" \
    '.exceptions[0].expires_at = $expires_at' \
    "$fixture_dir/exceptions-expired.json" >"$output_path"
}

cat >"$tmp_dir/bin/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

mode="${SUPPLY_CHAIN_FAKE_DOCKER_MODE:-pass}"
if [[ "$1" == "image" && "$2" == "inspect" ]]; then
  [[ "$mode" != "scanner-unavailable" ]]
  exit
fi
if [[ "$1" == "pull" ]]; then
  if [[ "$mode" == "scanner-unavailable" ]]; then
    echo "scanner image download unavailable" >&2
    exit 69
  fi
  exit 0
fi
if [[ "$1" != "run" ]]; then
  echo "unexpected fake docker invocation: $*" >&2
  exit 70
fi
if [[ " $* " == *" --version "* ]]; then
  echo "osv-scanner version: 2.2.4"
  exit 0
fi

reports_dir=""
sbom_dir=""
format=""
args=("$@")
for ((index = 0; index < ${#args[@]}; index++)); do
  if [[ "${args[$index]}" == "-v" ]]; then
    mount="${args[$((index + 1))]}"
    [[ "$mount" == *":/reports" ]] && reports_dir="${mount%:/reports}"
    [[ "$mount" == *":/sbom" ]] && sbom_dir="${mount%:/sbom}"
  fi
  if [[ "${args[$index]}" == "--format" ]]; then
    format="${args[$((index + 1))]}"
  fi
done

if [[ "$mode" == "database-failure" ]]; then
  echo "vulnerability database download failed" >&2
  exit 2
fi
if [[ "$format" == "json" ]]; then
  [[ -n "$reports_dir" ]] || exit 71
  case "$mode" in
    truncated-json) printf '{' >"$reports_dir/fixture-app.json" ;;
    missing-report) : ;;
    marker-leak) cp "$SUPPLY_CHAIN_FIXTURE_DIR/report-marker.json" "$reports_dir/fixture-app.json" ;;
    scanner-finding)
      cp "$SUPPLY_CHAIN_FIXTURE_DIR/report-high.json" "$reports_dir/fixture-app.json"
      exit 1
      ;;
    *) cp "$SUPPLY_CHAIN_FIXTURE_DIR/report-pass.json" "$reports_dir/fixture-app.json" ;;
  esac
  exit 0
fi
if [[ "$format" == "cyclonedx-1-5" ]]; then
  [[ -n "$sbom_dir" ]] || exit 72
  case "$mode" in
    missing-sbom) : ;;
    invalid-sbom) cp "$SUPPLY_CHAIN_FIXTURE_DIR/sbom-invalid-spec.json" "$sbom_dir/fixture-app.cdx.json" ;;
    empty-sbom) cp "$SUPPLY_CHAIN_FIXTURE_DIR/sbom-empty.json" "$sbom_dir/fixture-app.cdx.json" ;;
    *) cp "$SUPPLY_CHAIN_FIXTURE_DIR/sbom-pass.json" "$sbom_dir/fixture-app.cdx.json" ;;
  esac
  exit 0
fi

echo "unexpected fake scanner format: $format" >&2
exit 73
SH
chmod +x "$tmp_dir/bin/docker"

run_check_case() {
  local label="$1"
  local mode="$2"
  local expected="$3"
  local expected_pattern="${4:-}"
  local source_root="${5:-$root_dir}"
  local case_dir="$tmp_dir/check-$case_count"
  local log_file="$case_dir/output.log"
  mkdir -p "$case_dir"
  set +e
  PATH="$tmp_dir/bin:$PATH" \
  SUPPLY_CHAIN_FAKE_DOCKER_MODE="$mode" \
  SUPPLY_CHAIN_FIXTURE_DIR="$fixture_dir" \
  SUPPLY_CHAIN_SOURCE_ROOT="$source_root" \
  SUPPLY_CHAIN_POLICY="$fixture_dir/policy.json" \
  SUPPLY_CHAIN_EXCEPTIONS="$fixture_dir/exceptions-empty.json" \
  SUPPLY_CHAIN_OUTPUT_DIR="$case_dir/artifacts" \
    "$check_script" >"$log_file" 2>&1
  local status=$?
  set -e
  assert_status "$expected" "$label" "$log_file" "$status" "$expected_pattern"
  if [[ "$expected" == "pass" ]]; then
    local source_commit
    source_commit="$(git -C "$source_root" rev-parse HEAD)"
    jq -e --arg commit "$source_commit" '
      .verdict == "pass" and
      .commit == $commit and
      (.modules | length == 1) and
      (.blocking_findings | length == 0)
    ' "$case_dir/artifacts/summary.json" >/dev/null
    jq -e '.bomFormat == "CycloneDX" and (.components | length == 1)' \
      "$case_dir/artifacts/sbom/fixture-app.cdx.json" >/dev/null
  fi
}

run_evaluator_case "正常报告" report-pass.json exceptions-empty.json pass
run_evaluator_case "known high/critical vulnerability" report-high.json exceptions-empty.json fail "blocked by 1 finding"
run_evaluator_case "unknown severity vulnerability" report-unknown-severity.json exceptions-empty.json fail "blocked by 1 finding"
run_evaluator_case "reject license" report-reject-license.json exceptions-empty.json fail "blocked by 1 finding"
run_evaluator_case "expired exception" report-high.json exceptions-expired.json fail "expired or has an invalid"
invalid_month="$tmp_dir/exceptions-invalid-month.json"
invalid_day="$tmp_dir/exceptions-invalid-day.json"
far_future="$tmp_dir/exceptions-far-future.json"
valid_tomorrow="$tmp_dir/exceptions-valid-tomorrow.json"
make_exception_fixture "$invalid_month" "2027-13-01"
make_exception_fixture "$invalid_day" "2027-02-31"
make_exception_fixture "$far_future" "9999-12-31"
tomorrow="$($real_bun -e 'console.log(new Date(Date.now() + 86400000).toISOString().slice(0, 10))')"
make_exception_fixture "$valid_tomorrow" "$tomorrow"
run_evaluator_case "invalid exception month" report-high.json "$invalid_month" fail "invalid expires_at"
run_evaluator_case "invalid exception calendar day" report-high.json "$invalid_day" fail "invalid expires_at"
run_evaluator_case "exception exceeds policy duration" report-high.json "$far_future" fail "exceeds the policy maximum"
run_evaluator_case "valid near-term exception" report-high.json "$valid_tomorrow" pass
"$real_bun" -e '
  import { validateExceptionExpiry } from "./scripts/supply-chain/expiry.ts";
  validateExceptionExpiry("2028-02-29", "2028-02-01", 90);
  validateExceptionExpiry("2028-05-01", "2028-02-01", 90);
  for (const value of ["2027-02-29", "2028-02-30", "2028-13-01", "2028-2-01", "2028-05-02"]) {
    try {
      validateExceptionExpiry(value, "2028-02-01", 90);
      throw new Error(`${value} should fail`);
    } catch (error) {
      if (String(error).includes("should fail")) throw error;
    }
  }
'
case_count=$((case_count + 1))
echo "[supply-chain-test] strict UTC calendar and leap day: pass"
run_evaluator_case "missing exception owner" report-high.json exceptions-missing-owner.json fail "missing or unknown fields"
run_evaluator_case "wildcard exception" report-high.json exceptions-wildcard.json fail "must be exact"
valid_unused="$tmp_dir/exceptions-unused-valid-date.json"
jq --arg expires_at "$tomorrow" '.exceptions[0].expires_at = $expires_at' \
  "$fixture_dir/exceptions-unused.json" >"$valid_unused"
run_evaluator_case "unused exception" report-pass.json "$valid_unused" fail "unused exceptions are forbidden"
policy_without_expiry="$tmp_dir/policy-without-expiry.json"
jq 'del(.exceptions)' "$fixture_dir/policy.json" >"$policy_without_expiry"
run_evaluator_case "missing exception validity policy" report-pass.json exceptions-empty.json fail \
  "max_validity_days must be a safe integer between 1 and 90" sbom-pass.json "$policy_without_expiry"
for invalid_max in 91 90.5 9007199254740992; do
  invalid_policy="$tmp_dir/policy-invalid-max-${invalid_max}.json"
  jq --argjson invalid_max "$invalid_max" \
    '.exceptions.max_validity_days = $invalid_max' \
    "$fixture_dir/policy.json" >"$invalid_policy"
  run_evaluator_case "invalid exception policy maximum $invalid_max" \
    report-pass.json exceptions-empty.json fail \
    "max_validity_days must be a safe integer between 1 and 90" \
    sbom-pass.json "$invalid_policy"
done
run_evaluator_case "truncated report JSON" report-truncated.json exceptions-empty.json fail "JSON Parse error"
run_evaluator_case "missing module report" missing exceptions-empty.json fail "ENOENT"
run_evaluator_case "partial report mismatches SBOM" report-pass.json exceptions-empty.json fail "identities do not match" sbom-partial-mismatch.json
run_evaluator_case "report and SBOM synchronously truncate lockfile" report-pass.json exceptions-empty.json fail "does not cover the complete lockfile" sbom-pass.json policy-complete-two.json

run_check_case "隔离扫描正常通过" pass pass

untrusted_source="$tmp_dir/untrusted-source"
mkdir -p "$untrusted_source/tests/fixtures/supply-chain"
cp "$fixture_dir/fixture.lock" "$untrusted_source/tests/fixtures/supply-chain/fixture.lock"
git -C "$untrusted_source" init -q
git -C "$untrusted_source" -c user.name=Fixture -c user.email=fixture@example.invalid \
  add tests/fixtures/supply-chain/fixture.lock
git -C "$untrusted_source" -c user.name=Fixture -c user.email=fixture@example.invalid \
  commit -q -m fixture
run_check_case "trusted gate scans separate source checkout" pass pass "" "$untrusted_source"

run_check_case "scanner unavailable" scanner-unavailable fail "scanner image download unavailable"
run_check_case "vulnerability DB/download failure" database-failure fail "OSV-Scanner failed"
run_check_case "scanner truncated JSON" truncated-json fail "parse error"
run_check_case "scanner missing report" missing-report fail "No such file or directory"
run_check_case "sensitive marker leakage" marker-leak fail "sensitive marker leaked"
run_check_case "scanner exit 1 with valid finding" scanner-finding fail "blocked by 1 finding"
run_check_case "scanner missing SBOM" missing-sbom fail
run_check_case "scanner invalid SBOM version" invalid-sbom fail
run_check_case "scanner empty SBOM" empty-sbom fail

echo "[supply-chain-test] $case_count 个正负场景全部通过"
