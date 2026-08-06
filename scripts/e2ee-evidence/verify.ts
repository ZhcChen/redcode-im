import { execFileSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
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
exactKeys(schema.evidence_types, ['g1-backup-rollout', 'g3-h5-release'], 'schema-v1.evidence_types');

const files: Array<[EvidenceType, string]> = [
  ['g1-backup-rollout', 'g1-backup-rollout.json'],
  ['g3-h5-release', 'g3-h5-release.json'],
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
    'verified', 'runtime', 'source_network_reachable', 'source_postgres_connections',
    'source_redis_connections',
  ], 'g1.restore_runtime');
  if (!boolean(assertions.restore_runtime.verified, 'g1.restore_runtime.verified')) fail('restore 未验证');
  enumValue(assertions.restore_runtime.runtime, ['persist/e2ee'] as const, 'g1.restore_runtime.runtime');
  if (boolean(assertions.restore_runtime.source_network_reachable, 'source_network_reachable')) {
    fail('restore source network 可达');
  }
  if (integer(assertions.restore_runtime.source_postgres_connections, 'source_postgres_connections') !== 0
    || integer(assertions.restore_runtime.source_redis_connections, 'source_redis_connections') !== 0) {
    fail('restore 连接旧主');
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
  exactKeys(evidence.assertions, (
    schema.evidence_types as Record<string, { assertion_keys: string[] }>
  )[type].assertion_keys, `${name}.assertions`);
  if (type === 'g1-backup-rollout') verifyG1(evidence.assertions);
  else verifyG3(evidence.assertions);
  console.log(`[e2ee-evidence] verified ${name} subject=${commit}`);
}
