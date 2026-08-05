import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { lstat, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { dirname, relative, resolve, sep } from "node:path";

const root = resolve(dirname(import.meta.path), "..");
const h5Root = resolve(root, "h5-app");
const defaultLockPath = resolve(root, "h5-app/bun.lock");
const policyPath = resolve(root, "config/h5-release/security-headers.json");
const manifestName = "release-manifest.json";
const headersName = "security-headers.json";
const sha256Pattern = /^[a-f0-9]{64}$/;
const commitPattern = /^[a-f0-9]{40}$/;

type Asset = { path: string; bytes: number; sha256: string };
type Headers = Record<string, string>;
type Manifest = {
  schema: "redcode-h5-release/v1";
  source_commit: string;
  lockfile: { path: "h5-app/bun.lock"; sha256: string };
  endpoints: { api_base_url: string; ws_url: string };
  security_headers_sha256: string;
  assets: Asset[];
};
type Attestation = {
  schema: "redcode-h5-release-attestation/v1";
  source_commit: string;
  manifest_sha256: string;
};

function fail(message: string): never {
  throw new Error(`[h5-release] ${message}`);
}

function hash(data: Uint8Array | string): string {
  return createHash("sha256").update(data).digest("hex");
}

function gitCommit(): string {
  const value = execFileSync("git", ["rev-parse", "HEAD"], {
    cwd: root,
    encoding: "utf8",
  }).trim();
  if (!commitPattern.test(value))
    fail("source commit must be a full lowercase Git SHA");
  return value;
}

function attestationPath(commit: string, dist: string): string {
  const configured = process.env.H5_RELEASE_ATTESTATION_PATH;
  if (configured) {
    const path = resolve(configured);
    if (path === dist || path.startsWith(`${dist}${sep}`)) {
      fail(
        "release attestation must stay outside the deployable dist directory",
      );
    }
    return path;
  }
  return resolve(root, ".artifacts/h5-release", `${commit}.json`);
}

function secureEndpoint(
  raw: string | undefined,
  kind: "api" | "ws",
): { url: string; origin: string } {
  if (!raw) fail(`${kind} release URL is required`);
  const value = raw.trim();
  if (value !== raw)
    fail(`${kind} URL must not contain surrounding whitespace`);
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    fail(`${kind} URL is invalid`);
  }
  const protocol = kind === "api" ? "https:" : "wss:";
  if (url.protocol !== protocol) fail(`${kind} URL must use ${protocol}`);
  if (url.username || url.password)
    fail(`${kind} URL must not contain credentials`);
  if (url.search || url.hash)
    fail(`${kind} URL must not contain query or fragment`);
  if (["localhost", "127.0.0.1", "::1"].includes(url.hostname)) {
    fail(`${kind} URL must not target localhost`);
  }
  return { url: value, origin: url.origin };
}

function resolveDist(distArg: string): string {
  const dist = resolve(h5Root, distArg);
  if (!dist.startsWith(`${h5Root}${sep}`))
    fail("release output must stay inside h5-app");
  const isTestFixture =
    process.env.H5_RELEASE_TEST_MODE === "true" &&
    dist.startsWith(`${h5Root}${sep}.release-security-test-`);
  if (dist !== resolve(h5Root, "dist") && !isTestFixture) {
    fail("release output must be h5-app/dist");
  }
  return dist;
}

async function regularFiles(directory: string): Promise<string[]> {
  const result: string[] = [];
  async function visit(current: string): Promise<void> {
    for (const entry of await readdir(current, { withFileTypes: true })) {
      const path = resolve(current, entry.name);
      const stat = await lstat(path);
      if (stat.isSymbolicLink())
        fail(`symbolic link is forbidden: ${relative(directory, path)}`);
      if (stat.isDirectory()) await visit(path);
      else if (stat.isFile()) result.push(path);
      else fail(`unsupported output entry: ${relative(directory, path)}`);
    }
  }
  await visit(directory);
  return result.sort((a, b) => a.localeCompare(b));
}

async function assetFor(dist: string, path: string): Promise<Asset> {
  const bytes = await readFile(path);
  return {
    path: relative(dist, path).split(sep).join("/"),
    bytes: bytes.byteLength,
    sha256: hash(bytes),
  };
}

async function validateCspCompatibleSource(): Promise<void> {
  const sourceRoot = resolve(h5Root, "src");
  for (const path of await regularFiles(sourceRoot)) {
    if (!path.endsWith(".vue")) continue;
    const source = await readFile(path, "utf8");
    if (/(?:\s:style=|\sv-bind:style=|\sstyle=)/.test(source)) {
      fail(
        `inline style is incompatible with strict CSP: ${relative(h5Root, path)}`,
      );
    }
  }
}

function validateHeaders(
  headers: Headers,
  apiOrigin: string,
  wsOrigin: string,
): void {
  const required = [
    "cache-control",
    "content-security-policy",
    "cross-origin-opener-policy",
    "cross-origin-resource-policy",
    "permissions-policy",
    "referrer-policy",
    "strict-transport-security",
    "x-content-type-options",
    "x-frame-options",
  ];
  if (Object.keys(headers).sort().join("\n") !== required.sort().join("\n")) {
    fail("security header set is incomplete or contains an unreviewed header");
  }
  const csp = headers["content-security-policy"];
  const directives = [
    "default-src 'none'",
    "base-uri 'self'",
    "frame-ancestors 'none'",
    "object-src 'none'",
    "script-src 'self' 'wasm-unsafe-eval'",
    "style-src 'self'",
  ];
  for (const directive of directives) {
    if (
      !csp
        .split(";")
        .map((item) => item.trim())
        .includes(directive)
    ) {
      fail(`CSP is missing exact directive: ${directive}`);
    }
  }
  if (/(^|\s)'unsafe-(inline|eval)'(\s|;|$)/.test(csp))
    fail("CSP contains unsafe-inline or unsafe-eval");
  const connect = csp
    .split(";")
    .map((item) => item.trim())
    .find((item) => item.startsWith("connect-src "));
  if (
    !connect ||
    !connect.split(/\s+/).includes(apiOrigin) ||
    !connect.split(/\s+/).includes(wsOrigin)
  ) {
    fail("CSP connect-src does not bind the release API and WebSocket origins");
  }
  if (headers["x-content-type-options"] !== "nosniff")
    fail("X-Content-Type-Options must be nosniff");
  if (headers["cache-control"] !== "no-store")
    fail("Cache-Control must be no-store");
  if (headers["x-frame-options"] !== "DENY")
    fail("X-Frame-Options must be DENY");
  if (headers["referrer-policy"] !== "no-referrer")
    fail("Referrer-Policy must be no-referrer");
  if (!headers["strict-transport-security"].startsWith("max-age=63072000"))
    fail("HSTS is too weak");
}

async function renderHeaders(
  apiOrigin: string,
  wsOrigin: string,
): Promise<Headers> {
  const template = JSON.parse(await readFile(policyPath, "utf8")) as Headers;
  const connectSources = [...new Set(["'self'", apiOrigin, wsOrigin])].join(
    " ",
  );
  const headers = Object.fromEntries(
    Object.entries(template).map(([name, value]) => [
      name,
      value.replace("{{CONNECT_SRC}}", connectSources),
    ]),
  );
  validateHeaders(headers, apiOrigin, wsOrigin);
  return headers;
}

async function finalize(distArg: string): Promise<void> {
  const dist = resolveDist(distArg);
  await validateCspCompatibleSource();
  const api = secureEndpoint(process.env.H5_RELEASE_API_BASE_URL, "api");
  const ws = secureEndpoint(process.env.H5_RELEASE_WS_URL, "ws");
  const headers = await renderHeaders(api.origin, ws.origin);
  const headersBytes = `${JSON.stringify(headers, null, 2)}\n`;
  await writeFile(resolve(dist, headersName), headersBytes);

  const files = (await regularFiles(dist)).filter(
    (path) => relative(dist, path) !== manifestName,
  );
  if (files.length === 0) fail("release output is empty");
  const assets = await Promise.all(files.map((path) => assetFor(dist, path)));
  const manifest: Manifest = {
    schema: "redcode-h5-release/v1",
    source_commit: gitCommit(),
    lockfile: {
      path: "h5-app/bun.lock",
      sha256: hash(await readFile(defaultLockPath)),
    },
    endpoints: { api_base_url: api.url, ws_url: ws.url },
    security_headers_sha256: hash(headersBytes),
    assets,
  };
  const manifestBytes = `${JSON.stringify(manifest, null, 2)}\n`;
  await writeFile(resolve(dist, manifestName), manifestBytes);
  await checkInternal(distArg, false);
  const evidencePath = attestationPath(manifest.source_commit, dist);
  const attestation: Attestation = {
    schema: "redcode-h5-release-attestation/v1",
    source_commit: manifest.source_commit,
    manifest_sha256: hash(manifestBytes),
  };
  await mkdir(dirname(evidencePath), { recursive: true });
  await writeFile(evidencePath, `${JSON.stringify(attestation, null, 2)}\n`);
  await checkInternal(distArg, true);
  console.log(
    `[h5-release] finalized ${assets.length} assets for ${manifest.source_commit}`,
  );
}

async function checkInternal(
  distArg: string,
  requireAttestation: boolean,
): Promise<void> {
  const dist = resolveDist(distArg);
  const manifest = JSON.parse(
    await readFile(resolve(dist, manifestName), "utf8"),
  ) as Manifest;
  if (manifest.schema !== "redcode-h5-release/v1")
    fail("unsupported release manifest schema");
  if (
    !commitPattern.test(manifest.source_commit) ||
    manifest.source_commit !== gitCommit()
  ) {
    fail("release manifest source commit does not match the requested commit");
  }
  if (requireAttestation) {
    const evidence = JSON.parse(
      await readFile(attestationPath(manifest.source_commit, dist), "utf8"),
    ) as Attestation;
    if (
      evidence.schema !== "redcode-h5-release-attestation/v1" ||
      evidence.source_commit !== manifest.source_commit ||
      !sha256Pattern.test(evidence.manifest_sha256) ||
      evidence.manifest_sha256 !==
        hash(await readFile(resolve(dist, manifestName)))
    ) {
      fail("release manifest does not match the external attestation");
    }
  }
  const lockDigest = hash(await readFile(defaultLockPath));
  if (
    manifest.lockfile?.path !== "h5-app/bun.lock" ||
    manifest.lockfile.sha256 !== lockDigest
  ) {
    fail("release manifest lockfile binding is stale");
  }
  const api = secureEndpoint(manifest.endpoints?.api_base_url, "api");
  const ws = secureEndpoint(manifest.endpoints?.ws_url, "ws");
  const headersBytes = await readFile(resolve(dist, headersName));
  if (
    !sha256Pattern.test(manifest.security_headers_sha256) ||
    hash(headersBytes) !== manifest.security_headers_sha256
  ) {
    fail("security headers digest mismatch");
  }
  validateHeaders(
    JSON.parse(headersBytes.toString()) as Headers,
    api.origin,
    ws.origin,
  );
  const renderedHeaders = await renderHeaders(api.origin, ws.origin);
  if (
    JSON.stringify(JSON.parse(headersBytes.toString())) !==
    JSON.stringify(renderedHeaders)
  ) {
    fail("security headers do not match the reviewed release policy");
  }

  const files = (await regularFiles(dist)).filter(
    (path) => relative(dist, path) !== manifestName,
  );
  const actual = await Promise.all(files.map((path) => assetFor(dist, path)));
  if (JSON.stringify(actual) !== JSON.stringify(manifest.assets))
    fail("release asset inventory or digest mismatch");
  let executableText = "";
  for (const asset of actual) {
    if (asset.path.endsWith(".map"))
      fail(`public source map is forbidden: ${asset.path}`);
    if (/\.(?:html|css|js|mjs)$/.test(asset.path)) {
      const content = await readFile(resolve(dist, asset.path), "utf8");
      if (/\.(?:js|mjs)$/.test(asset.path)) executableText += content;
      if (/sourceMappingURL\s*=/.test(content))
        fail(`source map reference is forbidden: ${asset.path}`);
    }
  }
  if (!executableText.includes(api.url) || !executableText.includes(ws.url)) {
    fail("built JavaScript does not bind the manifest API and WebSocket URLs");
  }
  console.log(
    `[h5-release] verified ${actual.length} assets for ${manifest.source_commit}`,
  );
}

async function check(distArg: string): Promise<void> {
  await checkInternal(distArg, true);
}

if (import.meta.main) {
  const [command, dist = "dist"] = process.argv.slice(2);
  if (command === "finalize") await finalize(dist);
  else if (command === "check") await check(dist);
  else
    fail("usage: h5-release-security.ts <finalize|check> [dist-relative-path]");
}

export { check, finalize };
