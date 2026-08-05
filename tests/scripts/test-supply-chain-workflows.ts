import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dir, "../..");

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
  assert.equal(stepByName(job, "Verify fail-closed fixtures").run, "make supply-chain.test");
  assert.equal(stepByName(job, "Scan six locked dependency sets").run, "make supply-chain.check");

  const validation = stepByName(job, "Validate machine reports").run as string;
  assert.match(validation, /\.modules \| length == 6/);
  assert.match(validation, /\.blocking_findings \| length == 0/);
  assert.match(validation, /reports[\s\S]*-eq 6/);
  assert.match(validation, /sbom[\s\S]*-eq 6/);

  const upload = stepByName(job, "Upload supply-chain evidence");
  assert.equal(upload.if, "always()");
  assert.equal(upload.uses, "actions/upload-artifact@v6");
  assert.equal(upload.with["if-no-files-found"], "error");
  assert.equal(upload.with["retention-days"], artifactRetention);
}

function validateReleaseDependencies(workflow: any): void {
  for (const jobName of ["android-app-check", "api-build", "publish-release"]) {
    assert.ok(
      needs(workflow.jobs[jobName]).includes("supply-chain-check"),
      `${jobName} can bypass supply-chain-check`,
    );
  }
}

const standalone = await parseWorkflow(".github/workflows/supply-chain.yml");
assert.ok(standalone.on.pull_request !== undefined);
assert.deepEqual(standalone.on.push.branches, ["main"]);
assert.ok(standalone.on.workflow_dispatch !== undefined);
validateGateJob(standalone.jobs["supply-chain-check"], 30);

const release = await parseWorkflow(".github/workflows/release-artifacts.yml");
validateGateJob(release.jobs["supply-chain-check"], 90);
validateReleaseDependencies(release);

const policy = JSON.parse(
  await readFile(resolve(root, "config/supply-chain/policy.json"), "utf8"),
);
assert.ok(
  policy.modules.some(
    (module: any) => module.name === "ios-app" && module.lockfile === "ios-app/Package.resolved",
  ),
  "disabled iOS build must not remove iOS lockfile scanning",
);

const bypassFixture = structuredClone(release);
bypassFixture.jobs["api-build"].needs = needs(bypassFixture.jobs["api-build"]).filter(
  (dependency) => dependency !== "supply-chain-check",
);
assert.throws(() => validateReleaseDependencies(bypassFixture), /api-build can bypass/);

console.log("[supply-chain-workflow-test] triggers, artifacts and release dependencies: pass");
