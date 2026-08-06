import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import { sha256 } from '../../scripts/e2ee-evidence/contract';

const root = resolve(import.meta.dir, '../..');
const committedEvidence = resolve(root, 'docs/reviews/evidence/u10-e2ee');
const verifier = resolve(root, 'scripts/e2ee-evidence/verify.ts');
const sanitizer = resolve(root, 'scripts/e2ee-evidence/sanitize.ts');
const fixture = await mkdtemp(resolve(tmpdir(), 'redcode-e2ee-evidence.'));
const head = Bun.spawnSync(['git', 'rev-parse', 'HEAD'], { cwd: root }).stdout.toString().trim();

async function run(
  command: string[],
  expectedSuccess: boolean,
  label: string,
  env?: Record<string, string>,
): Promise<void> {
  const result = Bun.spawnSync(command, {
    cwd: root,
    stdout: 'pipe',
    stderr: 'pipe',
    env: { ...process.env, ...env },
  });
  if ((result.exitCode === 0) !== expectedSuccess) {
    throw new Error(`${label}: unexpected exit ${result.exitCode}\n${result.stderr.toString()}`);
  }
  console.log(`[e2ee-evidence-test] ${label}: ${expectedSuccess ? 'pass' : 'fail closed'}`);
}

async function copyEvidence(name: string): Promise<string> {
  const target = resolve(fixture, name);
  await cp(committedEvidence, target, { recursive: true });
  return target;
}

async function rewrite(
  directory: string,
  file: string,
  mutate: (value: Record<string, any>) => void,
  resign = false,
): Promise<void> {
  const path = resolve(directory, file);
  const value = JSON.parse(await readFile(path, 'utf8')) as Record<string, any>;
  mutate(value);
  if (resign) {
    const { integrity_sha256: _, ...envelope } = value;
    value.integrity_sha256 = sha256(envelope);
  }
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`);
}

try {
  await run(['bun', verifier], true, 'committed evidence');

  const tampered = await copyEvidence('tampered');
  await rewrite(tampered, 'g1-backup-rollout.json', (value) => {
    value.assertions.live.message_proof_count += 1;
  });
  await run(['bun', verifier, tampered], false, 'payload tamper');

  const extraField = await copyEvidence('extra-field');
  await rewrite(extraField, 'g3-h5-release.json', (value) => {
    value.assertions.production_path.unreviewed = true;
  }, true);
  await run(['bun', verifier, extraField], false, 'resigned extra field');

  const sensitive = await copyEvidence('sensitive');
  await rewrite(sensitive, 'g1-backup-rollout.json', (value) => {
    value.assertions.run_id = 'u10-restore-plaintext-marker';
  }, true);
  await run(['bun', verifier, sensitive], false, 'resigned sensitive marker');

  const semantic = await copyEvidence('semantic');
  await rewrite(semantic, 'g1-backup-rollout.json', (value) => {
    value.assertions.snapshot.matched = false;
  }, true);
  await run(['bun', verifier, semantic], false, 'resigned semantic failure');

  const noWebSocket = await copyEvidence('no-websocket');
  await rewrite(noWebSocket, 'g3-h5-release.json', (value) => {
    value.assertions.browser_boundaries.websocket_frame_count = 0;
  }, true);
  await run(['bun', verifier, noWebSocket], false, 'resigned missing observation');

  const unreachable = await copyEvidence('unreachable');
  await rewrite(unreachable, 'g3-h5-release.json', (value) => {
    value.subject_commit = '0'.repeat(40);
  }, true);
  await run(['bun', verifier, unreachable], false, 'unreachable subject commit');

  const wrongCommitTime = await copyEvidence('wrong-commit-time');
  await rewrite(wrongCommitTime, 'g3-h5-release.json', (value) => {
    value.subject_committed_at = '2026-01-01T00:00:00Z';
  }, true);
  await run(['bun', verifier, wrongCommitTime], false, 'resigned wrong commit time');

  const failedRequiredJob = await copyEvidence('failed-required-job');
  await rewrite(failedRequiredJob, 'f5-release-workflow.json', (value) => {
    value.assertions.jobs.find((job: any) => job.name === 'API test').conclusion = 'skipped';
  }, true);
  await run(['bun', verifier, failedRequiredJob], false, 'resigned failed required job');

  const releaseSideEffect = await copyEvidence('release-side-effect');
  await rewrite(releaseSideEffect, 'f5-release-workflow.json', (value) => {
    value.assertions.release_state.tags_after_sha256 = '0'.repeat(64);
  }, true);
  await run(['bun', verifier, releaseSideEffect], false, 'resigned release side effect');

  const tamperedBundle = await copyEvidence('tampered-bundle');
  const tamperedManifest = JSON.parse(await readFile(
    resolve(tamperedBundle, 'f5-provenance-manifest.json'),
    'utf8',
  ));
  await writeFile(resolve(tamperedBundle, tamperedManifest.subjects[0].bundle_file), '{}\n');
  await run(['bun', verifier, tamperedBundle], false, 'SLSA bundle tamper');

  const missing = await copyEvidence('missing');
  await rm(resolve(missing, 'g1-backup-rollout.json'));
  await run(['bun', verifier, missing], false, 'missing evidence');

  const schemaSource = resolve(root, 'scripts/e2ee-evidence/schema-v1.json');
  const driftedSchema = resolve(fixture, 'schema-drift.json');
  const schema = JSON.parse(await readFile(schemaSource, 'utf8'));
  schema.additional_properties = true;
  await writeFile(driftedSchema, `${JSON.stringify(schema, null, 2)}\n`);
  await run(
    ['bun', verifier],
    false,
    'schema drift',
    { E2EE_EVIDENCE_SCHEMA: driftedSchema },
  );

  const generated = resolve(fixture, 'generated');
  const raw = resolve(fixture, 'raw');
  await mkdir(generated, { recursive: true });
  await mkdir(raw, { recursive: true });
  const committedG1 = JSON.parse(
    await readFile(resolve(committedEvidence, 'g1-backup-rollout.json'), 'utf8'),
  );
  const committedG3 = JSON.parse(
    await readFile(resolve(committedEvidence, 'g3-h5-release.json'), 'utf8'),
  );
  const committedF5 = JSON.parse(
    await readFile(resolve(committedEvidence, 'f5-release-workflow.json'), 'utf8'),
  );
  const snapshot = committedG1.assertions.snapshot.candidate;
  let proofSequence = 0;
  const proof = (kind = 'text') => {
    proofSequence += 1;
    return {
      message_id: `00000000-0000-4000-8000-${String(proofSequence).padStart(12, '0')}`,
      plaintext_marker: `fixture-marker-${proofSequence}`,
      ciphertext_sha256: String(proofSequence).padStart(64, '0'),
      binding_hmac: String(proofSequence + 20).padStart(64, '0'),
      kind,
      ...(kind === 'attachment' ? { object_key: 'fixture/object.bin' } : {}),
    };
  };
  const rawG1 = {
    switch: {
      identity: {
        run_id: 'fixture-run', project: 'fixture', database_marker: 'fixture',
        api_container_id: 'fixture', api_url: 'http://127.0.0.1:18010',
        database_host: 'postgres-restore', redis_host: 'redis-restore',
        isolation: {
          api_networks_exclude_source: true,
          database_url_points_restore: true,
          redis_urls_point_restore: true,
          storage_network_members_exact: true,
          ingress_network_members_exact: true,
        },
        runtime: 'persist/e2ee', verified: true,
      },
      candidate_snapshot: snapshot,
      restore_snapshot: snapshot,
      snapshots_match: true,
    },
    live: {
      run_id: 'fixture-run',
      scenarios: [
        {
          name: 'restore-continuity', room_id: 'removed',
          before_message_id: 'removed', after_message_id: 'removed',
          history_decrypted_after_restore: true, new_message_decrypted_after_restore: true,
          message_proofs: [proof(), proof()],
        },
        { name: 'h5-h5', room_id: 'removed', message_proofs: [proof(), proof()] },
        { name: 'android-h5', room_id: 'removed', message_proofs: [proof(), proof(), proof('attachment')] },
        { name: 'ios-h5', room_id: 'removed', message_proofs: [proof(), proof()] },
      ],
    },
    recovery: {
      name: 'restore-continuity', room_id: 'removed', before_message_id: 'removed',
      after_message_id: 'removed', message_proofs: [proof(), proof()],
      history_decrypted_after_restore: true, new_message_decrypted_after_restore: true,
    },
    post: committedG1.assertions.post_live_snapshot,
    boundary: {
      run_id: 'fixture-run', db: 'ciphertext-only', redis: 'marker-free',
      logs: 'marker-free', push: 'not-observed-live',
      rustfs: {
        object_key: 'removed-before-output', content: 'ciphertext-only',
        sha256: committedG1.assertions.boundaries.rustfs_sha256,
      },
    },
  };
  for (const [name, value] of Object.entries({
    'switch.json': rawG1.switch,
    'live.json': rawG1.live,
    'recovery.json': rawG1.recovery,
    'post-live-snapshot.json': rawG1.post,
    'boundary-scan.json': rawG1.boundary,
  })) await writeFile(resolve(raw, name), `${JSON.stringify(value)}\n`);

  const rawBrowser = {
    schema: 'redcode-h5-browser-audit/v2', source_commit: head,
    candidate_origin: 'https://removed.invalid', api_path: '/api', base_path: '/candidate/',
    manifest_sha256: committedG3.assertions.release_attestation.manifest_sha256,
    checked_at: committedG3.assertions.browser_boundaries.checked_at,
    response_headers: {}, private_artifacts_get_head: '404', missing_asset: '404',
    production_path: {
      ...committedG3.assertions.production_path,
      local_decrypted_message_storage: 'allowed-for-local-search',
    },
    network_url_count: 1, websocket_frame_count: 1, console_message_count: 0,
    page_error_count: 0,
  };
  const rawAttestation = {
    schema: 'redcode-h5-release-attestation/v1', source_commit: head,
    manifest_sha256: rawBrowser.manifest_sha256,
  };
  await writeFile(resolve(raw, 'browser.json'), `${JSON.stringify(rawBrowser)}\n`);
  await writeFile(resolve(raw, 'attestation.json'), `${JSON.stringify(rawAttestation)}\n`);
  const rawF5 = {
    schema: 'redcode-f5-release-workflow-raw/v2',
    run_id: committedF5.assertions.run.id,
    workflow_name: committedF5.assertions.run.workflow_name,
    event: committedF5.assertions.run.event,
    head_sha: committedF5.subject_commit,
    conclusion: committedF5.assertions.run.conclusion,
    publish_release: committedF5.assertions.run.publish_release,
    created_at: committedF5.assertions.run.created_at,
    completed_at: committedF5.assertions.run.completed_at,
    jobs: committedF5.assertions.jobs,
    artifacts: committedF5.assertions.artifacts,
    asset_digests: committedF5.assertions.asset_digests,
    release_state: committedF5.assertions.release_state,
  };
  await writeFile(resolve(raw, 'workflow.json'), `${JSON.stringify(rawF5)}\n`);
  await copyProvenanceSet(committedEvidence, raw);

  await run([
    'bun', sanitizer, '--type', 'g1-backup-rollout', '--subject-commit', head,
    '--input-dir', raw, '--output', resolve(generated, 'g1-backup-rollout.json'),
  ], true, 'G1 generation');
  await run([
    'bun', sanitizer, '--type', 'g3-h5-release', '--subject-commit', head,
    '--browser', resolve(raw, 'browser.json'), '--attestation', resolve(raw, 'attestation.json'),
    '--output', resolve(generated, 'g3-h5-release.json'),
  ], true, 'G3 generation');
  await run([
    'bun', sanitizer, '--type', 'f5-release-workflow',
    '--subject-commit', committedF5.subject_commit,
    '--workflow', resolve(raw, 'workflow.json'),
    '--provenance-manifest', resolve(raw, 'f5-provenance-manifest.json'),
    '--output', resolve(generated, 'f5-release-workflow.json'),
  ], true, 'F5 generation');
  await copyProvenanceSet(raw, generated);
  await run(['bun', verifier, generated], true, 'generated evidence verification');

  const invalidIsolation = JSON.parse(await readFile(resolve(raw, 'switch.json'), 'utf8'));
  invalidIsolation.identity.isolation.api_networks_exclude_source = false;
  await writeFile(resolve(raw, 'switch-invalid-isolation.json'), `${JSON.stringify(invalidIsolation)}\n`);
  await writeFile(resolve(raw, 'switch.json'), `${JSON.stringify(invalidIsolation)}\n`);
  await run([
    'bun', sanitizer, '--type', 'g1-backup-rollout', '--subject-commit', head,
    '--input-dir', raw, '--output', resolve(generated, 'invalid-isolation.json'),
  ], true, 'G1 false isolation generation');
  await cp(
    resolve(generated, 'invalid-isolation.json'),
    resolve(generated, 'g1-backup-rollout.json'),
  );
  await run(['bun', verifier, generated], false, 'G1 false isolation verification');

  const rawWithExtra = JSON.parse(await readFile(resolve(raw, 'browser.json'), 'utf8'));
  rawWithExtra.unreviewed = true;
  await writeFile(resolve(raw, 'browser-extra.json'), `${JSON.stringify(rawWithExtra)}\n`);
  await run([
    'bun', sanitizer, '--type', 'g3-h5-release', '--subject-commit', head,
    '--browser', resolve(raw, 'browser-extra.json'), '--attestation', resolve(raw, 'attestation.json'),
    '--output', resolve(generated, 'should-not-exist.json'),
  ], false, 'raw extra field');

  const malformedG1 = JSON.parse(await readFile(resolve(raw, 'live.json'), 'utf8'));
  malformedG1.scenarios[0].message_proofs[0].binding_hmac = 'short';
  await writeFile(resolve(raw, 'live.json'), `${JSON.stringify(malformedG1)}\n`);
  await run([
    'bun', sanitizer, '--type', 'g1-backup-rollout', '--subject-commit', head,
    '--input-dir', raw, '--output', resolve(generated, 'malformed-g1.json'),
  ], false, 'malformed raw proof');
} finally {
  await rm(fixture, { recursive: true, force: true });
}

async function copyProvenanceSet(source: string, target: string): Promise<void> {
  const manifestName = 'f5-provenance-manifest.json';
  const manifest = JSON.parse(await readFile(resolve(source, manifestName), 'utf8'));
  const names = new Set<string>([manifestName, manifest.trusted_root_file]);
  for (const subject of manifest.subjects) {
    names.add(subject.sidecar_file);
    names.add(subject.bundle_file);
  }
  for (const name of names) await cp(resolve(source, name), resolve(target, name));
}
