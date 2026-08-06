import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dir, "../..");

const wasmBuildScript = await readFile(
  resolve(root, "scripts/build-e2ee-wasm.sh"),
  "utf8",
);
const h5Package = JSON.parse(
  await readFile(resolve(root, "h5-app/package.json"), "utf8"),
);

assert.equal(h5Package.scripts["e2ee:build"], "../scripts/build-e2ee-wasm.sh");
assert.equal(h5Package.scripts.build, "vue-tsc --noEmit && vite build");
assert.equal(
  h5Package.scripts["build:with-e2ee"],
  "bun run e2ee:build && bun run build",
);
assert.match(wasmBuildScript, /uname -s.*Linux/s);
assert.match(wasmBuildScript, /uname -m.*x86_64/s);
assert.match(wasmBuildScript, /rustc --version.*1\.94\.0/s);
assert.match(wasmBuildScript, /wasm-pack --version.*0\.15\.0/s);
assert.match(wasmBuildScript, /--remap-path-prefix=\$\{ROOT_DIR\}=\/workspace/);
assert.match(wasmBuildScript, /--remap-path-prefix=\$\{CARGO_HOME\}=\/cargo-home/);
assert.match(wasmBuildScript, /--remap-path-prefix=\$\{RUST_SYSROOT\}=\/rust-toolchain/);
assert.match(wasmBuildScript, /wasm-pack build "\$\{ROOT_DIR\}\/e2ee-core"/);

async function parseWorkflow(path: string): Promise<any> {
  return Bun.YAML.parse(await readFile(resolve(root, path), "utf8"));
}

function needs(job: any): string[] {
  return Array.isArray(job.needs) ? job.needs : job.needs ? [job.needs] : [];
}

function stepByName(job: any, name: string): any {
  const step = job.steps?.find((candidate: any) => candidate.name === name);
  assert.ok(step, `missing workflow step: ${name}`);
  return step;
}

function validateGateJob(job: any, artifactRetention: number): void {
  assert.match(
    stepByName(job, "Verify fail-closed fixtures").run,
    /^(make supply-chain\.test|make -C \.supply-chain-gate supply-chain\.test)$/,
  );
  assert.match(
    stepByName(job, "Scan six locked dependency sets").run,
    /^(make supply-chain\.check|\.supply-chain-gate\/scripts\/supply-chain\/check\.sh)$/,
  );

  const validation = stepByName(job, "Validate machine reports").run as string;
  assert.match(validation, /\.verdict == "pass"/);
  assert.match(validation, /\.commit == \$commit/);
  assert.match(validation, /--arg commit "\$(GITHUB_SHA|SOURCE_SHA)"/);
  assert.match(validation, /\.modules \| length == 6/);
  assert.match(validation, /\.blocking_findings \| length == 0/);
  assert.match(validation, /reports[\s\S]*-eq 6/);
  assert.match(validation, /sbom[\s\S]*-eq 6/);
  assert.doesNotMatch(validation, /\|\|\s*true/);

  const checkout =
    job.steps?.find((step: any) =>
      ["Checkout", "Checkout trusted gate"].includes(step.name),
    ) ?? null;
  assert.ok(checkout, "missing trusted checkout");
  assert.equal(
    checkout.uses,
    "actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09",
  );
  const setupBun = stepByName(job, "Setup Bun");
  assert.equal(
    setupBun.uses,
    "oven-sh/setup-bun@0c5077e51419868618aeaa5fe8019c62421857d6",
  );

  const upload = stepByName(job, "Upload supply-chain evidence");
  assert.equal(
    upload.if,
    undefined,
    "failed scans must not upload potentially sensitive reports",
  );
  assert.equal(
    upload.uses,
    "actions/upload-artifact@b7c566a772e6b6bfb58ed0dc250532a479d7789f",
  );
  assert.equal(upload.with["if-no-files-found"], "error");
  assert.equal(upload.with["retention-days"], artifactRetention);
}

function validateReleaseDependencies(workflow: any): void {
  for (const jobName of [
    "android-app-check",
    "api-build",
    "h5-app-build",
    "publish-release",
  ]) {
    assert.ok(
      needs(workflow.jobs[jobName]).includes("supply-chain-check"),
      `${jobName} can bypass supply-chain-check`,
    );
  }
}

const standalone = await parseWorkflow(".github/workflows/supply-chain.yml");
assert.ok(standalone.on.pull_request_target !== undefined);
assert.deepEqual(standalone.on.push.branches, ["main"]);
assert.ok(standalone.on.workflow_dispatch !== undefined);
validateGateJob(standalone.jobs["supply-chain-check"], 30);
const trustedCheckout = stepByName(
  standalone.jobs["supply-chain-check"],
  "Checkout trusted gate",
);
assert.match(trustedCheckout.with.ref, /pull_request\.base\.sha/);
const sourceCheckout = stepByName(
  standalone.jobs["supply-chain-check"],
  "Checkout untrusted source",
);
assert.equal(sourceCheckout.with.repository, "${{ env.SOURCE_REPOSITORY }}");
assert.equal(sourceCheckout.with["persist-credentials"], false);
assert.match(standalone.concurrency.group, /pull_request\.number/);
assert.equal(
  stepByName(
    standalone.jobs["supply-chain-check"],
    "Verify fail-closed fixtures",
  ).run,
  "make -C .supply-chain-gate supply-chain.test",
);
assert.equal(
  stepByName(
    standalone.jobs["supply-chain-check"],
    "Scan six locked dependency sets",
  ).run,
  ".supply-chain-gate/scripts/supply-chain/check.sh",
);

const release = await parseWorkflow(".github/workflows/release-artifacts.yml");
validateGateJob(release.jobs["supply-chain-check"], 90);
validateReleaseDependencies(release);
const androidJob = release.jobs["android-app-check"];
const androidSteps = androidJob.steps;
const buildHostIndex = androidSteps.findIndex(
  (step: any) => step.name === "Build E2EE host library",
);
const androidTestIndex = androidSteps.findIndex(
  (step: any) => step.name === "Run unit tests",
);
assert.ok(buildHostIndex >= 0 && buildHostIndex < androidTestIndex);
assert.match(
  stepByName(androidJob, "Build E2EE host library").run,
  /cargo build --locked --manifest-path e2ee-core\/Cargo\.toml --release/,
);
assert.equal(
  stepByName(androidJob, "Build E2EE host library")["working-directory"],
  "${{ github.workspace }}",
);
assert.equal(
  stepByName(androidJob, "Run unit tests").env.E2EE_CORE_LIB_DIR,
  "${{ github.workspace }}/e2ee-core/target/release",
);
const publishSteps = release.jobs["publish-release"].steps;
assert.equal(
  stepByName(release.jobs["publish-release"], "Download Android artifact").with
    .name,
  "android-app-debug",
);
assert.equal(
  stepByName(androidJob, "Upload Android debug APK").with.path,
  "android-app/app/build/outputs/apk/debug/app-debug.apk",
);
assert.equal(
  stepByName(release.jobs["publish-release"], "Download API artifacts").with
    .pattern,
  "api-linux-*-release",
);
assert.equal(
  stepByName(release.jobs["publish-release"], "Download H5 artifact").with.name,
  "h5-app-release",
);
const h5Job = release.jobs["h5-app-build"];
const h5Steps = h5Job.steps;
const endpointValidationIndex = h5Steps.findIndex(
  (step: any) => step.name === "Validate H5 release endpoints",
);
const rustSetupIndex = h5Steps.findIndex(
  (step: any) => step.name === "Setup pinned H5 Rust toolchain",
);
const wasmPackInstallIndex = h5Steps.findIndex(
  (step: any) => step.name === "Install pinned wasm-pack",
);
assert.ok(
  endpointValidationIndex >= 0 &&
    endpointValidationIndex < rustSetupIndex &&
    rustSetupIndex < wasmPackInstallIndex,
);
assert.match(
  stepByName(h5Job, "Validate H5 release endpoints").run,
  /H5_RELEASE_API_BASE_URL repository variable is required/,
);
assert.match(
  stepByName(h5Job, "Validate H5 release endpoints").run,
  /H5_RELEASE_WS_URL repository variable is required/,
);
assert.equal(release.env.H5_RUST_VERSION, "1.94.0");
assert.match(
  stepByName(h5Job, "Setup pinned H5 Rust toolchain").run,
  /rustup toolchain install "\$H5_RUST_VERSION" --profile minimal --target wasm32-unknown-unknown/,
);
assert.match(
  stepByName(h5Job, "Setup pinned H5 Rust toolchain").run,
  /rustc --version.*H5_RUST_VERSION/s,
);
assert.equal(
  stepByName(h5Job, "Attest H5 candidate provenance").uses,
  "actions/attest-build-provenance@78e6cbd37d0ac1a40113c04f2037dacf1ea3f12e",
);
assert.equal(h5Job.permissions["id-token"], "write");
assert.equal(h5Job.permissions.attestations, "write");
assert.equal(h5Job.permissions.contents, "read");
assert.match(
  stepByName(h5Job, "Build and verify H5 candidate").run,
  /make e2ee-core\.build\.h5[\s\S]*make h5-app\.release\.build/,
);
assert.equal(
  stepByName(h5Job, "Attest H5 candidate provenance").with["subject-path"],
  ".artifacts/h5-release/redcode-im-h5-${{ github.sha }}.tar.gz",
);
assert.ok(needs(release.jobs["publish-release"]).includes("h5-app-build"));
const tagVerification = stepByName(
  release.jobs["publish-release"],
  "Verify release tag source commit",
).run as string;
assert.match(tagVerification, /refs\/tags\/\$\{RELEASE_TAG\}\^\{commit\}/);
assert.match(tagVerification, /TAG_COMMIT.*GITHUB_SHA/s);
assert.match(
  stepByName(release.jobs["publish-release"], "Create or update GitHub release")
    .run,
  /--target "\$\{GITHUB_SHA\}"/,
);
assert.ok(
  !publishSteps.some(
    (step: any) => step.with?.pattern === "supply-chain-release-*",
  ),
  "supply-chain evidence must not be flattened into release assets",
);

const policy = JSON.parse(
  await readFile(resolve(root, "config/supply-chain/policy.json"), "utf8"),
);
assert.ok(
  policy.modules.some(
    (module: any) =>
      module.name === "ios-app" &&
      module.lockfile === "ios-app/Package.resolved",
  ),
  "disabled iOS build must not remove iOS lockfile scanning",
);

const bypassFixture = structuredClone(release);
bypassFixture.jobs["api-build"].needs = needs(
  bypassFixture.jobs["api-build"],
).filter((dependency) => dependency !== "supply-chain-check");
assert.throws(
  () => validateReleaseDependencies(bypassFixture),
  /api-build can bypass/,
);

console.log(
  "[supply-chain-workflow-test] triggers, artifacts and release dependencies: pass",
);
