const PROFILE_VERSION = 1;

export interface E2eeDeviceProfile {
  deviceId: string;
  deviceLabel: string;
  registered: boolean;
  keyPackagePublished: boolean;
  lastControlSequences: Record<string, number>;
}

export const encodeDeviceProfile = (profile: E2eeDeviceProfile) => new TextEncoder().encode(JSON.stringify({
  version: PROFILE_VERSION,
  device_id: profile.deviceId,
  device_label: profile.deviceLabel,
  registered: profile.registered,
  key_package_published: profile.keyPackagePublished,
  last_control_sequences: profile.lastControlSequences,
}));

export const decodeDeviceProfile = (value: Uint8Array): E2eeDeviceProfile => {
  const data = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(value)) as Record<string, unknown>;
  if (data.version !== PROFILE_VERSION
    || typeof data.device_id !== 'string'
    || !data.device_id.trim()
    || typeof data.device_label !== 'string'
    || typeof data.registered !== 'boolean'
    || typeof data.key_package_published !== 'boolean'
    || !isRecord(data.last_control_sequences)) {
    throw new Error('E2EE 设备档案格式无效');
  }
  const sequences = Object.fromEntries(Object.entries(data.last_control_sequences).map(([key, item]) => {
    if (!Number.isSafeInteger(item) || Number(item) < 0) throw new Error('E2EE 控制消息游标无效');
    return [key, Number(item)];
  }));
  return {
    deviceId: data.device_id,
    deviceLabel: data.device_label,
    registered: data.registered,
    keyPackagePublished: data.key_package_published,
    lastControlSequences: sequences,
  };
};

const isRecord = (value: unknown): value is Record<string, unknown> => (
  Boolean(value && typeof value === 'object' && !Array.isArray(value))
);
