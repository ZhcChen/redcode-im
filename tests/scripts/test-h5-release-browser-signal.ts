import { spawn } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';

const root = resolve(import.meta.dir, '../..');
const fixture = await mkdtemp(resolve(tmpdir(), 'redcode-h5-browser-signal-'));
const evidence = resolve(fixture, 'signal.json');
const script = resolve(root, 'h5-app/scripts/release-browser-audit.ts');

try {
  await writeFile(resolve(fixture, 'release-manifest.json'), JSON.stringify({
    source_commit: '0'.repeat(40),
    base_path: '/',
    endpoints: {
      api_base_url: 'https://audit.invalid/api',
      ws_url: 'wss://audit.invalid/ws',
    },
    assets: [],
  }));
  await writeFile(resolve(fixture, 'security-headers.json'), '{}');

  const child = spawn('bun', [script], {
    cwd: resolve(root, 'h5-app'),
    stdio: ['ignore', 'pipe', 'pipe'],
    env: {
      ...process.env,
      H5_RELEASE_DIST: fixture,
      H5_RELEASE_CANDIDATE_URL: 'https://audit.invalid/',
      H5_RELEASE_BROWSER_HEADLESS: 'true',
      H5_RELEASE_BROWSER_SIGNAL_TEST_EVIDENCE: evidence,
    },
  });
  let stderr = '';
  child.stderr.on('data', (chunk) => { stderr += String(chunk); });

  const deadline = Date.now() + 20_000;
  while (Date.now() < deadline) {
    const ready = await readFile(evidence, 'utf8').catch(() => '');
    if (ready.includes('"phase":"ready"')) break;
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 50));
  }
  const ready = await readFile(evidence, 'utf8').catch(() => '');
  if (!ready.includes('"phase":"ready"')) {
    child.kill('SIGKILL');
    throw new Error(`browser signal harness did not become ready: ${stderr}`);
  }

  child.kill('SIGTERM');
  const result = await new Promise<{ code: number | null; signal: NodeJS.Signals | null }>((resolveExit) => {
    child.once('exit', (code, signal) => resolveExit({ code, signal }));
  });
  if (result.code !== 143 || result.signal !== null) {
    throw new Error(`browser signal exit mismatch: ${JSON.stringify(result)} ${stderr}`);
  }
  const closed = JSON.parse(await readFile(evidence, 'utf8')) as {
    phase?: string;
    browser_connected?: boolean;
  };
  if (closed.phase !== 'closed' || closed.browser_connected !== false) {
    throw new Error(`browser signal cleanup did not close Chrome: ${JSON.stringify(closed)}`);
  }
  console.log('[h5-browser-signal-test] SIGTERM closed contexts and Chrome: pass');
} finally {
  await rm(fixture, { recursive: true, force: true });
}
