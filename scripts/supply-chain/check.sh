#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_ROOT_DIR="${SUPPLY_CHAIN_SOURCE_ROOT:-$ROOT_DIR}"
POLICY="${SUPPLY_CHAIN_POLICY:-$ROOT_DIR/config/supply-chain/policy.json}"
EXCEPTIONS="${SUPPLY_CHAIN_EXCEPTIONS:-$ROOT_DIR/config/supply-chain/exceptions.json}"
OUTPUT_DIR="${SUPPLY_CHAIN_OUTPUT_DIR:-$ROOT_DIR/.artifacts/supply-chain}"
REPORTS_DIR="$OUTPUT_DIR/reports"
SBOM_DIR="$OUTPUT_DIR/sbom"
INPUTS_DIR="$OUTPUT_DIR/inputs"

for command in bun docker jq grep; do
  command -v "$command" >/dev/null 2>&1 || { echo "missing required tool: $command" >&2; exit 1; }
done

test "$(bun --version)" = "$(jq -r '.tools.bun.version' "$POLICY")" || {
  echo "Bun version does not match supply-chain policy" >&2
  exit 1
}

mkdir -p "$REPORTS_DIR" "$SBOM_DIR" "$INPUTS_DIR"
find "$REPORTS_DIR" "$SBOM_DIR" "$INPUTS_DIR" -type f -delete

COMMIT="$(git -C "$SOURCE_ROOT_DIR" rev-parse HEAD)"
IMAGE="$(jq -r '.tools.osv_scanner.image + "@" + .tools.osv_scanner.digest' "$POLICY")"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  docker pull "$IMAGE" >/dev/null
fi
ACTUAL_VERSION="$(docker run --rm "$IMAGE" --version | awk '$1 == "osv-scanner" && $2 == "version:" { print $3 }')"
test "$ACTUAL_VERSION" = "$(jq -r '.tools.osv_scanner.version' "$POLICY")" || {
  echo "OSV-Scanner version does not match supply-chain policy" >&2
  exit 1
}

ALLOW_LICENSES="$(jq -r '.licenses.allow | join(",")' "$POLICY")"
while IFS=$'\t' read -r module lockfile scanner scope; do
  test -s "$SOURCE_ROOT_DIR/$lockfile" || { echo "missing or empty lockfile: $lockfile" >&2; exit 1; }
  if [ "$scanner" = "swift-osv" ]; then
    bun "$ROOT_DIR/scripts/supply-chain/scan-swift.ts" \
      "$SOURCE_ROOT_DIR/$lockfile" "$POLICY" "$REPORTS_DIR/$module.json" "$SBOM_DIR/$module.cdx.json" "$COMMIT"
  else
    module_dir="$(dirname "$lockfile")"
    lock_name="$(basename "$lockfile")"
    if [ "$scope" = "releaseRuntimeClasspath" ]; then
      module_dir="$INPUTS_DIR/$module"
      lock_name="gradle.lockfile"
      mkdir -p "$module_dir"
      awk -F= '
        /^#/ { next }
        NF == 2 && index("," $2 ",", ",releaseRuntimeClasspath,") { print }
      ' "$SOURCE_ROOT_DIR/$lockfile" > "$module_dir/$lock_name"
      test -s "$module_dir/$lock_name" || {
        echo "$module lockfile has no releaseRuntimeClasspath dependencies" >&2
        exit 1
      }
    else
      module_dir="$SOURCE_ROOT_DIR/$module_dir"
    fi
    set +e
    docker run --rm \
      -v "$module_dir:/src:ro" \
      -v "$REPORTS_DIR:/reports" \
      "$IMAGE" scan source \
        --lockfile "/src/$lock_name" \
        --licenses="$ALLOW_LICENSES" \
        --all-vulns \
        --all-packages \
        --format json \
        --output "/reports/$module.json" >/dev/null
    scanner_status=$?
    set -e
    if [ "$scanner_status" -ne 0 ] && [ "$scanner_status" -ne 1 ]; then
      echo "OSV-Scanner failed for $module with status $scanner_status" >&2
      exit 1
    fi
    jq -e '.results | type == "array"' "$REPORTS_DIR/$module.json" >/dev/null

    set +e
    docker run --rm \
      -v "$module_dir:/src:ro" \
      -v "$SBOM_DIR:/sbom" \
      "$IMAGE" scan source \
        --lockfile "/src/$lock_name" \
        --all-packages \
        --format cyclonedx-1-5 \
        --output "/sbom/$module.cdx.json" >/dev/null
    sbom_status=$?
    set -e
    if [ "$sbom_status" -ne 0 ] && [ "$sbom_status" -ne 1 ]; then
      echo "OSV-Scanner SBOM generation failed for $module with status $sbom_status" >&2
      exit 1
    fi
  fi

  sbom_file="$SBOM_DIR/$module.cdx.json"
  sbom_tmp="$sbom_file.tmp"
  jq --arg commit "$COMMIT" '
    .metadata = (.metadata // {}) |
    .metadata.properties = (
      [(.metadata.properties // [])[] | select(.name != "redcode:commit")] +
      [{name:"redcode:commit", value:$commit}]
    )
  ' "$sbom_file" > "$sbom_tmp"
  mv "$sbom_tmp" "$sbom_file"
  jq -e '.bomFormat == "CycloneDX" and .specVersion == "1.5" and (.components | length > 0)' \
    "$sbom_file" >/dev/null
done < <(jq -r '.modules[] | [.name, .lockfile, .scanner, (.scope // "all")] | @tsv' "$POLICY")

for marker in REDCODE_SUPPLY_CHAIN_SECRET_MARKER PRIVATE_KEY_PLACEHOLDER PASSWORD_PLACEHOLDER; do
  if grep -R -F -q -- "$marker" "$REPORTS_DIR" "$SBOM_DIR"; then
    echo "sensitive marker leaked into supply-chain report" >&2
    exit 1
  fi
done

bun "$ROOT_DIR/scripts/supply-chain/evaluate.ts" \
  "$POLICY" "$EXCEPTIONS" "$REPORTS_DIR" "$SBOM_DIR" "$SOURCE_ROOT_DIR" \
  "$OUTPUT_DIR/summary.json" "$COMMIT"

jq -n \
  --arg commit "$COMMIT" \
  --arg scanner_version "$(jq -r '.tools.osv_scanner.version' "$POLICY")" \
  --slurpfile summary "$OUTPUT_DIR/summary.json" \
  '{schema_version:1,commit:$commit,scanner_version:$scanner_version,summary:$summary[0],artifacts:["reports/*.json","sbom/*.cdx.json"]}' \
  > "$OUTPUT_DIR/index.json"

echo "Supply-chain gate passed: $OUTPUT_DIR"
