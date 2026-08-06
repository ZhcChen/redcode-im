import { createHash } from 'node:crypto';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { basename, dirname, resolve } from 'node:path';
import {
  assertSensitiveValuesAbsent,
  boolean,
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
  type EvidenceType,
} from './contract';

const root = resolve(import.meta.dir, '../..');
const args = new Map<string, string>();
for (let index = 2; index < process.argv.length; index += 2) {
  const key = process.argv[index];
  const value = process.argv[index + 1];
  if (!key?.startsWith('--') || !value) fail('参数必须使用 --name value');
  args.set(key.slice(2), value);
}

const mode = args.get('type') as EvidenceType | undefined;
const subjectCommit = args.get('subject-commit') ?? '';
const output = resolve(args.get('output') ?? '');
if (!mode || !['g1-backup-rollout', 'g3-h5-release', 'f5-release-workflow'].includes(mode)) {
  fail('缺少合法 --type');
}
if (!args.get('output')) fail('缺少 --output');

async function json(path: string): Promise<Record<string, unknown>> {
  try {
    return JSON.parse(await readFile(resolve(path), 'utf8')) as Record<string, unknown>;
  } catch {
    fail(`无法读取 JSON：${path}`);
  }
}

function snapshot(value: unknown, context: string) {
  const keys = ['attachment_commits', 'control_messages', 'control_receipts', 'devices', 'digest',
    'encrypted_messages', 'identities', 'key_packages', 'room_epochs'] as const;
  exactKeys(value, keys, context);
  const digest = string(value.digest, `${context}.digest`);
  if (!/^[a-f0-9]{32}$/.test(digest)) fail(`${context}.digest 格式无效`);
  return {
    attachment_commits: integer(value.attachment_commits, `${context}.attachment_commits`),
    control_messages: integer(value.control_messages, `${context}.control_messages`),
    control_receipts: integer(value.control_receipts, `${context}.control_receipts`),
    devices: integer(value.devices, `${context}.devices`),
    digest,
    encrypted_messages: integer(value.encrypted_messages, `${context}.encrypted_messages`),
    identities: integer(value.identities, `${context}.identities`),
    key_packages: integer(value.key_packages, `${context}.key_packages`),
    room_epochs: integer(value.room_epochs, `${context}.room_epochs`),
  };
}

function proofKind(value: unknown, context: string): 'text' | 'attachment' {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail(`${context} 必须是 object`);
  const record = value as Record<string, unknown>;
  const kind = enumValue(record.kind, ['text', 'attachment'] as const, `${context}.kind`);
  exactKeys(record, kind === 'attachment'
    ? ['message_id', 'plaintext_marker', 'ciphertext_sha256', 'binding_hmac', 'kind', 'object_key']
    : ['message_id', 'plaintext_marker', 'ciphertext_sha256', 'binding_hmac', 'kind'], context);
  if (!/^[0-9a-f-]{36}$/.test(string(record.message_id, `${context}.message_id`))) {
    fail(`${context}.message_id 格式无效`);
  }
  string(record.plaintext_marker, `${context}.plaintext_marker`);
  for (const key of ['ciphertext_sha256', 'binding_hmac'] as const) {
    if (!sha256Pattern.test(string(record[key], `${context}.${key}`))) fail(`${context}.${key} 格式无效`);
  }
  if (kind === 'attachment') string(record.object_key, `${context}.object_key`);
  return kind;
}

async function sanitizeG1(): Promise<Record<string, unknown>> {
  const input = args.get('input-dir');
  if (!input) fail('G1 缺少 --input-dir');
  const directory = resolve(input);
  const [switched, live, recovery, postLive, boundary] = await Promise.all([
    json(`${directory}/switch.json`),
    json(`${directory}/live.json`),
    json(`${directory}/recovery.json`),
    json(`${directory}/post-live-snapshot.json`),
    json(`${directory}/boundary-scan.json`),
  ]);
  exactKeys(switched, ['identity', 'candidate_snapshot', 'restore_snapshot', 'snapshots_match'], 'switch');
  exactKeys(switched.identity, [
    'run_id', 'project', 'database_marker', 'api_container_id', 'api_url', 'database_host',
    'redis_host', 'isolation', 'runtime', 'verified',
  ], 'switch.identity');
  exactKeys(switched.identity.isolation, [
    'api_networks_exclude_source', 'database_url_points_restore', 'redis_urls_point_restore',
    'storage_network_members_exact', 'ingress_network_members_exact',
  ], 'switch.identity.isolation');
  exactKeys(live, ['run_id', 'scenarios'], 'live');
  if (!Array.isArray(live.scenarios)) fail('live.scenarios 必须是 array');
  const proofs = live.scenarios.flatMap((scenario, index) => {
    const context = `live.scenarios[${index}]`;
    if (!scenario || typeof scenario !== 'object' || Array.isArray(scenario)) fail(`${context} 必须是 object`);
    const record = scenario as Record<string, unknown>;
    const scenarioKeys = record.name === 'restore-continuity'
      ? [
          'name', 'room_id', 'message_proofs', 'before_message_id', 'after_message_id',
          'history_decrypted_after_restore', 'new_message_decrypted_after_restore',
        ]
      : ['name', 'room_id', 'message_proofs'];
    exactKeys(record, scenarioKeys, context);
    if (!Array.isArray(record.message_proofs)) fail('message_proofs 必须是 array');
    return record.message_proofs as Array<Record<string, unknown>>;
  });
  const proofKinds = proofs.map((proof, index) => proofKind(proof, `live.message_proofs[${index}]`));
  const attachmentProofCount = proofKinds.filter((kind) => kind === 'attachment').length;
  exactKeys(recovery, [
    'name', 'room_id', 'before_message_id', 'after_message_id', 'message_proofs',
    'history_decrypted_after_restore', 'new_message_decrypted_after_restore',
  ], 'recovery');
  if (!Array.isArray(recovery.message_proofs)) fail('recovery.message_proofs 必须是 array');
  recovery.message_proofs.forEach((proof, index) => proofKind(proof, `recovery.message_proofs[${index}]`));
  exactKeys(boundary, ['run_id', 'db', 'redis', 'logs', 'push', 'rustfs'], 'boundary');
  exactKeys(boundary.rustfs, ['object_key', 'content', 'sha256'], 'boundary.rustfs');
  const rustfsSha = string(boundary.rustfs.sha256, 'boundary.rustfs.sha256');
  if (!sha256Pattern.test(rustfsSha)) fail('boundary.rustfs.sha256 格式无效');
  if (live.run_id !== switched.identity.run_id || boundary.run_id !== switched.identity.run_id) {
    fail('G1 run_id 不一致');
  }
  return {
    run_id: string(live.run_id, 'run_id'),
    snapshot: {
      matched: boolean(switched.snapshots_match, 'snapshots_match'),
      candidate: snapshot(switched.candidate_snapshot, 'candidate_snapshot'),
      restore: snapshot(switched.restore_snapshot, 'restore_snapshot'),
    },
    restore_runtime: {
      verified: boolean(switched.identity.verified, 'identity.verified'),
      runtime: enumValue(switched.identity.runtime, ['persist/e2ee'] as const, 'identity.runtime'),
      isolation: {
        api_networks_exclude_source: boolean(switched.identity.isolation.api_networks_exclude_source, 'identity.isolation.api_networks_exclude_source'),
        database_url_points_restore: boolean(switched.identity.isolation.database_url_points_restore, 'identity.isolation.database_url_points_restore'),
        redis_urls_point_restore: boolean(switched.identity.isolation.redis_urls_point_restore, 'identity.isolation.redis_urls_point_restore'),
        storage_network_members_exact: boolean(switched.identity.isolation.storage_network_members_exact, 'identity.isolation.storage_network_members_exact'),
        ingress_network_members_exact: boolean(switched.identity.isolation.ingress_network_members_exact, 'identity.isolation.ingress_network_members_exact'),
      },
    },
    live: {
      scenario_count: live.scenarios.length,
      message_proof_count: proofs.length,
      attachment_proof_count: attachmentProofCount,
      history_decrypted_after_restore: boolean(
        recovery.history_decrypted_after_restore,
        'recovery.history_decrypted_after_restore',
      ),
      new_message_decrypted_after_restore: boolean(
        recovery.new_message_decrypted_after_restore,
        'recovery.new_message_decrypted_after_restore',
      ),
    },
    post_live_snapshot: snapshot(postLive, 'post_live_snapshot'),
    boundaries: {
      db: enumValue(boundary.db, ['ciphertext-only'] as const, 'boundary.db'),
      redis: enumValue(boundary.redis, ['marker-free'] as const, 'boundary.redis'),
      logs: enumValue(boundary.logs, ['marker-free'] as const, 'boundary.logs'),
      push: enumValue(boundary.push, ['placeholder-only', 'not-observed-live'] as const, 'boundary.push'),
      rustfs_content: enumValue(boundary.rustfs.content, ['ciphertext-only'] as const, 'boundary.rustfs.content'),
      rustfs_sha256: rustfsSha,
    },
  };
}

async function sanitizeF5(): Promise<Record<string, unknown>> {
  const workflowPath = args.get('workflow');
  const bundlePath = args.get('bundle');
  if (!workflowPath || !bundlePath) fail('F5 缺少 --workflow/--bundle');
  const workflow = await json(workflowPath);
  exactKeys(workflow, [
    'schema', 'run_id', 'workflow_name', 'event', 'head_sha', 'conclusion',
    'publish_release', 'created_at', 'completed_at', 'jobs', 'artifacts', 'asset_digests',
    'release_state', 'provenance',
  ], 'workflow');
  if (workflow.schema !== 'redcode-f5-release-workflow-raw/v1') fail('F5 workflow schema 无效');
  if (workflow.head_sha !== subjectCommit) fail('F5 head_sha 与 subject_commit 不一致');
  if (!Array.isArray(workflow.jobs) || !Array.isArray(workflow.artifacts)) {
    fail('F5 jobs/artifacts 必须是 array');
  }
  const jobs = workflow.jobs.map((value, index) => {
    exactKeys(value, ['name', 'conclusion', 'required'], `workflow.jobs[${index}]`);
    return {
      name: string(value.name, `workflow.jobs[${index}].name`),
      conclusion: enumValue(value.conclusion, ['success', 'skipped'] as const, `workflow.jobs[${index}].conclusion`),
      required: boolean(value.required, `workflow.jobs[${index}].required`),
    };
  });
  const artifacts = workflow.artifacts.map((value, index) => {
    exactKeys(value, ['name', 'digest', 'size_in_bytes'], `workflow.artifacts[${index}]`);
    const digest = string(value.digest, `workflow.artifacts[${index}].digest`);
    if (!/^sha256:[a-f0-9]{64}$/.test(digest)) fail('F5 artifact digest 无效');
    return {
      name: string(value.name, `workflow.artifacts[${index}].name`),
      digest,
      size_in_bytes: integer(value.size_in_bytes, `workflow.artifacts[${index}].size_in_bytes`),
    };
  });
  exactKeys(workflow.asset_digests, [
    'h5_archive_sha256', 'android_apk_sha256', 'h5_manifest_sha256', 'wasm_sha256',
  ], 'workflow.asset_digests');
  exactKeys(workflow.release_state, [
    'tags_before_sha256', 'tags_after_sha256', 'releases_before_sha256',
    'releases_after_sha256', 'unchanged',
  ], 'workflow.release_state');
  exactKeys(workflow.provenance, [
    'subject_name', 'subject_sha256', 'source_commit', 'predicate_type',
  ], 'workflow.provenance');
  const bundleBytes = await readFile(resolve(bundlePath));
  const bundleSha256 = createHash('sha256').update(bundleBytes).digest('hex');
  return {
    run: {
      id: integer(workflow.run_id, 'workflow.run_id'),
      workflow_name: string(workflow.workflow_name, 'workflow.workflow_name'),
      event: enumValue(workflow.event, ['workflow_dispatch'] as const, 'workflow.event'),
      head_sha: string(workflow.head_sha, 'workflow.head_sha'),
      conclusion: enumValue(workflow.conclusion, ['success'] as const, 'workflow.conclusion'),
      publish_release: boolean(workflow.publish_release, 'workflow.publish_release'),
      created_at: string(workflow.created_at, 'workflow.created_at'),
      completed_at: string(workflow.completed_at, 'workflow.completed_at'),
    },
    jobs,
    artifacts,
    asset_digests: Object.fromEntries(Object.entries(workflow.asset_digests).map(([key, value]) => {
      const digest = string(value, `workflow.asset_digests.${key}`);
      if (!sha256Pattern.test(digest)) fail(`workflow.asset_digests.${key} 无效`);
      return [key, digest];
    })),
    release_state: workflow.release_state,
    provenance: {
      subject_name: string(workflow.provenance.subject_name, 'workflow.provenance.subject_name'),
      subject_sha256: string(workflow.provenance.subject_sha256, 'workflow.provenance.subject_sha256'),
      source_commit: string(workflow.provenance.source_commit, 'workflow.provenance.source_commit'),
      predicate_type: enumValue(
        workflow.provenance.predicate_type,
        ['https://slsa.dev/provenance/v1'] as const,
        'workflow.provenance.predicate_type',
      ) === 'https://slsa.dev/provenance/v1' ? 'slsa-provenance-v1' : fail('F5 predicate 无效'),
      bundle_file: basename(bundlePath),
      bundle_sha256: bundleSha256,
    },
  };
}

async function sanitizeG3(): Promise<Record<string, unknown>> {
  const browserPath = args.get('browser');
  const attestationPath = args.get('attestation');
  if (!browserPath || !attestationPath) fail('G3 缺少 --browser/--attestation');
  const [browser, attestation] = await Promise.all([json(browserPath), json(attestationPath)]);
  exactKeys(attestation, ['schema', 'source_commit', 'manifest_sha256'], 'attestation');
  exactKeys(browser, [
    'schema', 'source_commit', 'candidate_origin', 'api_path', 'base_path', 'manifest_sha256',
    'checked_at', 'response_headers', 'private_artifacts_get_head', 'missing_asset',
    'production_path', 'network_url_count', 'websocket_frame_count', 'console_message_count',
    'page_error_count',
  ], 'browser');
  exactKeys(browser.production_path, [
    'distinct_browser_contexts', 'ui_login', 'ui_message_round_trip',
    'recipient_decrypted_message', 'production_database', 'secure_context',
    'wrapping_key_non_extractable', 'wrapping_key_export_blocked', 'encrypted_record_count',
    'encrypted_record_structure_valid', 'secure_state_forbidden_values_absent',
    'browser_storage_password_marker_free', 'local_decrypted_message_storage',
    'aad_mismatch_failed_closed', 'plaintext_downgrade_blocked',
  ], 'browser.production_path');
  if (browser.source_commit !== subjectCommit || attestation.source_commit !== subjectCommit) {
    fail('G3 subject_commit 与原始 evidence 不一致');
  }
  if (browser.manifest_sha256 !== attestation.manifest_sha256) fail('G3 manifest 摘要不一致');
  const manifestSha = string(browser.manifest_sha256, 'manifest_sha256');
  if (!sha256Pattern.test(manifestSha)) fail('manifest_sha256 格式无效');
  const production = browser.production_path;
  return {
    release_attestation: { manifest_sha256: manifestSha, browser_manifest_matches: true },
    production_path: {
      distinct_browser_contexts: boolean(production.distinct_browser_contexts, 'distinct_browser_contexts'),
      ui_login: boolean(production.ui_login, 'ui_login'),
      ui_message_round_trip: boolean(production.ui_message_round_trip, 'ui_message_round_trip'),
      recipient_decrypted_message: boolean(production.recipient_decrypted_message, 'recipient_decrypted_message'),
      production_database: enumValue(production.production_database, ['redcode-h5-e2ee-state'] as const, 'production_database'),
      secure_context: boolean(production.secure_context, 'secure_context'),
      wrapping_key_non_extractable: boolean(production.wrapping_key_non_extractable, 'wrapping_key_non_extractable'),
      wrapping_key_export_blocked: boolean(production.wrapping_key_export_blocked, 'wrapping_key_export_blocked'),
      encrypted_record_count: integer(production.encrypted_record_count, 'encrypted_record_count'),
      encrypted_record_structure_valid: boolean(production.encrypted_record_structure_valid, 'encrypted_record_structure_valid'),
      secure_state_forbidden_values_absent: boolean(production.secure_state_forbidden_values_absent, 'secure_state_forbidden_values_absent'),
      browser_storage_password_marker_free: boolean(production.browser_storage_password_marker_free, 'browser_storage_password_marker_free'),
      aad_mismatch_failed_closed: boolean(production.aad_mismatch_failed_closed, 'aad_mismatch_failed_closed'),
      plaintext_downgrade_blocked: boolean(production.plaintext_downgrade_blocked, 'plaintext_downgrade_blocked'),
    },
    browser_boundaries: {
      checked_at: string(browser.checked_at, 'checked_at'),
      network_url_count: integer(browser.network_url_count, 'network_url_count'),
      websocket_frame_count: integer(browser.websocket_frame_count, 'websocket_frame_count'),
      console_message_count: integer(browser.console_message_count, 'console_message_count'),
      page_error_count: integer(browser.page_error_count, 'page_error_count'),
      private_artifacts_get_head: enumValue(browser.private_artifacts_get_head, ['404'] as const, 'private_artifacts_get_head'),
      missing_asset: enumValue(browser.missing_asset, ['404'] as const, 'missing_asset'),
    },
  };
}

const assertions = mode === 'g1-backup-rollout'
  ? await sanitizeG1()
  : mode === 'g3-h5-release'
    ? await sanitizeG3()
    : await sanitizeF5();
const envelope = {
  schema: evidenceSchema,
  evidence_type: mode,
  subject_commit: subjectCommit,
  subject_committed_at: subjectCommitTime(root, subjectCommit),
  generator,
  assertions,
};
assertSensitiveValuesAbsent(envelope);
const evidence = { ...envelope, integrity_sha256: sha256(envelope) };
await mkdir(dirname(output), { recursive: true });
await writeFile(output, `${JSON.stringify(evidence, null, 2)}\n`);
console.log(`[e2ee-evidence] 已生成 ${mode}: ${output}`);
