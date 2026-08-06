import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
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

function run(
  command: string[],
  cwd: string,
  env: Record<string, string> = {},
): ReturnType<typeof Bun.spawnSync> {
  return Bun.spawnSync(command, {
    cwd,
    env: { ...process.env, ...env },
    stdout: "pipe",
    stderr: "pipe",
  });
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
  "android-app-release",
);
assert.equal(
  stepByName(androidJob, "Upload Android release candidate").with.path,
  ".artifacts/android/redcode-im-android-${{ github.sha }}.apk",
);
const androidBuild = stepByName(androidJob, "Build Android release candidate");
assert.match(androidBuild.run, /validate-android-signing\.sh/);
assert.match(androidBuild.run, /assembleRelease/);
assert.match(androidBuild.run, /app-release-unsigned\.apk/);
assert.match(androidBuild.run, /ANDROID_HOME.*build-tools[\s\S]*APKSIGNER/);
assert.match(androidBuild.run, /APKSIGNER.*verify/);
for (const secret of [
  "ANDROID_SIGNING_KEYSTORE_BASE64",
  "ANDROID_SIGNING_STORE_PASSWORD",
  "ANDROID_SIGNING_KEY_ALIAS",
  "ANDROID_SIGNING_KEY_PASSWORD",
]) assert.match(androidBuild.env[secret], new RegExp(`secrets\\.${secret}`));
assert.equal(androidJob.permissions.contents, "read");
assert.equal(androidJob.permissions["id-token"], "write");
assert.equal(androidJob.permissions.attestations, "write");
assert.equal(
  stepByName(androidJob, "Attest Android release candidate provenance").uses,
  "actions/attest-build-provenance@78e6cbd37d0ac1a40113c04f2037dacf1ea3f12e",
);
assert.equal(
  stepByName(androidJob, "Attest Android release candidate provenance").with["subject-path"],
  ".artifacts/android/redcode-im-android-${{ github.sha }}.apk",
);
assert.equal(
  stepByName(release.jobs["publish-release"], "Download API artifacts").with
    .pattern,
  "api-linux-*-release",
);
const apiBuildJob = release.jobs["api-build"];
assert.equal(apiBuildJob.permissions.contents, "read");
assert.equal(apiBuildJob.permissions["id-token"], "write");
assert.equal(apiBuildJob.permissions.attestations, "write");
assert.equal(
  stepByName(apiBuildJob, "Attest API artifacts provenance").uses,
  "actions/attest-build-provenance@78e6cbd37d0ac1a40113c04f2037dacf1ea3f12e",
);
assert.equal(
  stepByName(apiBuildJob, "Attest API artifacts provenance").with["subject-path"],
  ".artifacts/api/*",
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
assert.equal(
  release.jobs["publish-release"].if,
  "github.event_name == 'workflow_dispatch' && inputs.publish_release == true",
);
assert.match(
  stepByName(release.jobs["validate-release-inputs"], "Resolve release tag").run,
  /validate-release-inputs\.sh/,
);
const tagVerification = stepByName(
  release.jobs["publish-release"],
  "Verify release tag source commit",
).run as string;
assert.match(tagVerification, /refs\/tags\/\$\{RELEASE_TAG\}\^\{commit\}/);
assert.match(tagVerification, /TAG_COMMIT.*GITHUB_SHA/s);
assert.match(tagVerification, /must already exist/);
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
const apiReleaseDockerfile = await readFile(
  resolve(root, "api/docker/release/Dockerfile"),
  "utf8",
);
const fromLines = apiReleaseDockerfile.match(/^FROM .+$/gm) ?? [];
assert.equal(fromLines.length, 2);
for (const line of fromLines) {
  assert.match(line, /@sha256:[a-f0-9]{64}(?: AS builder)?$/);
}
assert.match(apiReleaseDockerfile, /FROM rust:1\.94\.0-alpine3\.21@sha256:/);
assert.match(apiReleaseDockerfile, /FROM alpine:3\.21@sha256:/);
assert.equal(
  (apiReleaseDockerfile.match(/cargo build --release --locked/g) ?? []).length,
  2,
);
assert.doesNotMatch(apiReleaseDockerfile, /RUN cargo build --release\s*$/m);
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

const releaseInputScript = resolve(root, "scripts/release/validate-release-inputs.sh");
const signingScript = resolve(root, "scripts/release/validate-android-signing.sh");
const fixture = await mkdtemp(resolve(tmpdir(), "redcode-release-inputs."));
try {
  assert.equal(run(["git", "init", "-q"], fixture).exitCode, 0);
  assert.equal(run(["git", "config", "user.email", "test@example.invalid"], fixture).exitCode, 0);
  assert.equal(run(["git", "config", "user.name", "Release Test"], fixture).exitCode, 0);
  await writeFile(resolve(fixture, "README"), "fixture\n");
  assert.equal(run(["git", "add", "README"], fixture).exitCode, 0);
  assert.equal(run(["git", "commit", "-qm", "fixture"], fixture).exitCode, 0);
  const fixtureHead = run(["git", "rev-parse", "HEAD"], fixture).stdout.toString().trim();
  assert.equal(run(["git", "tag", "v9.9.9-f6test"], fixture).exitCode, 0);
  const baseEnv = {
    EVENT_NAME: "workflow_dispatch",
    GITHUB_REF: "refs/heads/main",
    GITHUB_SHA: fixtureHead,
    INPUT_RELEASE_TAG: "v9.9.9-f6test",
    PUBLISH_RELEASE: "true",
    GITHUB_OUTPUT: "",
  };
  assert.equal(run([releaseInputScript], fixture, baseEnv).exitCode, 0);
  assert.notEqual(run([releaseInputScript], fixture, {
    ...baseEnv,
    GITHUB_REF: "refs/heads/feature",
  }).exitCode, 0);
  assert.notEqual(run([releaseInputScript], fixture, {
    ...baseEnv,
    INPUT_RELEASE_TAG: "v9.9.9-missing",
  }).exitCode, 0);
  await writeFile(resolve(fixture, "README"), "second\n");
  assert.equal(run(["git", "commit", "-qam", "second"], fixture).exitCode, 0);
  const secondHead = run(["git", "rev-parse", "HEAD"], fixture).stdout.toString().trim();
  assert.notEqual(run([releaseInputScript], fixture, {
    ...baseEnv,
    GITHUB_SHA: secondHead,
  }).exitCode, 0);
  assert.notEqual(run([releaseInputScript], fixture, {
    ...baseEnv,
    PUBLISH_RELEASE: "false",
  }).exitCode, 0);
  assert.equal(run([releaseInputScript], fixture, {
    EVENT_NAME: "push",
    GITHUB_REF: "refs/tags/v9.9.9-f6test",
    GITHUB_SHA: fixtureHead,
    INPUT_RELEASE_TAG: "",
    PUBLISH_RELEASE: "false",
    GITHUB_OUTPUT: "",
  }).exitCode, 0);

  assert.equal(run([signingScript], fixture, { PUBLISH_RELEASE: "false" }).exitCode, 0);
  assert.notEqual(run([signingScript], fixture, { PUBLISH_RELEASE: "true" }).exitCode, 0);
  assert.equal(run([signingScript], fixture, {
    PUBLISH_RELEASE: "true",
    ANDROID_SIGNING_KEYSTORE_BASE64: "fixture",
    ANDROID_SIGNING_STORE_PASSWORD: "fixture",
    ANDROID_SIGNING_KEY_ALIAS: "fixture",
    ANDROID_SIGNING_KEY_PASSWORD: "fixture",
  }).exitCode, 0);
} finally {
  await rm(fixture, { recursive: true, force: true });
}

console.log(
  "[supply-chain-workflow-test] triggers, artifacts and release dependencies: pass",
);
