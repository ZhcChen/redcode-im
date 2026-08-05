import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { basename } from "node:path";

type Pin = {
  identity: string;
  kind: string;
  location: string;
  state: { revision: string; version?: string };
};

type Policy = {
  licenses: { allow: string[] };
  swift_license_evidence: Array<{
    identity: string;
    location: string;
    version: string;
    revision: string;
    license: string;
    url: string;
    sha256: string;
  }>;
};

const [lockPath, policyPath, reportPath, sbomPath, commit] = process.argv.slice(2);
if (!lockPath || !policyPath || !reportPath || !sbomPath || !commit) {
  throw new Error("usage: scan-swift.ts <lock> <policy> <report> <sbom> <commit>");
}

const lock = JSON.parse(await readFile(lockPath, "utf8")) as { version: number; pins: Pin[] };
const policy = JSON.parse(await readFile(policyPath, "utf8")) as Policy;
if (lock.version !== 3 || !Array.isArray(lock.pins) || lock.pins.length === 0) {
  throw new Error("ios-app/Package.resolved must be a non-empty SwiftPM v3 lockfile");
}

const packages = [];
for (const pin of lock.pins) {
  const version = pin.state.version;
  if (pin.kind !== "remoteSourceControl" || !version || !pin.state.revision) {
    throw new Error(`unsupported SwiftPM pin: ${pin.identity}`);
  }
  const evidence = policy.swift_license_evidence.find(
    (item) =>
      item.identity === pin.identity &&
      item.location === pin.location &&
      item.version === version &&
      item.revision === pin.state.revision,
  );
  if (!evidence) {
    throw new Error(`missing revision-bound license evidence for ${pin.identity}@${version}`);
  }
  const response = await fetch(evidence.url, { signal: AbortSignal.timeout(30_000) });
  if (!response.ok) {
    throw new Error(`license evidence unavailable for ${pin.identity}: HTTP ${response.status}`);
  }
  const licenseBytes = new Uint8Array(await response.arrayBuffer());
  const digest = createHash("sha256").update(licenseBytes).digest("hex");
  if (digest !== evidence.sha256) {
    throw new Error(`license evidence checksum mismatch for ${pin.identity}`);
  }
  packages.push({ pin, version, evidence });
}

const osvResponse = await fetch("https://api.osv.dev/v1/querybatch", {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({
    queries: packages.map(({ pin, version }) => ({
      package: { ecosystem: "SwiftURL", name: pin.location },
      version,
    })),
  }),
  signal: AbortSignal.timeout(30_000),
});
if (!osvResponse.ok) {
  throw new Error(`OSV SwiftURL query unavailable: HTTP ${osvResponse.status}`);
}
const osv = (await osvResponse.json()) as { results?: Array<{ vulns?: unknown[] }> };
if (!Array.isArray(osv.results) || osv.results.length !== packages.length) {
  throw new Error("OSV SwiftURL response is incomplete");
}

function severityOf(vulnerability: any): string {
  const named = String(vulnerability?.database_specific?.severity ?? "").toUpperCase();
  const namedScores: Record<string, string> = {
    LOW: "2.0",
    MODERATE: "5.0",
    MEDIUM: "5.0",
    HIGH: "8.0",
    CRITICAL: "9.5",
  };
  if (namedScores[named]) return namedScores[named];
  for (const severity of vulnerability?.severity ?? []) {
    if (/^\d+(\.\d+)?$/.test(String(severity?.score ?? ""))) return String(severity.score);
  }
  return "";
}

const reportPackages = packages.map(({ pin, version, evidence }, index) => {
  const vulns = osv.results![index]?.vulns ?? [];
  return {
    package: { ecosystem: "SwiftURL", name: pin.location, version },
    licenses: [evidence.license],
    license_violations: policy.licenses.allow.includes(evidence.license) ? [] : [evidence.license],
    groups: vulns.map((vulnerability: any) => ({
      ids: [String(vulnerability.id)],
      aliases: vulnerability.aliases ?? [],
      max_severity: severityOf(vulnerability),
    })),
  };
});

await writeFile(
  reportPath,
  `${JSON.stringify(
    {
      results: [{ source: { path: lockPath, type: "swift" }, packages: reportPackages }],
      license_summary: Object.entries(
        reportPackages.reduce<Record<string, number>>((summary, item) => {
          summary[item.licenses[0]] = (summary[item.licenses[0]] ?? 0) + 1;
          return summary;
        }, {}),
      ).map(([name, count]) => ({ name, count })),
    },
    null,
    2,
  )}\n`,
);

const components = packages.map(({ pin, version, evidence }) => ({
  type: "library",
  "bom-ref": `pkg:swift/${pin.location.replace(/^https:\/\//, "").replace(/\.git$/, "")}/${pin.identity}@${version}`,
  name: pin.identity,
  version,
  purl: `pkg:swift/${pin.location.replace(/^https:\/\//, "").replace(/\.git$/, "")}/${pin.identity}@${version}`,
  licenses: [{ license: { id: evidence.license } }],
  externalReferences: [{ type: "vcs", url: `${pin.location}@${pin.state.revision}` }],
  properties: [{ name: "redcode:revision", value: pin.state.revision }],
}));
await writeFile(
  sbomPath,
  `${JSON.stringify(
    {
      bomFormat: "CycloneDX",
      specVersion: "1.5",
      serialNumber: `urn:uuid:${crypto.randomUUID()}`,
      version: 1,
      metadata: {
        timestamp: new Date().toISOString(),
        tools: [{ vendor: "RedCode IM", name: basename(import.meta.path), version: "1" }],
        component: { type: "application", name: "ios-app", version: commit },
        properties: [{ name: "redcode:commit", value: commit }],
      },
      components,
      dependencies: components.map((component) => ({ ref: component["bom-ref"], dependsOn: [] })),
    },
    null,
    2,
  )}\n`,
);
