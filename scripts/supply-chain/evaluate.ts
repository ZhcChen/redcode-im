import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";

type Exception = {
  type: "vulnerability" | "license";
  module: string;
  ecosystem: string;
  package: string;
  version: string;
  finding: string;
  owner: string;
  reason: string;
  expires_at: string;
};

const [policyPath, exceptionsPath, reportsDir, sbomDir, sourceRoot, outputPath, commit] =
  process.argv.slice(2);
if (
  !policyPath ||
  !exceptionsPath ||
  !reportsDir ||
  !sbomDir ||
  !sourceRoot ||
  !outputPath ||
  !commit
) {
  throw new Error(
    "usage: evaluate.ts <policy> <exceptions> <reports-dir> <sbom-dir> <source-root> <summary> <commit>",
  );
}

const policy = JSON.parse(await readFile(policyPath, "utf8"));
const exceptionDocument = JSON.parse(await readFile(exceptionsPath, "utf8"));
if (policy.schema_version !== 1 || exceptionDocument.schema_version !== 1) {
  throw new Error("unsupported supply-chain policy schema");
}
const exceptions = exceptionDocument.exceptions as Exception[];
if (!Array.isArray(exceptions)) throw new Error("exceptions must be an array");

const today = new Date().toISOString().slice(0, 10);
const exactToken = /^[^*?\s][^*?]*$/;
for (const [index, item] of exceptions.entries()) {
  const keys = Object.keys(item).sort().join(",");
  const expected = "ecosystem,expires_at,finding,module,owner,package,reason,type,version";
  if (keys !== expected) throw new Error(`exception ${index} has missing or unknown fields`);
  if (!["vulnerability", "license"].includes(item.type)) throw new Error(`exception ${index} has invalid type`);
  for (const field of ["module", "ecosystem", "package", "version", "finding", "owner", "reason"] as const) {
    if (!exactToken.test(item[field])) throw new Error(`exception ${index} field ${field} must be exact`);
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(item.expires_at) || item.expires_at < today) {
    throw new Error(`exception ${index} is expired or has an invalid expires_at`);
  }
}

const usedExceptions = new Set<number>();
const blocking: any[] = [];
const accepted: any[] = [];
const moduleSummaries: any[] = [];

function isProjectComponent(module: string, pkg: any): boolean {
  return policy.project_components.some(
    (item: any) =>
      item.module === module &&
      item.ecosystem === pkg.ecosystem &&
      item.name === pkg.name &&
      item.version === pkg.version,
  );
}

function routeFinding(finding: any) {
  const exceptionIndex = exceptions.findIndex(
    (item) =>
      item.type === finding.type &&
      item.module === finding.module &&
      item.ecosystem === finding.ecosystem &&
      item.package === finding.package &&
      item.version === finding.version &&
      item.finding === finding.finding,
  );
  if (exceptionIndex >= 0) {
    usedExceptions.add(exceptionIndex);
    accepted.push({ ...finding, exception: exceptions[exceptionIndex] });
  } else {
    blocking.push(finding);
  }
}

for (const module of policy.modules) {
  const reportPath = join(reportsDir, `${module.name}.json`);
  const raw = await readFile(reportPath, "utf8");
  const report = JSON.parse(raw);
  const packages = (report.results ?? []).flatMap((result: any) => result.packages ?? []);
  if (packages.length === 0) throw new Error(`${module.name} report contains no packages`);
  const packageIdentities = packages.map((entry: any) => {
    const pkg = entry.package;
    if (!pkg?.ecosystem || !pkg?.name || !pkg?.version) {
      throw new Error(`${module.name} report contains an incomplete package identity`);
    }
    return `${pkg.name}@${pkg.version}`;
  });
  if (new Set(packageIdentities).size !== packageIdentities.length) {
    throw new Error(`${module.name} report contains duplicate package identities`);
  }

  const sbom = JSON.parse(await readFile(join(sbomDir, `${module.name}.cdx.json`), "utf8"));
  if (sbom.bomFormat !== "CycloneDX" || sbom.specVersion !== "1.5") {
    throw new Error(`${module.name} SBOM has an invalid CycloneDX schema`);
  }
  if (!Array.isArray(sbom.components) || sbom.components.length === 0) {
    throw new Error(`${module.name} SBOM contains no components`);
  }
  const sbomIdentities = sbom.components.map((component: any) => {
    if (!component?.name || !component?.version || !component?.purl) {
      throw new Error(`${module.name} SBOM contains an incomplete component identity`);
    }
    return `${component.name}@${component.version}`;
  });
  if (new Set(sbomIdentities).size !== sbomIdentities.length) {
    throw new Error(`${module.name} SBOM contains duplicate component identities`);
  }
  const reportSet = [...packageIdentities].sort();
  const sbomSet = [...sbomIdentities].sort();
  if (JSON.stringify(reportSet) !== JSON.stringify(sbomSet)) {
    throw new Error(`${module.name} report and SBOM package identities do not match`);
  }
  const sbomCommit = sbom.metadata?.properties?.find(
    (property: any) => property.name === "redcode:commit",
  )?.value;
  if (sbomCommit !== commit) {
    throw new Error(`${module.name} SBOM is not bound to commit ${commit}`);
  }

  let vulnerabilityCount = 0;
  let licenseViolationCount = 0;
  for (const entry of packages) {
    const pkg = entry.package;
    for (const group of entry.groups ?? []) {
      const finding = String(group.ids?.[0] ?? "");
      if (!finding) throw new Error(`${module.name} vulnerability has no stable id`);
      const numericSeverity = Number.parseFloat(String(group.max_severity ?? ""));
      const unknownSeverity = !Number.isFinite(numericSeverity);
      if (
        (unknownSeverity && policy.vulnerabilities.block_unknown_severity) ||
        (!unknownSeverity && numericSeverity >= policy.vulnerabilities.block_cvss_at_or_above)
      ) {
        vulnerabilityCount += 1;
        routeFinding({
          type: "vulnerability",
          module: module.name,
          ecosystem: pkg.ecosystem,
          package: pkg.name,
          version: pkg.version,
          finding,
          severity: unknownSeverity ? "unknown" : numericSeverity,
        });
      }
    }
    if (!isProjectComponent(module.name, pkg)) {
      for (const license of entry.license_violations ?? []) {
        licenseViolationCount += 1;
        routeFinding({
          type: "license",
          module: module.name,
          ecosystem: pkg.ecosystem,
          package: pkg.name,
          version: pkg.version,
          finding: String(license),
        });
      }
    }
  }
  moduleSummaries.push({
    module: module.name,
    lockfile: module.lockfile,
    scope: module.scope ?? "all",
    lockfile_sha256: createHash("sha256")
      .update(await readFile(join(sourceRoot, module.lockfile)))
      .digest("hex"),
    packages: packages.length,
    sbom_components: sbom.components.length,
    blocking_vulnerabilities_seen: vulnerabilityCount,
    license_violations_seen: licenseViolationCount,
  });
}

const unused = exceptions.map((item, index) => ({ item, index })).filter(({ index }) => !usedExceptions.has(index));
if (unused.length > 0) {
  throw new Error(`unused exceptions are forbidden: ${unused.map(({ index }) => index).join(",")}`);
}

const summary = {
  schema_version: 1,
  generated_at: new Date().toISOString(),
  commit,
  policy_sha256: createHash("sha256").update(await readFile(policyPath)).digest("hex"),
  exceptions_sha256: createHash("sha256").update(await readFile(exceptionsPath)).digest("hex"),
  modules: moduleSummaries,
  accepted_exceptions: accepted,
  blocking_findings: blocking,
  verdict: blocking.length === 0 ? "pass" : "fail",
};
await writeFile(outputPath, `${JSON.stringify(summary, null, 2)}\n`);
if (blocking.length > 0) {
  console.error(`supply-chain gate blocked by ${blocking.length} finding(s)`);
  process.exit(1);
}
