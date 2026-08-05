import type { E2eeDeviceProfile } from '@/e2ee/device-profile';
import { e2eeSecureStateStorage } from '@/e2ee/secure-state-storage';
import { e2eeSession, type E2eeCommandResult } from '@/e2ee/session';
import {
  e2eeMlsApiService,
  type E2eeDeviceInfo,
} from '@/services/e2ee-mls-api-service';

const DEVICE_APPROVAL_DOMAIN = 'redcode-im/e2ee/device-approval/v1\0';
const MLS_PROTOCOL_VERSION = 1;

interface DeviceStorage {
  read(accountId: string): Promise<Uint8Array | null>;
  readDeviceProfile(accountId: string): Promise<E2eeDeviceProfile | null>;
}

interface SessionCore {
  signDeviceApproval(state: Uint8Array, payload: Uint8Array): Promise<E2eeCommandResult>;
}

interface DeviceApi {
  listDevices(): Promise<E2eeDeviceInfo[]>;
  approveDevice(
    targetDeviceId: string,
    input: { approverDeviceId: string; signature: string },
  ): Promise<E2eeDeviceInfo>;
  revokeDevice(deviceId: string): Promise<E2eeDeviceInfo>;
}

export class E2eeDeviceManager {
  constructor(
    private readonly storage: DeviceStorage = e2eeSecureStateStorage,
    private readonly core: SessionCore = e2eeSession,
    private readonly api: DeviceApi = e2eeMlsApiService,
  ) {}

  listDevices(): Promise<E2eeDeviceInfo[]> {
    return this.api.listDevices();
  }

  revokeDevice(deviceId: string): Promise<E2eeDeviceInfo> {
    return this.api.revokeDevice(deviceId);
  }

  async approveDevice(accountId: string, targetDevice: E2eeDeviceInfo): Promise<E2eeDeviceInfo> {
    const profile = await this.requiredProfile(accountId);
    if (profile.deviceStatus === 'pending_approval') {
      throw new Error('待批准设备不能批准其他设备');
    }
    const state = await this.storage.read(accountId);
    if (!state) throw new Error('E2EE 设备状态缺失');
    const payload = deviceApprovalPayload(
      accountId,
      profile.deviceId,
      targetDevice.id,
      MLS_PROTOCOL_VERSION,
      base64ToBytes(targetDevice.credentialFingerprint),
    );
    const signature = await this.core.signDeviceApproval(state, payload);
    return this.api.approveDevice(targetDevice.id, {
      approverDeviceId: profile.deviceId,
      signature: bytesToBase64(signature.field(0)),
    });
  }

  private async requiredProfile(accountId: string) {
    const profile = await this.storage.readDeviceProfile(accountId);
    if (!profile) throw new Error('E2EE 设备档案缺失');
    return profile;
  }
}

export const e2eeDeviceManager = new E2eeDeviceManager();

export const deviceApprovalPayload = (
  userId: string,
  approverDeviceId: string,
  targetDeviceId: string,
  protocolVersion: number,
  credentialFingerprint: Uint8Array,
) => concat(
  new TextEncoder().encode(DEVICE_APPROVAL_DOMAIN),
  uuidBytes(userId),
  uuidBytes(approverDeviceId),
  uuidBytes(targetDeviceId),
  uint16(protocolVersion),
  uint16(credentialFingerprint.length),
  credentialFingerprint,
);

const uuidBytes = (value: string) => {
  const hex = value.replace(/-/g, '').toLowerCase();
  if (!/^[0-9a-f]{32}$/.test(hex)) throw new Error('E2EE UUID 格式无效');
  const bytes = new Uint8Array(16);
  for (let index = 0; index < 16; index += 1) {
    bytes[index] = Number.parseInt(hex.slice(index * 2, index * 2 + 2), 16);
  }
  return bytes;
};

const uint16 = (value: number) => new Uint8Array([(value >> 8) & 0xff, value & 0xff]);

const concat = (...parts: Uint8Array[]) => {
  const output = new Uint8Array(parts.reduce((total, part) => total + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
};

const bytesToBase64 = (value: Uint8Array) => btoa(String.fromCharCode(...value));
const base64ToBytes = (value: string) => Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
