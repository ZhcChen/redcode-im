import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { basename, dirname, resolve } from 'node:path';
import { exactKeys, fail, sha256Pattern, string } from './contract';

const manifestPath = resolve(process.argv[2] ?? '');
if (!process.argv[2]) fail('用法: verify-provenance.ts <manifest.json>');
const evidenceDir = dirname(manifestPath);

const manifest = JSON.parse(await readFile(manifestPath, 'utf8')) as Record<string, any>;
exactKeys(manifest, [
  'schema', 'repository', 'signer_workflow', 'source_commit', 'trusted_root_file', 'subjects',
], 'provenance manifest');
if (manifest.schema !== 'redcode-e2ee-provenance-evidence/v1') fail('provenance manifest schema 无效');
const repository = string(manifest.repository, 'repository');
if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repository)) fail('repository 无效');
const signerWorkflow = string(manifest.signer_workflow, 'signer_workflow');
if (signerWorkflow !== `${repository}/.github/workflows/release-artifacts.yml`) {
  fail('signer workflow 与 repository 不一致');
}
const sourceCommit = string(manifest.source_commit, 'source_commit');
if (!/^[a-f0-9]{40}$/.test(sourceCommit)) fail('source_commit 无效');
const trustedRootFile = safeFile(manifest.trusted_root_file, 'trusted_root_file', '.jsonl');
const trustedRootPath = resolve(evidenceDir, trustedRootFile);
if ((await readFile(trustedRootPath)).length < 1) fail('trusted root 为空');

const requiredCategories = new Set(['h5', 'android', 'api-x86_64', 'api-arm64']);
if (!Array.isArray(manifest.subjects) || manifest.subjects.length !== requiredCategories.size) {
  fail('provenance subjects 必须完整覆盖四类资产');
}

for (const [index, subject] of manifest.subjects.entries()) {
  exactKeys(subject, [
    'category', 'sidecar_file', 'sidecar_sha256', 'bundle_file', 'bundle_sha256', 'artifacts',
  ], `subjects[${index}]`);
  const category = string(subject.category, `subjects[${index}].category`);
  if (!requiredCategories.delete(category)) fail(`provenance category 重复或未知：${category}`);
  const sidecarFile = safeFile(subject.sidecar_file, `subjects[${index}].sidecar_file`, '.sha256');
  const bundleFile = safeFile(subject.bundle_file, `subjects[${index}].bundle_file`, '.jsonl');
  const sidecarPath = resolve(evidenceDir, sidecarFile);
  const bundlePath = resolve(evidenceDir, bundleFile);
  const sidecarBytes = await readFile(sidecarPath);
  const bundleBytes = await readFile(bundlePath);
  verifyDigest(sidecarBytes, subject.sidecar_sha256, `${category} sidecar`);
  verifyDigest(bundleBytes, subject.bundle_sha256, `${category} bundle`);

  if (!Array.isArray(subject.artifacts) || subject.artifacts.length < 1) {
    fail(`${category} artifacts 为空`);
  }
  const expected = new Map<string, string>();
  for (const [artifactIndex, artifact] of subject.artifacts.entries()) {
    exactKeys(artifact, ['name', 'sha256'], `${category}.artifacts[${artifactIndex}]`);
    const name = safeFile(artifact.name, `${category}.artifacts[${artifactIndex}].name`);
    const digest = string(artifact.sha256, `${category}.artifacts[${artifactIndex}].sha256`);
    if (!sha256Pattern.test(digest) || expected.has(name)) fail(`${category} artifact 无效或重复：${name}`);
    expected.set(name, digest);
  }
  const observed = parseSidecar(sidecarBytes.toString('utf8'), category);
  if (observed.size !== expected.size) fail(`${category} sidecar 条目数不一致`);
  for (const [name, digest] of expected) {
    if (observed.get(name) !== digest) fail(`${category} sidecar 未绑定预期资产：${name}`);
  }

  let output: string;
  try {
    output = execFileSync('gh', [
      'attestation', 'verify', sidecarPath,
      '--repo', repository,
      '--bundle', bundlePath,
      '--custom-trusted-root', trustedRootPath,
      '--signer-workflow', signerWorkflow,
      '--source-digest', sourceCommit,
      '--format', 'json',
    ], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  } catch {
    fail(`${category} provenance 密码学验签失败`);
  }
  const verification = JSON.parse(output) as Array<Record<string, any>>;
  if (!Array.isArray(verification) || verification.length < 1) fail(`${category} 验签结果为空`);
  const sidecarDigest = digest(sidecarBytes);
  const valid = verification.some((entry) => {
    const result = entry.verificationResult;
    return Array.isArray(result?.verifiedTimestamps)
      && result.verifiedTimestamps.length > 0
      && result.statement?.predicateType === 'https://slsa.dev/provenance/v1'
      && result.statement?.subject?.some((item: any) =>
        item?.name === sidecarFile && item?.digest?.sha256 === sidecarDigest);
  });
  if (!valid) fail(`${category} 验签结果缺少可信时间戳或 subject 绑定`);
}
if (requiredCategories.size !== 0) fail('provenance category 覆盖不完整');
console.log(`[e2ee-provenance] verified 4 subjects source=${sourceCommit}`);

function safeFile(value: unknown, context: string, suffix = ''): string {
  const file = string(value, context);
  if (file !== basename(file) || !/^[A-Za-z0-9._-]+$/.test(file) || (suffix && !file.endsWith(suffix))) {
    fail(`${context} 文件名无效`);
  }
  return file;
}

function digest(bytes: Uint8Array): string {
  return createHash('sha256').update(bytes).digest('hex');
}

function verifyDigest(bytes: Uint8Array, expected: unknown, context: string): void {
  const value = string(expected, `${context}.sha256`);
  if (!sha256Pattern.test(value) || digest(bytes) !== value) fail(`${context} 摘要不匹配`);
}

function parseSidecar(content: string, category: string): Map<string, string> {
  const result = new Map<string, string>();
  const lines = content.trim().split('\n');
  if (lines.length < 1 || lines.some((line) => line.includes('\r'))) fail(`${category} sidecar 格式无效`);
  for (const line of lines) {
    const match = /^([a-f0-9]{64})  ([A-Za-z0-9._-]+)$/.exec(line);
    if (!match || result.has(match[2])) fail(`${category} sidecar 行无效`);
    result.set(match[2], match[1]);
  }
  return result;
}
