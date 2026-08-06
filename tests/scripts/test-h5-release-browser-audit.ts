import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = resolve(import.meta.dir, '../..');
const auditPath = resolve(root, 'h5-app/scripts/release-browser-audit.ts');
const caddyPath = resolve(root, 'deploy/im-test-1/Caddyfile.h5-candidate');
const windowPath = resolve(root, 'scripts/h5-release-secure-state-audit-window.sh');

const requiredAuditFragments = [
  "const aliceContext = await browser.newContext()",
  "const bobContext = await browser.newContext()",
  "loginThroughCandidate(alicePage",
  "loginThroughCandidate(bobPage",
  "databaseName = 'redcode-h5-e2ee-state'",
  'waitForProductionState(alicePage',
  'waitForProductionState(bobPage',
  'recipient_decrypted_message: true',
  'await tamperProtocolStateWithProfileCiphertext(alicePage, alice.user.id)',
  'encryptedPosts.length !== postsBeforeTamper',
  'plaintextMessagePosts.length !== plaintextPostsBeforeTamper',
  'secureStateContainsForbiddenValue',
  'sensitiveNetworkViolations',
  'consoleDiagnostics',
  'text_sha256',
  'expectedIdentityBootstrapPaths',
  'responseStatuses.get(entry.pathname)?.includes(404)',
  'unexpectedConsoleErrors.length',
  'drainResponseScans',
  "socket.on('framereceived'",
  'webSocketFrameCount === 0',
  "process.once('SIGTERM'",
  "local_decrypted_message_storage: 'allowed-for-local-search'",
  'encryptedRecordStructureValid',
  'secureContext: isSecureContext',
];

function assertAuditContract(source: string): void {
  for (const fragment of requiredAuditFragments) {
    if (!source.includes(fragment)) throw new Error(`browser audit contract missing: ${fragment}`);
  }
  for (const forbidden of [
    'redcode-h5-release-browser-audit',
    'crypto.subtle.generateKey',
    'crypto.subtle.encrypt',
  ]) {
    if (source.includes(forbidden)) throw new Error(`browser audit uses substitute crypto: ${forbidden}`);
  }
}

const audit = await readFile(auditPath, 'utf8');
assertAuditContract(audit);
console.log('[h5-browser-audit-test] production path contract: pass');

for (const fragment of requiredAuditFragments) {
  let failed = false;
  try {
    assertAuditContract(audit.replaceAll(fragment, 'removed-contract-fragment'));
  } catch {
    failed = true;
  }
  if (!failed) throw new Error(`contract mutation did not fail closed: ${fragment}`);
}
console.log(`[h5-browser-audit-test] ${requiredAuditFragments.length} required-fragment mutations: fail closed`);

for (const forbidden of [
  'redcode-h5-release-browser-audit',
  'crypto.subtle.generateKey',
  'crypto.subtle.encrypt',
]) {
  let failed = false;
  try {
    assertAuditContract(`${audit}\n${forbidden}\n`);
  } catch {
    failed = true;
  }
  if (!failed) throw new Error(`substitute implementation mutation passed: ${forbidden}`);
}
console.log('[h5-browser-audit-test] substitute crypto/database mutations: fail closed');

const caddy = await readFile(caddyPath, 'utf8');
const apiProxy = caddy.indexOf('handle_path /h5-candidate-api/*');
const staticCandidate = caddy.indexOf('handle_path /h5-candidate/*');
if (apiProxy < 0 || staticCandidate < 0 || apiProxy > staticCandidate) {
  throw new Error('isolated candidate API proxy must precede the static candidate route');
}
if (!caddy.includes('reverse_proxy 127.0.0.1:18010')) {
  throw new Error('candidate API proxy is not bound to the isolated API port');
}
if (!caddy.includes('Content-Security-Policy "{{H5_CANDIDATE_CSP}}"')) {
  throw new Error('candidate Caddyfile does not use the release CSP template');
}

const window = await readFile(windowPath, 'utf8');
for (const fragment of [
  'E2EE_RESTORE_ALLOW_EMPTY_PREPARE=yes',
  "remote_control cleanup",
  'remote_dir_created=1',
  'source_schema_digest',
  "awk '!/^\\\\(un)?restrict /'",
  'source_gate_table',
  'h5-release-candidate-window.sh',
  'remote_control verify',
]) {
  if (!window.includes(fragment)) throw new Error(`secure state window missing: ${fragment}`);
}
console.log('[h5-browser-audit-test] isolated API and cleanup contract: pass');
