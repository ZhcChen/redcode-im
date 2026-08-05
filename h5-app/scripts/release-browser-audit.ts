import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { chromium, type BrowserContext } from "@playwright/test";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const dist = resolve(root, process.env.H5_RELEASE_DIST ?? "h5-app/dist");
const manifest = JSON.parse(
  await readFile(resolve(dist, "release-manifest.json"), "utf8"),
) as {
  source_commit: string;
  base_path: string;
  assets: Array<{ path: string; bytes: number; sha256: string }>;
};
const expectedHeaders = JSON.parse(
  await readFile(resolve(dist, "security-headers.json"), "utf8"),
) as Record<string, string>;
const candidateUrl = new URL(
  process.env.H5_RELEASE_CANDIDATE_URL ??
    "https://im-test-admin-1.codelib.cc/h5-candidate/",
);
if (candidateUrl.pathname !== manifest.base_path) {
  throw new Error("candidate URL path does not match release manifest base_path");
}

const marker = `G3_BROWSER_AUDIT_${crypto.randomUUID()}`;
const consoleMessages: string[] = [];
const pageErrors: string[] = [];
const networkUrls: string[] = [];
const browser = await chromium.launch({ channel: "chrome", headless: true });
const context = await browser.newContext();
const page = await context.newPage();
page.on("console", (message) => consoleMessages.push(`${message.type()}: ${message.text()}`));
page.on("pageerror", (error) => pageErrors.push(error.message));
page.on("request", (request) => networkUrls.push(request.url()));

try {
  const response = await page.goto(candidateUrl.href, { waitUntil: "networkidle" });
  if (!response?.ok()) throw new Error(`candidate returned HTTP ${response?.status()}`);
  await page.waitForURL(new URL("login", candidateUrl).href);
  await page.getByRole("button", { name: "登录账号" }).waitFor();
  await page.reload({ waitUntil: "networkidle" });

  for (const [name, value] of Object.entries(expectedHeaders)) {
    if (response.headers()[name] !== value) {
      throw new Error(`candidate response has invalid ${name}`);
    }
  }

  for (const method of ["GET", "HEAD"] as const) {
    for (const name of ["release-manifest.json", "security-headers.json"]) {
      const privateResponse = await context.request.fetch(new URL(name, candidateUrl).href, { method });
      if (privateResponse.status() !== 404) {
        throw new Error(`${method} exposed private artifact ${name}`);
      }
    }
  }
  const missingAsset = await context.request.get(new URL("assets/missing.js", candidateUrl).href);
  if (missingAsset.status() !== 404) throw new Error("missing static asset did not return 404");

  const browserEvidence = await page.evaluate(async (plaintextMarker) => {
    const databaseName = "redcode-h5-release-browser-audit";
    await new Promise<void>((resolveDelete) => {
      const request = indexedDB.deleteDatabase(databaseName);
      request.onsuccess = request.onerror = request.onblocked = () => resolveDelete();
    });
    const database = await new Promise<IDBDatabase>((resolveOpen, rejectOpen) => {
      const request = indexedDB.open(databaseName, 1);
      request.onupgradeneeded = () => {
        request.result.createObjectStore("wrapping-keys");
        request.result.createObjectStore("encrypted-states");
      };
      request.onsuccess = () => resolveOpen(request.result);
      request.onerror = () => rejectOpen(request.error);
    });
    const key = await crypto.subtle.generateKey(
      { name: "AES-GCM", length: 256 },
      false,
      ["encrypt", "decrypt"],
    );
    const nonce = crypto.getRandomValues(new Uint8Array(12));
    const plaintext = new TextEncoder().encode(plaintextMarker);
    const ciphertext = new Uint8Array(await crypto.subtle.encrypt(
      { name: "AES-GCM", iv: nonce },
      key,
      plaintext,
    ));
    await new Promise<void>((resolveWrite, rejectWrite) => {
      const transaction = database.transaction(
        ["wrapping-keys", "encrypted-states"],
        "readwrite",
      );
      transaction.objectStore("wrapping-keys").put(key, "account:audit");
      transaction.objectStore("encrypted-states").put({
        version: 1,
        nonce: Array.from(nonce),
        ciphertext: Array.from(ciphertext),
      }, "account:audit");
      transaction.oncomplete = () => resolveWrite();
      transaction.onerror = () => rejectWrite(transaction.error);
    });
    const storedKey = await new Promise<CryptoKey>((resolveRead, rejectRead) => {
      const request = database.transaction("wrapping-keys")
        .objectStore("wrapping-keys").get("account:audit");
      request.onsuccess = () => resolveRead(request.result as CryptoKey);
      request.onerror = () => rejectRead(request.error);
    });
    const storedState = await new Promise<Record<string, unknown>>((resolveRead, rejectRead) => {
      const request = database.transaction("encrypted-states")
        .objectStore("encrypted-states").get("account:audit");
      request.onsuccess = () => resolveRead(request.result as Record<string, unknown>);
      request.onerror = () => rejectRead(request.error);
    });
    let exportBlocked = false;
    try {
      await crypto.subtle.exportKey("raw", storedKey);
    } catch {
      exportBlocked = true;
    }

    const cacheBodies: string[] = [];
    for (const cacheName of await caches.keys()) {
      const cache = await caches.open(cacheName);
      for (const request of await cache.keys()) {
        const cached = await cache.match(request);
        if (cached) cacheBodies.push(await cached.text());
      }
    }
    const opfsEntries: string[] = [];
    let opfsContainsMarker = false;
    if (navigator.storage.getDirectory) {
      const visit = async (directory: FileSystemDirectoryHandle, prefix: string): Promise<void> => {
        const entries = directory as FileSystemDirectoryHandle & {
          entries(): AsyncIterableIterator<[string, FileSystemHandle]>;
        };
        for await (const [name, handle] of entries.entries()) {
          const path = `${prefix}${name}`;
          opfsEntries.push(path);
          if (handle.kind === "directory") {
            await visit(handle as FileSystemDirectoryHandle, `${path}/`);
          }
          else {
            const content = new Uint8Array(
              await (await (handle as FileSystemFileHandle).getFile()).arrayBuffer(),
            );
            if (new TextDecoder().decode(content).includes(plaintextMarker)) {
              opfsContainsMarker = true;
            }
          }
        }
      };
      await visit(await navigator.storage.getDirectory(), "");
    }

    const serializedState = JSON.stringify(storedState);
    database.close();
    await new Promise<void>((resolveDelete) => {
      const request = indexedDB.deleteDatabase(databaseName);
      request.onsuccess = request.onerror = request.onblocked = () => resolveDelete();
    });
    return {
      secureContext: isSecureContext,
      inlineStyleAttributes: document.querySelectorAll("[style]").length,
      inlineStyleElements: document.querySelectorAll("style").length,
      wrappingKey: {
        algorithm: storedKey.algorithm,
        extractable: storedKey.extractable,
        usages: storedKey.usages,
        exportBlocked,
      },
      markerChecks: {
        indexedDb: serializedState.includes(plaintextMarker),
        localStorage: JSON.stringify(Object.entries(localStorage)).includes(plaintextMarker),
        sessionStorage: JSON.stringify(Object.entries(sessionStorage)).includes(plaintextMarker),
        cacheStorage: cacheBodies.some((body) => body.includes(plaintextMarker)),
        opfs: opfsContainsMarker,
      },
      cacheNames: await caches.keys(),
      opfsEntries,
      auditDatabaseRemoved: !(await indexedDB.databases())
        .some((entry) => entry.name === databaseName),
    };
  }, marker);

  if (!browserEvidence.secureContext) throw new Error("candidate is not a secure context");
  if (
    browserEvidence.wrappingKey.extractable ||
    !browserEvidence.wrappingKey.exportBlocked ||
    Object.values(browserEvidence.markerChecks).some(Boolean)
  ) {
    throw new Error("browser WebCrypto or plaintext storage boundary failed");
  }
  if (consoleMessages.length || pageErrors.length) {
    throw new Error(
      `candidate emitted console messages or page errors: ${JSON.stringify({ consoleMessages, pageErrors, networkUrls })}`,
    );
  }
  if (networkUrls.some((url) => url.includes(marker))) {
    throw new Error("plaintext marker appeared in browser network URLs");
  }

  const evidence = {
    schema: "redcode-h5-browser-audit/v1",
    source_commit: manifest.source_commit,
    candidate_origin: candidateUrl.origin,
    base_path: manifest.base_path,
    manifest_sha256: createHash("sha256")
      .update(await readFile(resolve(dist, "release-manifest.json")))
      .digest("hex"),
    checked_at: new Date().toISOString(),
    response_headers: expectedHeaders,
    private_artifacts_get_head: "404",
    missing_asset: "404",
    final_url: page.url(),
    network_urls: networkUrls,
    console_messages: consoleMessages,
    page_errors: pageErrors,
    browser: browserEvidence,
  };
  const output = resolve(
    root,
    process.env.H5_RELEASE_BROWSER_EVIDENCE ??
      `.artifacts/h5-release/${manifest.source_commit}-browser.json`,
  );
  await mkdir(dirname(output), { recursive: true });
  await writeFile(output, `${JSON.stringify(evidence, null, 2)}\n`);
  console.log(`[h5-release-browser] verified candidate and wrote ${output}`);
} finally {
  await closeContext(context);
  await browser.close();
}

async function closeContext(context: BrowserContext): Promise<void> {
  await context.clearCookies();
  await context.close();
}
