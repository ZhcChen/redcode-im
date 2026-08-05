const PROFILE_VERSION = 1;

export interface E2eeDeviceProfile {
  deviceId: string;
  deviceLabel: string;
  registered: boolean;
  keyPackagePublished: boolean;
  deviceStatus?: 'active' | 'pending_approval';
  lastControlSequences: Record<string, number>;
  lastCommitMessageIds: Record<string, string>;
}

export const encodeDeviceProfile = (profile: E2eeDeviceProfile) => new TextEncoder().encode(JSON.stringify({
  version: PROFILE_VERSION,
  device_id: profile.deviceId,
  device_label: profile.deviceLabel,
  registered: profile.registered,
  key_package_published: profile.keyPackagePublished,
  device_status: profile.deviceStatus ?? 'active',
  last_control_sequences: profile.lastControlSequences,
  last_commit_message_ids: profile.lastCommitMessageIds,
}));

export const decodeDeviceProfile = (value: Uint8Array): E2eeDeviceProfile => {
  const data = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(value)) as Record<string, unknown>;
  if (data.version !== PROFILE_VERSION
    || typeof data.device_id !== 'string'
    || !data.device_id.trim()
    || typeof data.device_label !== 'string'
    || typeof data.registered !== 'boolean'
    || typeof data.key_package_published !== 'boolean'
    || (data.device_status != null && data.device_status !== 'active' && data.device_status !== 'pending_approval')
    || !isRecord(data.last_control_sequences)
    || (data.last_commit_message_ids != null && !isRecord(data.last_commit_message_ids))) {
    throw new Error('E2EE 设备档案格式无效');
  }
  const sequences = Object.fromEntries(Object.entries(data.last_control_sequences).map(([key, item]) => {
    if (!Number.isSafeInteger(item) || Number(item) < 0) throw new Error('E2EE 控制消息游标无效');
    return [key, Number(item)];
  }));
  const commitIds = Object.fromEntries(Object.entries(
    isRecord(data.last_commit_message_ids) ? data.last_commit_message_ids : {},
  ).map(([key, item]) => {
    if (!key.trim() || typeof item !== 'string' || !item.trim()) throw new Error('E2EE Commit 索引无效');
    return [key, item];
  }));
  return {
    deviceId: data.device_id,
    deviceLabel: data.device_label,
    registered: data.registered,
    keyPackagePublished: data.key_package_published,
    deviceStatus: data.device_status === 'pending_approval' ? 'pending_approval' : 'active',
    lastControlSequences: sequences,
    lastCommitMessageIds: commitIds,
  };
};

const isRecord = (value: unknown): value is Record<string, unknown> => (
  Boolean(value && typeof value === 'object' && !Array.isArray(value))
);
