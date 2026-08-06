import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { basename, resolve } from 'node:path';
import {
  assertSensitiveValuesAbsent,
  boolean,
  commitPattern,
  enumValue,
  evidenceSchema,
  exactKeys,
  fail,
  generator,
  integer,
  sha256,
  sha256Pattern,
  string,
  subjectCommitTime,
  timestampPattern,
  type EvidenceType,
} from './contract';

const root = resolve(import.meta.dir, '../..');
const evidenceDir = resolve(process.argv[2] ?? 'docs/reviews/evidence/u10-e2ee');
const schemaPath = resolve(
  process.env.E2EE_EVIDENCE_SCHEMA ?? resolve(import.meta.dir, 'schema-v1.json'),
);
const schema = JSON.parse(
  await readFile(schemaPath, 'utf8'),
) as Record<string, unknown>;
exactKeys(schema, [
  'schema', 'evidence_schema', 'additional_properties', 'common_keys',
  'evidence_types', 'sensitive_values_forbidden',
], 'schema-v1');
if (schema.schema !== 'redcode-e2ee-evidence-schema/v1' || schema.evidence_schema !== evidenceSchema) {
  fail('schema-v1 身份不匹配');
}
if (schema.additional_properties !== false) fail('schema-v1 必须禁止额外字段');
if (!Array.isArray(schema.common_keys)) fail('schema-v1 common_keys 无效');
exactKeys(schema.evidence_types, [
  'g1-backup-rollout', 'g3-h5-release', 'f5-release-workflow',
], 'schema-v1.evidence_types');
const evidenceTypeSchemas = schema.evidence_types as Record<string, Record<string, unknown>>;
for (const type of ['g1-backup-rollout', 'g3-h5-release']) {
  exactKeys(evidenceTypeSchemas[type], ['assertion_keys'], `schema-v1.evidence_types.${type}`);
}
exactKeys(evidenceTypeSchemas['f5-release-workflow'], [
  'assertion_keys', 'provenance_assertion_keys',
], 'schema-v1.evidence_types.f5-release-workflow');
if (!Array.isArray(evidenceTypeSchemas['f5-release-workflow'].provenance_assertion_keys)) {
  fail('schema-v1 F5 provenance_assertion_keys 无效');
}
const f5ProvenanceKeys = evidenceTypeSchemas['f5-release-workflow'].provenance_assertion_keys as string[];

const files: Array<[EvidenceType, string]> = [
  ['g1-backup-rollout', 'g1-backup-rollout.json'],
  ['g3-h5-release', 'g3-h5-release.json'],
  ['f5-release-workflow', 'f5-release-workflow.json'],
];

function verifyCommit(commit: string): void {
  if (!commitPattern.test(commit)) fail('subject_commit 格式无效');
  try {
    const resolved = execFileSync('git', ['rev-parse', `${commit}^{commit}`], {
      cwd: root,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    if (resolved !== commit) fail('subject_commit 解析结果不一致');
    execFileSync('git', ['merge-base', '--is-ancestor', commit, 'HEAD'], {
      cwd: root,
      stdio: 'ignore',
    });
  } catch {
    fail(`subject_commit 不可从当前 HEAD 到达：${commit}`);
  }
}

function verifySnapshot(value: unknown, context: string): void {
  const keys = ['attachment_commits', 'control_messages', 'control_receipts', 'devices', 'digest',
    'encrypted_messages', 'identities', 'key_packages', 'room_epochs'] as const;
  exactKeys(value, keys, context);
  for (const key of keys.filter((key) => key !== 'digest')) integer(value[key], `${context}.${key}`);
  if (!/^[a-f0-9]{32}$/.test(string(value.digest, `${context}.digest`))) fail(`${context}.digest 无效`);
}

function verifyG1(assertions: Record<string, unknown>): void {
  exactKeys(assertions, [
    'run_id', 'snapshot', 'restore_runtime', 'live', 'post_live_snapshot', 'boundaries',
  ], 'g1.assertions');
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(string(assertions.run_id, 'g1.run_id'))) {
    fail('g1.run_id 无效');
  }
  exactKeys(assertions.snapshot, ['matched', 'candidate', 'restore'], 'g1.snapshot');
  if (!boolean(assertions.snapshot.matched, 'g1.snapshot.matched')) fail('G1 snapshot 未匹配');
  verifySnapshot(assertions.snapshot.candidate, 'g1.snapshot.candidate');
  verifySnapshot(assertions.snapshot.restore, 'g1.snapshot.restore');
  if (sha256(assertions.snapshot.candidate) !== sha256(assertions.snapshot.restore)) {
    fail('G1 candidate/restore snapshot 不一致');
  }
  exactKeys(assertions.restore_runtime, [
    'verified', 'runtime', 'isolation',
  ], 'g1.restore_runtime');
  if (!boolean(assertions.restore_runtime.verified, 'g1.restore_runtime.verified')) fail('restore 未验证');
  enumValue(assertions.restore_runtime.runtime, ['persist/e2ee'] as const, 'g1.restore_runtime.runtime');
  const isolationKeys = [
    'api_networks_exclude_source', 'database_url_points_restore', 'redis_urls_point_restore',
    'storage_network_members_exact', 'ingress_network_members_exact',
  ] as const;
  exactKeys(assertions.restore_runtime.isolation, isolationKeys, 'g1.restore_runtime.isolation');
  for (const key of isolationKeys) {
    if (!boolean(assertions.restore_runtime.isolation[key], `g1.restore_runtime.isolation.${key}`)) {
      fail(`restore isolation 未通过：${key}`);
    }
  }
  exactKeys(assertions.live, [
    'scenario_count', 'message_proof_count', 'attachment_proof_count',
    'history_decrypted_after_restore', 'new_message_decrypted_after_restore',
  ], 'g1.live');
  if (integer(assertions.live.scenario_count, 'scenario_count') < 4
    || integer(assertions.live.message_proof_count, 'message_proof_count') < 9
    || integer(assertions.live.attachment_proof_count, 'attachment_proof_count') < 1) {
    fail('G1 live 覆盖不足');
  }
  if (!boolean(assertions.live.history_decrypted_after_restore, 'history_decrypted_after_restore')
    || !boolean(assertions.live.new_message_decrypted_after_restore, 'new_message_decrypted_after_restore')) {
    fail('G1 恢复连续性失败');
  }
  verifySnapshot(assertions.post_live_snapshot, 'g1.post_live_snapshot');
  exactKeys(assertions.boundaries, [
    'db', 'redis', 'logs', 'push', 'rustfs_content', 'rustfs_sha256',
  ], 'g1.boundaries');
  enumValue(assertions.boundaries.db, ['ciphertext-only'] as const, 'g1.boundaries.db');
  enumValue(assertions.boundaries.redis, ['marker-free'] as const, 'g1.boundaries.redis');
  enumValue(assertions.boundaries.logs, ['marker-free'] as const, 'g1.boundaries.logs');
  enumValue(assertions.boundaries.push, ['placeholder-only', 'not-observed-live'] as const, 'g1.boundaries.push');
  enumValue(assertions.boundaries.rustfs_content, ['ciphertext-only'] as const, 'g1.boundaries.rustfs_content');
  if (!sha256Pattern.test(string(assertions.boundaries.rustfs_sha256, 'rustfs_sha256'))) fail('rustfs_sha256 无效');
}

async function verifyF5(
  assertions: Record<string, unknown>,
  evidenceDirPath: string,
  subjectCommit: string,
  provenanceKeys: string[],
): Promise<void> {
  exactKeys(assertions, [
    'run', 'jobs', 'artifacts', 'asset_digests', 'release_state', 'provenance',
  ], 'f5.assertions');
  exactKeys(assertions.run, [
    'id', 'workflow_name', 'event', 'head_sha', 'conclusion', 'publish_release',
    'created_at', 'completed_at',
  ], 'f5.run');
  if (integer(assertions.run.id, 'f5.run.id') < 1) fail('F5 run ID 无效');
  enumValue(assertions.run.workflow_name, ['Build Release Artifacts'] as const, 'f5.run.workflow_name');
  enumValue(assertions.run.event, ['workflow_dispatch'] as const, 'f5.run.event');
  enumValue(assertions.run.conclusion, ['success'] as const, 'f5.run.conclusion');
  if (string(assertions.run.head_sha, 'f5.run.head_sha') !== subjectCommit) {
    fail('F5 run head_sha 与 evidence subject 不一致');
  }
  if (boolean(assertions.run.publish_release, 'f5.run.publish_release')) fail('F5 验收 run 不得发布');
  for (const key of ['created_at', 'completed_at'] as const) {
    const timestamp = string(assertions.run[key], `f5.run.${key}`);
    if (!timestampPattern.test(timestamp) || Number.isNaN(Date.parse(timestamp))) fail(`f5.run.${key} 无效`);
  }
  if (Date.parse(String(assertions.run.completed_at)) < Date.parse(String(assertions.run.created_at))) {
    fail('F5 run 完成时间早于创建时间');
  }
  if (!Array.isArray(assertions.jobs) || assertions.jobs.length < 8) fail('F5 jobs 覆盖不足');
  const jobs = new Map<string, { conclusion: string; required: boolean }>();
  assertions.jobs.forEach((value, index) => {
    exactKeys(value, ['name', 'conclusion', 'required'], `f5.jobs[${index}]`);
    const name = string(value.name, `f5.jobs[${index}].name`);
    if (jobs.has(name)) fail(`F5 job 重复：${name}`);
    jobs.set(name, {
      conclusion: enumValue(value.conclusion, ['success', 'skipped'] as const, `f5.jobs[${index}].conclusion`),
      required: boolean(value.required, `f5.jobs[${index}].required`),
    });
  });
  const requiredJobs = [
    'Validate release inputs', 'Supply-chain release gate', 'Build and attest H5 candidate',
    'API test', 'Build Android app (Kotlin/Compose)', 'Build API x86_64', 'Build API arm64',
  ];
  for (const name of requiredJobs) {
    const job = jobs.get(name);
    if (!job || !job.required || job.conclusion !== 'success') fail(`F5 必需 job 未通过：${name}`);
  }
  const publish = jobs.get('Publish GitHub release');
  if (!publish || publish.required || publish.conclusion !== 'skipped') fail('F5 Publish job 未正确跳过');
  if (!Array.isArray(assertions.artifacts) || assertions.artifacts.length !== 5) fail('F5 artifact 数量无效');
  assertions.artifacts.forEach((value, index) => {
    exactKeys(value, ['name', 'digest', 'size_in_bytes'], `f5.artifacts[${index}]`);
    string(value.name, `f5.artifacts[${index}].name`);
    if (!/^sha256:[a-f0-9]{64}$/.test(string(value.digest, `f5.artifacts[${index}].digest`))) {
      fail('F5 artifact digest 无效');
    }
    if (integer(value.size_in_bytes, `f5.artifacts[${index}].size_in_bytes`) < 1) fail('F5 artifact 为空');
  });
  const assetKeys = [
    'h5_archive_sha256', 'android_apk_sha256', 'h5_manifest_sha256', 'wasm_sha256',
  ] as const;
  exactKeys(assertions.asset_digests, assetKeys, 'f5.asset_digests');
  for (const key of assetKeys) {
    if (!sha256Pattern.test(string(assertions.asset_digests[key], `f5.asset_digests.${key}`))) {
      fail(`F5 asset digest 无效：${key}`);
    }
  }
  exactKeys(assertions.release_state, [
    'tags_before_sha256', 'tags_after_sha256', 'releases_before_sha256',
    'releases_after_sha256', 'unchanged',
  ], 'f5.release_state');
  for (const key of ['tags_before_sha256', 'tags_after_sha256', 'releases_before_sha256', 'releases_after_sha256'] as const) {
    if (!sha256Pattern.test(string(assertions.release_state[key], `f5.release_state.${key}`))) {
      fail(`F5 release state digest 无效：${key}`);
    }
  }
  if (!boolean(assertions.release_state.unchanged, 'f5.release_state.unchanged')
    || assertions.release_state.tags_before_sha256 !== assertions.release_state.tags_after_sha256
    || assertions.release_state.releases_before_sha256 !== assertions.release_state.releases_after_sha256) {
    fail('F5 tag/Release 存在副作用');
  }
  exactKeys(assertions.provenance, provenanceKeys, 'f5.provenance');
  const manifestFile = string(assertions.provenance.manifest_file, 'f5.provenance.manifest_file');
  if (manifestFile !== basename(manifestFile) || !manifestFile.endsWith('.json')) {
    fail('F5 provenance manifest_file 无效');
  }
  const manifestPath = resolve(evidenceDirPath, manifestFile);
  const manifestBytes = await readFile(manifestPath);
  if (!sha256Pattern.test(string(assertions.provenance.manifest_sha256, 'f5.provenance.manifest_sha256'))
    || createHash('sha256').update(manifestBytes).digest('hex') !== assertions.provenance.manifest_sha256) {
    fail('F5 provenance manifest 摘要不匹配');
  }
  const manifest = JSON.parse(manifestBytes.toString('utf8')) as Record<string, unknown>;
  if (manifest.source_commit !== subjectCommit) {
    fail('F5 provenance source commit 与 evidence subject 不一致');
  }
  try {
    execFileSync('bun', [
      resolve(root, 'scripts/e2ee-evidence/verify-provenance.ts'), manifestPath,
    ], { cwd: root, stdio: ['ignore', 'ignore', 'pipe'] });
  } catch {
    fail('F5 四类 provenance 离线验签失败');
  }
}

function verifyG3(assertions: Record<string, unknown>): void {
  exactKeys(assertions, ['release_attestation', 'production_path', 'browser_boundaries'], 'g3.assertions');
  exactKeys(assertions.release_attestation, ['manifest_sha256', 'browser_manifest_matches'], 'g3.release_attestation');
  if (!sha256Pattern.test(string(assertions.release_attestation.manifest_sha256, 'manifest_sha256'))
    || !boolean(assertions.release_attestation.browser_manifest_matches, 'browser_manifest_matches')) {
    fail('G3 release attestation 无效');
  }
  const productionKeys = [
    'distinct_browser_contexts', 'ui_login', 'ui_message_round_trip',
    'recipient_decrypted_message', 'production_database', 'secure_context',
    'wrapping_key_non_extractable', 'wrapping_key_export_blocked', 'encrypted_record_count',
    'encrypted_record_structure_valid', 'secure_state_forbidden_values_absent',
    'browser_storage_password_marker_free', 'aad_mismatch_failed_closed',
    'plaintext_downgrade_blocked',
  ] as const;
  exactKeys(assertions.production_path, productionKeys, 'g3.production_path');
  enumValue(assertions.production_path.production_database, ['redcode-h5-e2ee-state'] as const, 'production_database');
  if (integer(assertions.production_path.encrypted_record_count, 'encrypted_record_count') < 1) {
    fail('未观测 production encrypted record');
  }
  for (const key of productionKeys.filter((key) => !['production_database', 'encrypted_record_count'].includes(key))) {
    if (!boolean(assertions.production_path[key], `g3.production_path.${key}`)) fail(`G3 ${key} 未通过`);
  }
  exactKeys(assertions.browser_boundaries, [
    'checked_at', 'network_url_count', 'websocket_frame_count', 'console_message_count',
    'page_error_count', 'private_artifacts_get_head', 'missing_asset',
  ], 'g3.browser_boundaries');
  const checkedAt = string(assertions.browser_boundaries.checked_at, 'checked_at');
  if (!timestampPattern.test(checkedAt) || Number.isNaN(Date.parse(checkedAt))) fail('checked_at 无效');
  if (integer(assertions.browser_boundaries.network_url_count, 'network_url_count') < 1) {
    fail('未观测 Network URL');
  }
  if (integer(assertions.browser_boundaries.websocket_frame_count, 'websocket_frame_count') < 1) {
    fail('未观测 WebSocket frame');
  }
  integer(assertions.browser_boundaries.console_message_count, 'console_message_count');
  if (integer(assertions.browser_boundaries.page_error_count, 'page_error_count') !== 0) fail('存在 page error');
  enumValue(assertions.browser_boundaries.private_artifacts_get_head, ['404'] as const, 'private_artifacts_get_head');
  enumValue(assertions.browser_boundaries.missing_asset, ['404'] as const, 'missing_asset');
}

for (const [type, name] of files) {
  let evidence: Record<string, unknown>;
  try {
    evidence = JSON.parse(await readFile(resolve(evidenceDir, name), 'utf8')) as Record<string, unknown>;
  } catch {
    fail(`缺失或无法读取 evidence：${name}`);
  }
  exactKeys(evidence, schema.common_keys as string[], name);
  if (evidence.schema !== evidenceSchema || evidence.evidence_type !== type) fail(`${name} 身份不匹配`);
  const commit = string(evidence.subject_commit, `${name}.subject_commit`);
  const committedAt = string(evidence.subject_committed_at, `${name}.subject_committed_at`);
  if (!timestampPattern.test(committedAt) || Number.isNaN(Date.parse(committedAt))) fail(`${name} commit 时间无效`);
  exactKeys(evidence.generator, ['name', 'version'], `${name}.generator`);
  if (evidence.generator.name !== generator.name || evidence.generator.version !== generator.version) {
    fail(`${name} generator 身份不匹配`);
  }
  const integrity = string(evidence.integrity_sha256, `${name}.integrity_sha256`);
  if (!sha256Pattern.test(integrity)) fail(`${name} integrity 格式无效`);
  const { integrity_sha256: _, ...envelope } = evidence;
  if (sha256(envelope) !== integrity) fail(`${name} integrity 校验失败`);
  assertSensitiveValuesAbsent(envelope);
  verifyCommit(commit);
  if (subjectCommitTime(root, commit) !== committedAt) fail(`${name} commit 时间与 Git 不一致`);
  exactKeys(evidence.assertions, (
    schema.evidence_types as Record<string, { assertion_keys: string[] }>
  )[type].assertion_keys, `${name}.assertions`);
  if (type === 'g1-backup-rollout') verifyG1(evidence.assertions);
  else if (type === 'g3-h5-release') verifyG3(evidence.assertions);
  else await verifyF5(evidence.assertions, evidenceDir, commit, f5ProvenanceKeys);
  console.log(`[e2ee-evidence] verified ${name} subject=${commit}`);
}
