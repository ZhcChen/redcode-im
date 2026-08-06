import { createHash } from 'node:crypto';
import { chmod, cp, mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dir, '../..');
const verifier = resolve(root, 'scripts/e2ee-evidence/verify-provenance.ts');
const temp = await mkdtemp(resolve(tmpdir(), 'redcode-provenance-test-'));
process.on('exit', () => { void rm(temp, { recursive: true, force: true }); });
const fixture = resolve(temp, 'fixture');
const bin = resolve(temp, 'bin');
await mkdir(fixture);
await mkdir(bin);
await writeFile(resolve(fixture, 'trusted-root.jsonl'), '{"mediaType":"trustedroot"}\n');

const source = '1'.repeat(40);
const categories: Record<string, string[]> = {
  h5: ['redcode-im-h5.tar.gz'],
  android: ['redcode-im-android.apk'],
  'api-x86_64': ['redcode-im-api-linux-x86_64.binary.tar.gz', 'redcode-im-api-linux-x86_64.docker.tar.gz'],
  'api-arm64': ['redcode-im-api-linux-arm64.binary.tar.gz', 'redcode-im-api-linux-arm64.docker.tar.gz'],
};
const subjects = [];
for (const [category, artifacts] of Object.entries(categories)) {
  const sidecar = `${category}.sha256`;
  const bundle = `${category}.bundle.jsonl`;
  const entries = artifacts.map((name, index) => ({ name, sha256: String(index + 2).repeat(64) }));
  await writeFile(resolve(fixture, sidecar), entries.map((item) => `${item.sha256}  ${item.name}`).join('\n') + '\n');
  await writeFile(resolve(fixture, bundle), '{"bundle":true}\n');
  subjects.push({
    category,
    sidecar_file: sidecar,
    sidecar_sha256: await fileDigest(resolve(fixture, sidecar)),
    bundle_file: bundle,
    bundle_sha256: await fileDigest(resolve(fixture, bundle)),
    artifacts: entries,
  });
}
const manifest = {
  schema: 'redcode-e2ee-provenance-evidence/v1',
  repository: 'ZhcChen/redcode-im',
  signer_workflow: 'ZhcChen/redcode-im/.github/workflows/release-artifacts.yml',
  source_commit: source,
  trusted_root_file: 'trusted-root.jsonl',
  subjects,
};
await writeFile(resolve(fixture, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');

await writeFile(resolve(bin, 'gh'), `#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$*" >>"\${PROVENANCE_GH_LOG:?}"
[[ "\${PROVENANCE_GH_MODE:-success}" == success ]] || exit 1
args=" $* "
case "$args" in *" --repo ZhcChen/redcode-im "*) ;; *) exit 2 ;; esac
case "$args" in *" --signer-workflow ZhcChen/redcode-im/.github/workflows/release-artifacts.yml "*) ;; *) exit 2 ;; esac
case "$args" in *" --source-digest \${PROVENANCE_EXPECTED_SOURCE:?} "*) ;; *) exit 2 ;; esac
case "$args" in *" --bundle "*".bundle.jsonl "*) ;; *) exit 2 ;; esac
case "$args" in *" --custom-trusted-root "*"trusted-root.jsonl "*) ;; *) exit 2 ;; esac
subject="$3"
name="\${subject##*/}"
digest="$(shasum -a 256 "$subject" | awk '{print $1}')"
timestamps='[{"type":"transparency-log"}]'
[[ "\${PROVENANCE_GH_TIMESTAMPS:-present}" == present ]] || timestamps='[]'
printf '[{"verificationResult":{"verifiedTimestamps":%s,"statement":{"predicateType":"https://slsa.dev/provenance/v1","subject":[{"name":"%s","digest":{"sha256":"%s"}}]}}}]\\n' "$timestamps" "$name" "$digest"
`);
await chmod(resolve(bin, 'gh'), 0o755);

const env = {
  ...process.env,
  PATH: `${bin}:${process.env.PATH}`,
  PROVENANCE_GH_LOG: resolve(temp, 'gh.log'),
  PROVENANCE_EXPECTED_SOURCE: source,
};
run(fixture, true, env);
const calls = await readFile(resolve(temp, 'gh.log'), 'utf8');
if ((calls.match(/attestation verify/g) ?? []).length !== 4
  || !calls.includes('--custom-trusted-root')
  || !calls.includes('--signer-workflow ZhcChen/redcode-im/.github/workflows/release-artifacts.yml')
  || !calls.includes(`--source-digest ${source}`)) throw new Error('gh 验签参数覆盖不足');
console.log('[e2ee-provenance-test] complete manifest: pass');

await negative('missing-category', (value) => { value.subjects.pop(); });
await negative('wrong-sidecar-digest', (value) => { value.subjects[0].sidecar_sha256 = '0'.repeat(64); });
await negative('wrong-artifact-binding', (value) => { value.subjects[1].artifacts[0].sha256 = '9'.repeat(64); });
await negative('wrong-workflow', (value) => { value.signer_workflow = 'ZhcChen/redcode-im/.github/workflows/other.yml'; });
await negative('wrong-source', (value) => { value.source_commit = '2'.repeat(40); });
run(fixture, false, { ...env, PROVENANCE_GH_MODE: 'fail' });
console.log('[e2ee-provenance-test] signature failure: fail closed');
run(fixture, false, { ...env, PROVENANCE_GH_TIMESTAMPS: 'missing' });
console.log('[e2ee-provenance-test] missing transparency timestamp: fail closed');

async function negative(name: string, mutate: (value: any) => void): Promise<void> {
  const target = resolve(temp, name);
  await cp(fixture, target, { recursive: true });
  const value = JSON.parse(await readFile(resolve(target, 'manifest.json'), 'utf8'));
  mutate(value);
  await writeFile(resolve(target, 'manifest.json'), JSON.stringify(value, null, 2) + '\n');
  run(target, false, env);
  console.log(`[e2ee-provenance-test] ${name}: fail closed`);
}

function run(directory: string, expected: boolean, runEnv: Record<string, string | undefined>): void {
  const result = spawnSync('bun', [verifier, resolve(directory, 'manifest.json')], {
    cwd: root, env: runEnv, encoding: 'utf8',
  });
  if ((result.status === 0) !== expected) {
    throw new Error(`verifier 状态异常 expected=${expected} status=${result.status}\n${result.stdout}\n${result.stderr}`);
  }
}

async function fileDigest(path: string): Promise<string> {
  return createHash('sha256').update(await readFile(path)).digest('hex');
}
