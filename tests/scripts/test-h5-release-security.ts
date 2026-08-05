import { createHash } from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";

const root = resolve(import.meta.dir, "../..");
const h5 = resolve(root, "h5-app");
const script = resolve(root, "scripts/h5-release-security.ts");
const httpCheckScript = resolve(root, "scripts/h5-release-http-check.ts");
const api = "https://api.release.invalid/v1";
const ws = "wss://api.release.invalid/ws";
let passed = 0;

function run(
  command: "finalize" | "check",
  dist: string,
  extraEnv: Record<string, string> = {},
) {
  return spawnSync("bun", [script, command, dist], {
    cwd: h5,
    encoding: "utf8",
    env: {
      ...process.env,
      H5_RELEASE_ATTESTATION_PATH: `${dist}.attestation.json`,
      H5_RELEASE_TEST_MODE: "true",
      H5_RELEASE_API_BASE_URL: api,
      H5_RELEASE_WS_URL: ws,
      ...extraEnv,
    },
  });
}

async function refreshAttestation(dist: string): Promise<void> {
  const manifestBytes = await readFile(resolve(dist, "release-manifest.json"));
  const manifest = JSON.parse(manifestBytes.toString());
  await writeFile(
    `${dist}.attestation.json`,
    `${JSON.stringify(
      {
        schema: "redcode-h5-release-attestation/v1",
        source_commit: manifest.source_commit,
        manifest_sha256: createHash("sha256")
          .update(manifestBytes)
          .digest("hex"),
      },
      null,
      2,
    )}\n`,
  );
}

async function fixture(): Promise<string> {
  const directory = await mkdtemp(resolve(h5, ".release-security-test-"));
  await writeFile(
    resolve(directory, "index.html"),
    "<!doctype html><script src='/assets/app.js'></script>\n",
  );
  await Bun.write(
    resolve(directory, "assets/app.js"),
    `console.log(${JSON.stringify(api)}, ${JSON.stringify(ws)});\n`,
  );
  return directory;
}

async function scenario(
  name: string,
  mutate: (dist: string) => Promise<void>,
  expected: "pass" | "fail",
  expectedMessage?: string,
) {
  const dist = await fixture();
  try {
    const finalized = run("finalize", dist);
    if (finalized.status !== 0)
      throw new Error(`fixture finalize failed: ${finalized.stderr}`);
    await mutate(dist);
    const result = run("check", dist);
    const actual = result.status === 0 ? "pass" : "fail";
    if (actual !== expected)
      throw new Error(
        `${name}: expected ${expected}, got ${actual}\n${result.stderr}`,
      );
    if (expectedMessage && !result.stderr.includes(expectedMessage)) {
      throw new Error(
        `${name}: missing error ${JSON.stringify(expectedMessage)}\n${result.stderr}`,
      );
    }
    passed += 1;
    console.log(`[h5-release-test] ${name}: ${actual}`);
  } finally {
    await rm(dist, { recursive: true, force: true });
    await rm(`${dist}.attestation.json`, { force: true });
  }
}

await scenario(
  "valid candidate",
  async (dist) => {
    const result = spawnSync("bun", [httpCheckScript, dist], {
      cwd: h5,
      encoding: "utf8",
      env: {
        ...process.env,
        H5_RELEASE_ATTESTATION_PATH: `${dist}.attestation.json`,
        H5_RELEASE_TEST_MODE: "true",
      },
    });
    if (result.status !== 0 || !result.stdout.includes("verified 9 headers")) {
      throw new Error(`candidate HTTP headers failed\n${result.stderr}`);
    }
  },
  "pass",
);
await scenario(
  "tampered asset",
  async (dist) => {
    await writeFile(
      resolve(dist, "assets/app.js"),
      "console.log('tampered');\n",
    );
  },
  "fail",
  "release asset inventory or digest mismatch",
);
await scenario(
  "public source map",
  async (dist) => {
    const manifestPath = resolve(dist, "release-manifest.json");
    await writeFile(resolve(dist, "assets/app.js.map"), "{}\n");
    const finalized = run("finalize", dist);
    if (
      finalized.status === 0 ||
      !finalized.stderr.includes("public source map is forbidden")
    ) {
      throw new Error(
        `source map finalize did not fail closed\n${finalized.stderr}`,
      );
    }
    await refreshAttestation(dist);
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    if (
      !manifest.assets.some((asset: { path: string }) =>
        asset.path.endsWith(".map"),
      )
    ) {
      throw new Error("source map fixture was not inventoried");
    }
  },
  "fail",
  "public source map is forbidden",
);
await scenario(
  "inline source map reference",
  async (dist) => {
    const assetPath = resolve(dist, "assets/app.js");
    await writeFile(
      assetPath,
      `${await readFile(assetPath, "utf8")}//# sourceMappingURL=hidden.map\n`,
    );
    const finalized = run("finalize", dist);
    if (
      finalized.status === 0 ||
      !finalized.stderr.includes("source map reference is forbidden")
    ) {
      throw new Error(
        `source map reference finalize did not fail closed\n${finalized.stderr}`,
      );
    }
    await refreshAttestation(dist);
  },
  "fail",
  "source map reference is forbidden",
);
await scenario(
  "weakened CSP",
  async (dist) => {
    const headersPath = resolve(dist, "security-headers.json");
    const headers = JSON.parse(await readFile(headersPath, "utf8"));
    headers["content-security-policy"] = headers[
      "content-security-policy"
    ].replace(
      "script-src 'self' 'wasm-unsafe-eval'",
      "script-src 'self' 'unsafe-eval'",
    );
    const headersBytes = `${JSON.stringify(headers, null, 2)}\n`;
    await writeFile(headersPath, headersBytes);
    const manifestPath = resolve(dist, "release-manifest.json");
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    manifest.security_headers_sha256 = createHash("sha256")
      .update(headersBytes)
      .digest("hex");
    await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
    await refreshAttestation(dist);
  },
  "fail",
  "CSP is missing exact directive",
);
await scenario(
  "wrong source commit",
  async (dist) => {
    const manifestPath = resolve(dist, "release-manifest.json");
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    manifest.source_commit = "ffffffffffffffffffffffffffffffffffffffff";
    await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  },
  "fail",
  "source commit does not match",
);
await scenario(
  "stale lockfile binding",
  async (dist) => {
    const manifestPath = resolve(dist, "release-manifest.json");
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    manifest.lockfile.sha256 = "0".repeat(64);
    await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
    await refreshAttestation(dist);
  },
  "fail",
  "lockfile binding is stale",
);
await scenario(
  "endpoint differs from built JavaScript",
  async (dist) => {
    const manifestPath = resolve(dist, "release-manifest.json");
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    manifest.endpoints.api_base_url = "https://api.release.invalid/v2";
    await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
    await refreshAttestation(dist);
  },
  "fail",
  "built JavaScript does not bind",
);
await scenario(
  "resource and manifest synchronously tampered",
  async (dist) => {
    const assetPath = resolve(dist, "assets/app.js");
    const bytes = Buffer.from(
      `${await readFile(assetPath, "utf8")}console.log('tampered');\n`,
    );
    await writeFile(assetPath, bytes);
    const manifestPath = resolve(dist, "release-manifest.json");
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    const asset = manifest.assets.find(
      (item: { path: string }) => item.path === "assets/app.js",
    );
    asset.bytes = bytes.byteLength;
    asset.sha256 = createHash("sha256").update(bytes).digest("hex");
    await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  },
  "fail",
  "external attestation",
);
await scenario(
  "unreviewed CSP source",
  async (dist) => {
    const headersPath = resolve(dist, "security-headers.json");
    const headers = JSON.parse(await readFile(headersPath, "utf8"));
    headers["content-security-policy"] += " connect-src *";
    const headersBytes = `${JSON.stringify(headers, null, 2)}\n`;
    await writeFile(headersPath, headersBytes);
    const manifestPath = resolve(dist, "release-manifest.json");
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    manifest.security_headers_sha256 = createHash("sha256")
      .update(headersBytes)
      .digest("hex");
    await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
    await refreshAttestation(dist);
  },
  "fail",
  "security headers do not match",
);

async function finalizeFailure(
  name: string,
  env: Record<string, string>,
  message: string,
) {
  const dist = await fixture();
  try {
    const result = run("finalize", dist, env);
    if (result.status === 0 || !result.stderr.includes(message)) {
      throw new Error(
        `${name} unexpectedly passed or hit the wrong branch\n${result.stderr}`,
      );
    }
    passed += 1;
    console.log(`[h5-release-test] ${name}: fail`);
  } finally {
    await rm(dist, { recursive: true, force: true });
    await rm(`${dist}.attestation.json`, { force: true });
  }
}

await finalizeFailure(
  "insecure API protocol",
  { H5_RELEASE_API_BASE_URL: "http://api.release.invalid/v1" },
  "api URL must use https:",
);
await finalizeFailure(
  "localhost API endpoint",
  { H5_RELEASE_API_BASE_URL: "https://127.0.0.1/v1" },
  "api URL must not target localhost",
);
await finalizeFailure(
  "credentialed API endpoint",
  { H5_RELEASE_API_BASE_URL: "https://user:secret@api.release.invalid/v1" },
  "api URL must not contain credentials",
);
await finalizeFailure(
  "API endpoint query",
  { H5_RELEASE_API_BASE_URL: "https://api.release.invalid/v1?token=secret" },
  "api URL must not contain query or fragment",
);
await finalizeFailure(
  "insecure WebSocket",
  { H5_RELEASE_WS_URL: "ws://api.release.invalid/ws" },
  "ws URL must use wss:",
);

const escaped = run("check", "../outside-release");
if (
  escaped.status === 0 ||
  !escaped.stderr.includes("release output must stay inside h5-app")
) {
  throw new Error(`escaped output path unexpectedly passed\n${escaped.stderr}`);
}
passed += 1;
console.log("[h5-release-test] escaped output path: fail");

console.log(`[h5-release-test] ${passed} 个正负场景全部通过`);
