import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium, type APIRequestContext, type BrowserContext, type Page } from '@playwright/test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const dist = resolve(root, process.env.H5_RELEASE_DIST ?? 'h5-app/dist');
const manifest = JSON.parse(
  await readFile(resolve(dist, 'release-manifest.json'), 'utf8'),
) as {
  source_commit: string;
  base_path: string;
  endpoints: { api_base_url: string; ws_url: string };
  assets: Array<{ path: string; bytes: number; sha256: string }>;
};
const expectedHeaders = JSON.parse(
  await readFile(resolve(dist, 'security-headers.json'), 'utf8'),
) as Record<string, string>;
const candidateUrl = new URL(
  process.env.H5_RELEASE_CANDIDATE_URL
    ?? 'https://im-test-admin-1.codelib.cc/h5-candidate/',
);
if (candidateUrl.pathname !== manifest.base_path) {
  throw new Error('candidate URL path does not match release manifest base_path');
}

const apiUrl = new URL(manifest.endpoints.api_base_url);
if (apiUrl.origin !== candidateUrl.origin) {
  throw new Error('secure state audit requires a same-origin isolated API');
}
const runId = crypto.randomUUID().replaceAll('-', '').slice(0, 12);
const passwordMarker = `H5Audit-${runId}-secret`;
const messageMarker = `h5-production-store-${runId}`;
const tamperMarker = `h5-aad-tamper-${runId}`;
const consoleMessages: string[] = [];
const pageErrors: string[] = [];
const networkUrls: string[] = [];
const encryptedPosts: string[] = [];
const plaintextMessagePosts: string[] = [];
const sensitiveNetworkViolations: string[] = [];
const responseScans: Array<Promise<void>> = [];
let webSocketFrameCount = 0;
const browser = await chromium.launch({
  channel: 'chrome',
  headless: process.env.H5_RELEASE_BROWSER_HEADLESS === 'true',
});
const aliceContext = await browser.newContext();
const bobContext = await browser.newContext();
const alicePage = await observedPage(aliceContext, 'alice');
const bobPage = await observedPage(bobContext, 'bob');
const signalTestEvidence = process.env.H5_RELEASE_BROWSER_SIGNAL_TEST_EVIDENCE;
let browserCleanup: Promise<void> | null = null;
const cleanupBrowser = () => {
  browserCleanup ??= (async () => {
    await Promise.allSettled([closeContext(aliceContext), closeContext(bobContext)]);
    await browser.close().catch(() => undefined);
  })();
  return browserCleanup;
};
const terminate = (status: number) => {
  void cleanupBrowser().then(async () => {
    if (signalTestEvidence) {
      await writeFile(signalTestEvidence, `${JSON.stringify({
        phase: 'closed',
        browser_connected: browser.isConnected(),
      })}\n`);
    }
  }).finally(() => process.exit(status));
};
process.once('SIGINT', () => terminate(130));
process.once('SIGTERM', () => terminate(143));

if (signalTestEvidence) {
  await writeFile(signalTestEvidence, `${JSON.stringify({ phase: 'ready' })}\n`);
  await new Promise<never>(() => undefined);
}

try {
  await verifyCandidateAssets(aliceContext, alicePage);
  const runtime = await apiRequest<{
    message_runtime?: { server_storage_mode?: string; content_audit_mode?: string };
  }>(
    aliceContext.request,
    '/settings/general',
  );
  if (
    runtime.message_runtime?.server_storage_mode !== 'persist'
    || runtime.message_runtime.content_audit_mode !== 'e2ee'
  ) {
    throw new Error('isolated candidate API is not persist/e2ee');
  }

  const alice = await register(aliceContext.request, `h5a${runId.slice(0, 8)}`);
  const bob = await register(bobContext.request, `h5b${runId.slice(0, 8)}`);
  const friendRequest = await apiRequest<{ id: string }>(
    aliceContext.request,
    '/friends/requests',
    {
      method: 'POST',
      token: alice.token,
      body: { target_user_id: bob.user.id },
    },
  );
  await apiRequest(
    bobContext.request,
    `/friends/requests/${friendRequest.id}/respond`,
    { method: 'POST', token: bob.token, body: { action: 'accept' } },
  );
  const room = await apiRequest<Record<string, unknown>>(
    aliceContext.request,
    `/friends/${bob.user.id}/chat`,
    { method: 'POST', token: alice.token },
  );
  const roomId = String(room.room_id ?? room.id ?? '');
  if (!roomId) throw new Error('private room setup returned no room id');

  await Promise.all([
    loginThroughCandidate(alicePage, alice.username, passwordMarker),
    loginThroughCandidate(bobPage, bob.username, passwordMarker),
  ]);
  await Promise.all([
    waitForProductionState(alicePage, alice.user.id),
    waitForProductionState(bobPage, bob.user.id),
  ]);

  await bobPage.goto(new URL(`chats/${roomId}`, candidateUrl).href, { waitUntil: 'networkidle' });
  await alicePage.goto(new URL(`chats/${roomId}`, candidateUrl).href, { waitUntil: 'networkidle' });
  await alicePage.getByPlaceholder('输入消息').fill(messageMarker);
  await alicePage.getByRole('button', { name: '发送', exact: true }).click();
  await bobPage.getByText(messageMarker, { exact: true }).waitFor({ timeout: 30_000 });

  const productionState = await inspectProductionState(alicePage, alice.user.id, [
    passwordMarker,
    messageMarker,
    tamperMarker,
    alice.token,
  ]);
  if (
    !productionState.secureContext
    || productionState.wrappingKey.extractable
    || !productionState.wrappingKey.exportBlocked
    || !productionState.wrappingKey.usages.includes('encrypt')
    || !productionState.wrappingKey.usages.includes('decrypt')
    || !productionState.encryptedRecordStructureValid
    || productionState.secureStateContainsForbiddenValue
    || productionState.browserStorageContainsPassword
  ) {
    throw new Error('production secure state encryption or plaintext boundary failed');
  }

  const postsBeforeTamper = encryptedPosts.length;
  const plaintextPostsBeforeTamper = plaintextMessagePosts.length;
  if (await alicePage.locator('.message-notice--error').count() !== 0) {
    throw new Error('chat page has an error before production state tamper');
  }
  await tamperProtocolStateWithProfileCiphertext(alicePage, alice.user.id);
  await alicePage.getByPlaceholder('输入消息').fill(tamperMarker);
  await alicePage.getByRole('button', { name: '发送', exact: true }).click();
  await alicePage.getByText('E2EE 协议状态已损坏或无法解密', { exact: true }).waitFor({
    timeout: 15_000,
  });
  await alicePage.getByPlaceholder('输入消息').waitFor({ state: 'visible' });
  if (await alicePage.getByPlaceholder('输入消息').inputValue() !== tamperMarker) {
    throw new Error('tampered send did not restore the exact draft marker');
  }
  if (encryptedPosts.length !== postsBeforeTamper) {
    throw new Error('tampered production state reached encrypted message endpoint');
  }
  if (plaintextMessagePosts.length !== plaintextPostsBeforeTamper) {
    throw new Error('tampered production state downgraded to plaintext message endpoint');
  }

  const sensitiveValues = [passwordMarker, messageMarker, tamperMarker, alice.token, bob.token];
  await drainResponseScans();
  if (
    webSocketFrameCount === 0
    || pageErrors.length
    || consoleMessages.some((entry) => (
      entry.includes('error:') || sensitiveValues.some((value) => entry.includes(value))
    ))
    || sensitiveNetworkViolations.length
  ) {
    throw new Error(
      `candidate leaked sensitive browser data: ${JSON.stringify({
        consoleMessageCount: consoleMessages.length,
        pageErrors,
        sensitiveNetworkViolations,
      })}`,
    );
  }
  if (networkUrls.some((url) => sensitiveValues.some((value) => url.includes(value)))) {
    throw new Error('plaintext marker appeared in browser network URL');
  }

  const evidence = {
    schema: 'redcode-h5-browser-audit/v2',
    source_commit: manifest.source_commit,
    candidate_origin: candidateUrl.origin,
    api_path: apiUrl.pathname,
    base_path: manifest.base_path,
    manifest_sha256: createHash('sha256')
      .update(await readFile(resolve(dist, 'release-manifest.json')))
      .digest('hex'),
    checked_at: new Date().toISOString(),
    response_headers: expectedHeaders,
    private_artifacts_get_head: '404',
    missing_asset: '404',
    production_path: {
      distinct_browser_contexts: true,
      ui_login: true,
      ui_message_round_trip: true,
      recipient_decrypted_message: true,
      production_database: productionState.databaseName,
      secure_context: productionState.secureContext,
      wrapping_key_non_extractable: !productionState.wrappingKey.extractable,
      wrapping_key_export_blocked: productionState.wrappingKey.exportBlocked,
      encrypted_record_count: productionState.encryptedRecordCount,
      encrypted_record_structure_valid: productionState.encryptedRecordStructureValid,
      secure_state_forbidden_values_absent: !productionState.secureStateContainsForbiddenValue,
      browser_storage_password_marker_free: !productionState.browserStorageContainsPassword,
      local_decrypted_message_storage: 'allowed-for-local-search',
      aad_mismatch_failed_closed: encryptedPosts.length === postsBeforeTamper,
      plaintext_downgrade_blocked: plaintextMessagePosts.length === plaintextPostsBeforeTamper,
    },
    network_url_count: networkUrls.length,
    websocket_frame_count: webSocketFrameCount,
    console_message_count: consoleMessages.length,
    page_error_count: pageErrors.length,
  };
  const output = resolve(
    root,
    process.env.H5_RELEASE_BROWSER_EVIDENCE
      ?? `.artifacts/h5-release/${manifest.source_commit}-browser.json`,
  );
  await mkdir(dirname(output), { recursive: true });
  await writeFile(output, `${JSON.stringify(evidence, null, 2)}\n`);
  console.log(`[h5-release-browser] verified production secure state and wrote ${output}`);
} finally {
  await cleanupBrowser();
}

async function observedPage(context: BrowserContext, label: string): Promise<Page> {
  const page = await context.newPage();
  page.on('console', (message) => {
    consoleMessages.push(`${label}:${message.type()}: ${message.text()}`);
  });
  page.on('pageerror', (error) => pageErrors.push(`${label}: ${error.message}`));
  page.on('request', (request) => {
    networkUrls.push(request.url());
    const body = request.postData() ?? '';
    if (body.includes(messageMarker) || body.includes(tamperMarker)) {
      sensitiveNetworkViolations.push(`${label}:plaintext-message-request:${new URL(request.url()).pathname}`);
    }
    if (body.includes(passwordMarker) && !request.url().endsWith('/auth/login')) {
      sensitiveNetworkViolations.push(`${label}:password-request:${new URL(request.url()).pathname}`);
    }
    if (request.method() === 'POST' && request.url().includes('/messages/encrypted')) {
      encryptedPosts.push(request.url());
    }
    if (
      request.method() === 'POST'
      && /\/rooms\/[^/]+\/messages$/.test(new URL(request.url()).pathname)
    ) {
      plaintextMessagePosts.push(request.url());
    }
  });
  page.on('response', (response) => {
    responseScans.push((async () => {
    const contentType = response.headers()['content-type'] ?? '';
    if (!contentType.includes('json') && !contentType.startsWith('text/')) return;
    const body = await response.text().catch(() => '');
    for (const [name, value] of [
      ['password', passwordMarker],
      ['message', messageMarker],
      ['tamper', tamperMarker],
    ] as const) {
      if (body.includes(value)) {
        sensitiveNetworkViolations.push(`${label}:${name}-response:${new URL(response.url()).pathname}`);
      }
    }
    })());
  });
  page.on('websocket', (socket) => {
    const scan = (direction: string, payload: string | Buffer) => {
      webSocketFrameCount += 1;
      const body = typeof payload === 'string' ? payload : payload.toString('utf8');
      for (const [name, value] of [
        ['password', passwordMarker],
        ['message', messageMarker],
        ['tamper', tamperMarker],
      ] as const) {
        if (body.includes(value)) {
          sensitiveNetworkViolations.push(`${label}:${name}-websocket-${direction}`);
        }
      }
    };
    socket.on('framesent', (event) => scan('sent', event.payload));
    socket.on('framereceived', (event) => scan('received', event.payload));
  });
  return page;
}

async function drainResponseScans(): Promise<void> {
  for (;;) {
    const count = responseScans.length;
    await Promise.all(responseScans);
    if (responseScans.length === count) return;
  }
}

async function verifyCandidateAssets(context: BrowserContext, page: Page): Promise<void> {
  const response = await page.goto(candidateUrl.href, { waitUntil: 'networkidle' });
  if (!response?.ok()) throw new Error(`candidate returned HTTP ${response?.status()}`);
  assertHeaders(response.headers(), 'candidate entry');
  await page.waitForURL(new URL('login', candidateUrl).href);
  await page.getByRole('button', { name: '登录账号' }).waitFor();
  const reloadResponse = await page.reload({ waitUntil: 'networkidle' });
  if (!reloadResponse?.ok()) throw new Error('candidate deep-link reload failed');
  assertHeaders(reloadResponse.headers(), 'candidate deep-link');

  for (const asset of manifest.assets) {
    if (asset.path === 'security-headers.json') continue;
    const assetResponse = await context.request.get(new URL(asset.path, candidateUrl).href);
    if (!assetResponse.ok()) throw new Error(`candidate asset failed: ${asset.path}`);
    assertHeaders(assetResponse.headers(), `candidate asset ${asset.path}`);
    const body = await assetResponse.body();
    if (
      body.byteLength !== asset.bytes
      || createHash('sha256').update(body).digest('hex') !== asset.sha256
    ) {
      throw new Error(`candidate HTTP asset digest mismatch: ${asset.path}`);
    }
  }

  for (const method of ['GET', 'HEAD'] as const) {
    for (const name of ['release-manifest.json', 'security-headers.json']) {
      const privateResponse = await context.request.fetch(new URL(name, candidateUrl).href, { method });
      if (privateResponse.status() !== 404) throw new Error(`${method} exposed ${name}`);
      assertHeaders(privateResponse.headers(), `${method} private artifact ${name}`);
    }
  }
  const missingAsset = await context.request.get(new URL('assets/missing.js', candidateUrl).href);
  if (missingAsset.status() !== 404) throw new Error('missing static asset did not return 404');
  assertHeaders(missingAsset.headers(), 'missing static asset');
}

async function register(request: APIRequestContext, username: string) {
  const user = await apiRequest<{ id: string; username: string }>(request, '/auth/register', {
    method: 'POST',
    body: { username, password: passwordMarker, nickname: username },
  });
  const login = await apiRequest<{ token: string }>(request, '/auth/login', {
    method: 'POST',
    body: { username, password: passwordMarker },
  });
  return { user, username, token: login.token };
}

async function loginThroughCandidate(page: Page, username: string, password: string): Promise<void> {
  await page.goto(new URL('login', candidateUrl).href, { waitUntil: 'networkidle' });
  await page.getByPlaceholder('请输入账号').fill(username);
  await page.getByPlaceholder('请输入登录密码').fill(password);
  await page.locator('.login-card__agreement').click();
  await page.getByRole('button', { name: '登录账号' }).click();
  await page.waitForURL(new URL('home', candidateUrl).href, { timeout: 30_000 });
  await page.getByText('实时在线', { exact: true }).waitFor({ timeout: 60_000 });
}

async function waitForProductionState(page: Page, accountId: string): Promise<void> {
  await page.waitForFunction(async ({ databaseName, namespace }) => {
    const open = () => new Promise<IDBDatabase>((resolve, reject) => {
      const request = indexedDB.open(databaseName);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    const result = <T>(request: IDBRequest<T>) => new Promise<T>((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    const database = await open();
    try {
      const transaction = database.transaction(['wrapping-keys', 'encrypted-states']);
      const key = await result(transaction.objectStore('wrapping-keys').get(namespace));
      const state = await result(transaction.objectStore('encrypted-states').get(namespace));
      const profile = await result(
        transaction.objectStore('encrypted-states').get(`${namespace}:device-profile`),
      );
      return Boolean(key && state && profile);
    } finally {
      database.close();
    }
  }, { databaseName: 'redcode-h5-e2ee-state', namespace: `account:${accountId}` }, {
    timeout: 60_000,
  });
}

async function inspectProductionState(page: Page, accountId: string, forbiddenValues: string[]) {
  return page.evaluate(async ({ accountId, forbiddenValues }) => {
    const open = (name: string) => new Promise<IDBDatabase>((resolve, reject) => {
      const request = indexedDB.open(name);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    const result = <T>(request: IDBRequest<T>) => new Promise<T>((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    const databaseName = 'redcode-h5-e2ee-state';
    const namespace = `account:${accountId}`;
    const database = await open(databaseName);
    const key = await result<CryptoKey>(
      database.transaction('wrapping-keys').objectStore('wrapping-keys').get(namespace),
    );
    if (!key) throw new Error('production wrapping key is missing');
    let exportBlocked = false;
    try {
      await crypto.subtle.exportKey('raw', key);
    } catch {
      exportBlocked = true;
    }
    const secureRecords = await result<unknown[]>(
      database.transaction('encrypted-states').objectStore('encrypted-states').getAll(),
    );
    database.close();

    const allIndexedDbRecords: unknown[] = [];
    for (const entry of await indexedDB.databases()) {
      if (!entry.name) continue;
      const scanned = await open(entry.name);
      try {
        for (const storeName of scanned.objectStoreNames) {
          allIndexedDbRecords.push(...await result<unknown[]>(
            scanned.transaction(storeName).objectStore(storeName).getAll(),
          ));
        }
      } finally {
        scanned.close();
      }
    }

    const serializedLocal = JSON.stringify(Object.entries(localStorage));
    const serializedSession = JSON.stringify(Object.entries(sessionStorage));
    const cacheBodies: string[] = [];
    for (const cacheName of await caches.keys()) {
      const cache = await caches.open(cacheName);
      for (const request of await cache.keys()) {
        const response = await cache.match(request);
        if (response) cacheBodies.push(await response.text());
      }
    }
    let opfsContainsSecret = false;
    if (navigator.storage.getDirectory) {
      const visit = async (directory: FileSystemDirectoryHandle): Promise<void> => {
        const entries = directory as FileSystemDirectoryHandle & {
          entries(): AsyncIterableIterator<[string, FileSystemHandle]>;
        };
        for await (const [, handle] of entries.entries()) {
          if (handle.kind === 'directory') await visit(handle as FileSystemDirectoryHandle);
          else {
            const bytes = await (await (handle as FileSystemFileHandle).getFile()).arrayBuffer();
            const content = new TextDecoder().decode(bytes);
            if (content.includes(forbiddenValues[0]!)) opfsContainsSecret = true;
          }
        }
      };
      await visit(await navigator.storage.getDirectory());
    }
    return {
      databaseName,
      secureContext: isSecureContext,
      wrappingKey: {
        extractable: key.extractable,
        usages: key.usages,
        exportBlocked,
      },
      encryptedRecordCount: secureRecords.length,
      encryptedRecordStructureValid: secureRecords.length >= 2 && secureRecords.every((record) => {
        if (!record || typeof record !== 'object') return false;
        const value = record as { version?: unknown; nonce?: unknown; ciphertext?: unknown };
        return value.version === 1
          && Array.isArray(value.nonce) && value.nonce.length === 12
          && Array.isArray(value.ciphertext) && value.ciphertext.length > 16;
      }),
      secureStateContainsForbiddenValue: forbiddenValues.some(
        (value) => JSON.stringify(secureRecords).includes(value),
      ),
      browserStorageContainsPassword: serializedLocal.includes(forbiddenValues[0]!)
        || serializedSession.includes(forbiddenValues[0]!)
        || cacheBodies.some((body) => body.includes(forbiddenValues[0]!))
        || JSON.stringify(allIndexedDbRecords).includes(forbiddenValues[0]!)
        || opfsContainsSecret,
    };
  }, { accountId, forbiddenValues });
}

async function tamperProtocolStateWithProfileCiphertext(page: Page, accountId: string): Promise<void> {
  await page.evaluate(async (accountId) => {
    const open = (name: string) => new Promise<IDBDatabase>((resolve, reject) => {
      const request = indexedDB.open(name);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    const result = <T>(request: IDBRequest<T>) => new Promise<T>((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    const done = (transaction: IDBTransaction) => new Promise<void>((resolve, reject) => {
      transaction.oncomplete = () => resolve();
      transaction.onerror = () => reject(transaction.error);
      transaction.onabort = () => reject(transaction.error);
    });
    const database = await open('redcode-h5-e2ee-state');
    try {
      const namespace = `account:${accountId}`;
      const transaction = database.transaction('encrypted-states', 'readwrite');
      const store = transaction.objectStore('encrypted-states');
      const profile = await result(store.get(`${namespace}:device-profile`));
      if (!profile) throw new Error('production device profile ciphertext is missing');
      store.put(profile, namespace);
      await done(transaction);
    } finally {
      database.close();
    }
  }, accountId);
}

async function apiRequest<T = unknown>(
  request: APIRequestContext,
  path: string,
  options: { method?: string; token?: string; body?: unknown } = {},
): Promise<T> {
  const response = await request.fetch(new URL(`${apiUrl.pathname.replace(/\/$/, '')}${path}`, apiUrl.origin).href, {
    method: options.method ?? 'GET',
    headers: {
      ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(options.body ? { data: options.body } : {}),
  });
  if (!response.ok()) {
    throw new Error(`audit API ${options.method ?? 'GET'} ${path} failed (${response.status()})`);
  }
  return response.json() as Promise<T>;
}

async function closeContext(context: BrowserContext): Promise<void> {
  await context.clearCookies();
  await context.close();
}

function assertHeaders(actual: Record<string, string>, label: string): void {
  for (const [name, value] of Object.entries(expectedHeaders)) {
    if (actual[name] !== value) throw new Error(`${label} has invalid ${name}`);
  }
}
