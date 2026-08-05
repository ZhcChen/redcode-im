import { requestJson, withQuery } from '@/api/http';
import { E2eeCommandError, type E2eeCommandResult } from '@/e2ee/session';

import { requireToken } from './session';

export interface E2eeDeviceRegistrationMaterial {
  state: Uint8Array;
  keyPackage: Uint8Array;
  rootPublicKey: Uint8Array;
  rootFingerprint: Uint8Array;
  credential: Uint8Array;
  credentialFingerprint: Uint8Array;
  approvalPublicKey: Uint8Array;
}

export interface E2eeRoomEpoch {
  membershipRevision: number;
  activeEpoch: number;
  status: string;
}

export interface E2eeControlMessage {
  id: string;
  epoch: number;
  membershipRevision: number;
  contentType: 'commit' | 'welcome';
  envelope: Uint8Array;
  sequenceNo: number;
}

export interface E2eePeerDevice {
  id: string;
  protocolVersion: number;
  credentialFingerprint: Uint8Array;
}

export interface E2eeDeviceInfo {
  id: string;
  deviceLabel: string;
  protocolVersion: number;
  credentialFingerprint: string;
  status: 'active' | 'pending_approval' | 'revoked';
  approvedByDeviceId: string | null;
  approvedAt: string | null;
  revokedAt: string | null;
  createdAt: string;
}

export interface E2eeRoomMemberDevices {
  userId: string;
  devices: E2eePeerDevice[];
}

export interface E2eeKeyPackageInventory {
  available: number;
  maxAvailable: number;
}

export interface E2eeDeviceApprovalSignature {
  approverDeviceId: string;
  signature: string;
}

export const registrationMaterialFromCommand = (
  result: E2eeCommandResult,
): E2eeDeviceRegistrationMaterial => {
  if (result.fields.length !== 7) throw new E2eeCommandError('E2EE 初始化响应字段数量无效');
  return {
    state: result.field(0),
    keyPackage: result.field(1),
    rootPublicKey: result.field(2),
    rootFingerprint: result.field(3),
    credential: result.field(4),
    credentialFingerprint: result.field(5),
    approvalPublicKey: result.field(6),
  };
};

export const registrationMaterialFromRestoredCommand = (
  result: E2eeCommandResult,
): E2eeDeviceRegistrationMaterial => {
  if (result.fields.length !== 6) throw new E2eeCommandError('E2EE 公开材料响应字段数量无效');
  return {
    state: result.field(0),
    keyPackage: new Uint8Array(),
    rootPublicKey: result.field(1),
    rootFingerprint: result.field(2),
    credential: result.field(3),
    credentialFingerprint: result.field(4),
    approvalPublicKey: result.field(5),
  };
};

export const e2eeMlsApiService = {
  registerDevice(
    deviceId: string,
    deviceLabel: string,
    material: E2eeDeviceRegistrationMaterial,
  ) {
    return requestJson<Record<string, unknown>>('/e2ee/mls/devices', {
      method: 'POST',
      body: JSON.stringify({
        device_id: deviceId,
        device_label: deviceLabel,
        root_public_key: bytesToBase64(material.rootPublicKey),
        root_fingerprint: bytesToBase64(material.rootFingerprint),
        credential: bytesToBase64(material.credential),
        credential_fingerprint: bytesToBase64(material.credentialFingerprint),
        approval_public_key: bytesToBase64(material.approvalPublicKey),
        protocol_version: 1,
      }),
    }, requireToken()).then((response) => ({
      status: String(response.status ?? ''),
    }));
  },

  async publishKeyPackage(
    deviceId: string,
    keyPackage: Uint8Array,
    expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    cryptoProvider: Crypto = globalThis.crypto,
  ) {
    if (!cryptoProvider?.subtle) throw new Error('WebCrypto 不可用');
    const packageRef = new Uint8Array(
      await cryptoProvider.subtle.digest('SHA-256', toArrayBuffer(keyPackage)),
    );
    return requestJson<{ inserted: number }>(`/e2ee/mls/devices/${deviceId}/key-packages`, {
      method: 'POST',
      body: JSON.stringify({
        packages: [{
          id: cryptoProvider.randomUUID(),
          package_ref: bytesToBase64(packageRef),
          key_package: bytesToBase64(keyPackage),
          protocol_version: 1,
          expires_at: expiresAt.toISOString(),
        }],
      }),
    }, requireToken());
  },

  async publishKeyPackages(
    deviceId: string,
    keyPackages: Uint8Array[],
    expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    cryptoProvider: Crypto = globalThis.crypto,
  ) {
    if (!keyPackages.length) throw new Error('E2EE KeyPackage 批次不能为空');
    if (keyPackages.length > 100) throw new Error('E2EE KeyPackage 单批最多 100 个');
    if (!cryptoProvider?.subtle) throw new Error('WebCrypto 不可用');
    const packages = await Promise.all(keyPackages.map(async (keyPackage) => {
      const packageRef = new Uint8Array(
        await cryptoProvider.subtle.digest('SHA-256', toArrayBuffer(keyPackage)),
      );
      return {
        id: cryptoProvider.randomUUID(),
        package_ref: bytesToBase64(packageRef),
        key_package: bytesToBase64(keyPackage),
        protocol_version: 1,
        expires_at: expiresAt.toISOString(),
      };
    }));
    return requestJson<{ inserted: number }>(`/e2ee/mls/devices/${deviceId}/key-packages`, {
      method: 'POST',
      body: JSON.stringify({ packages }),
    }, requireToken());
  },

  async fetchKeyPackageInventory(deviceId: string): Promise<E2eeKeyPackageInventory> {
    const response = await requestJson<Record<string, unknown>>(
      `/e2ee/mls/devices/${deviceId}/key-packages`,
      {},
      requireToken(),
    );
    const available = Number(response.available);
    const maxAvailable = Number(response.max_available);
    if (!Number.isSafeInteger(available) || !Number.isSafeInteger(maxAvailable)) {
      throw new Error('E2EE KeyPackage 库存响应格式无效');
    }
    return { available, maxAvailable };
  },

  async listPeerDevices(userId: string): Promise<E2eePeerDevice[]> {
    const normalized = userId.trim();
    if (!normalized) throw new Error('E2EE 用户标识不能为空');
    const rows = await requestJson<Record<string, unknown>[]>(
      `/e2ee/mls/identities/${encodeURIComponent(normalized)}/devices`,
      {},
      requireToken(),
    );
    return rows.map((row) => {
      const id = typeof row.id === 'string' ? row.id : '';
      const protocolVersion = Number(row.protocol_version);
      const fingerprint = typeof row.credential_fingerprint === 'string'
        ? base64ToBytes(row.credential_fingerprint)
        : new Uint8Array();
      if (!id.trim() || protocolVersion !== 1 || fingerprint.length < 16) {
        throw new Error('E2EE 设备列表响应格式无效');
      }
      return { id, protocolVersion, credentialFingerprint: fingerprint };
    });
  },

  async listRoomMemberDevices(roomId: string): Promise<E2eeRoomMemberDevices[]> {
    const normalized = roomId.trim();
    if (!normalized) throw new Error('E2EE 房间标识不能为空');
    const rows = await requestJson<Record<string, unknown>[]>(
      `/rooms/${encodeURIComponent(normalized)}/e2ee/members`,
      {},
      requireToken(),
    );
    return rows.map((row) => {
      const userId = typeof row.user_id === 'string' ? row.user_id : '';
      const devices = Array.isArray(row.devices)
        ? row.devices.map((device) => {
            const record = device as Record<string, unknown>;
            const id = typeof record.id === 'string' ? record.id : '';
            const protocolVersion = Number(record.protocol_version);
            const fingerprint = typeof record.credential_fingerprint === 'string'
              ? base64ToBytes(record.credential_fingerprint)
              : new Uint8Array();
            if (!id.trim() || protocolVersion !== 1 || fingerprint.length < 16) {
              throw new Error('E2EE 房间成员设备响应格式无效');
            }
            return { id, protocolVersion, credentialFingerprint: fingerprint };
          })
        : [];
      if (!userId.trim()) throw new Error('E2EE 房间成员响应格式无效');
      return { userId, devices };
    });
  },

  async listDevices(): Promise<E2eeDeviceInfo[]> {
    const rows = await requestJson<Record<string, unknown>[]>(
      '/e2ee/mls/devices',
      {},
      requireToken(),
    );
    return rows.map((row) => mapDeviceInfo(row));
  },

  async approveDevice(
    targetDeviceId: string,
    input: E2eeDeviceApprovalSignature,
  ): Promise<E2eeDeviceInfo> {
    const response = await requestJson<Record<string, unknown>>(
      `/e2ee/mls/devices/${encodeURIComponent(targetDeviceId)}/approve`,
      {
        method: 'POST',
        body: JSON.stringify({
          approver_device_id: input.approverDeviceId,
          signature: input.signature,
        }),
      },
      requireToken(),
    );
    return mapDeviceInfo(response);
  },

  async revokeDevice(deviceId: string): Promise<E2eeDeviceInfo> {
    const response = await requestJson<Record<string, unknown>>(
      `/e2ee/mls/devices/${encodeURIComponent(deviceId)}`,
      { method: 'DELETE' },
      requireToken(),
    );
    return mapDeviceInfo(response);
  },

  async claimKeyPackage(roomId: string, consumerDeviceId: string, targetDeviceId: string) {
    const response = await requestJson<Record<string, unknown>>(
      `/e2ee/mls/devices/${targetDeviceId}/key-packages/claim`,
      {
        method: 'POST',
        body: JSON.stringify({ room_id: roomId, consumer_device_id: consumerDeviceId }),
      },
      requireToken(),
    );
    return {
      id: String(response.id),
      deviceId: String(response.device_id),
      keyPackage: base64ToBytes(String(response.key_package)),
    };
  },

  async getRoomEpoch(roomId: string): Promise<E2eeRoomEpoch> {
    const response = await requestJson<Record<string, unknown>>(
      `/rooms/${roomId}/e2ee/epoch`,
      {},
      requireToken(),
    );
    return {
      membershipRevision: Number(response.membership_revision),
      activeEpoch: Number(response.active_epoch),
      status: String(response.status),
    };
  },

  submitControlMessage(input: {
    roomId: string;
    messageId: string;
    epoch: number;
    membershipRevision: number;
    senderDeviceId: string;
    contentType: 'commit' | 'welcome';
    envelope: Uint8Array;
    recipientDeviceId?: string;
    idempotencyKey?: string;
  }) {
    return requestJson<Record<string, unknown>>(`/rooms/${input.roomId}/e2ee/control-messages`, {
      method: 'POST',
      body: JSON.stringify({
        id: input.messageId,
        epoch: input.epoch,
        membership_revision: input.membershipRevision,
        sender_device_id: input.senderDeviceId,
        recipient_device_id: input.recipientDeviceId ?? null,
        content_type: input.contentType,
        envelope: bytesToBase64(input.envelope),
        idempotency_key: input.idempotencyKey ?? input.messageId,
      }),
    }, requireToken());
  },

  async listControlMessages(
    roomId: string,
    deviceId: string,
    afterSequence = 0,
    limit = 50,
  ): Promise<E2eeControlMessage[]> {
    const rows = await requestJson<Record<string, unknown>[]>(withQuery(
      `/rooms/${roomId}/e2ee/control-messages`,
      { device_id: deviceId, after_sequence: afterSequence, limit },
    ), {}, requireToken());
    return rows.map((row) => ({
      id: String(row.id),
      epoch: Number(row.epoch),
      membershipRevision: Number(row.membership_revision),
      contentType: String(row.content_type) as 'commit' | 'welcome',
      envelope: base64ToBytes(String(row.envelope)),
      sequenceNo: Number(row.sequence_no),
    }));
  },

  async consumeControlMessage(roomId: string, messageId: string, deviceId: string) {
    await requestJson(`/rooms/${roomId}/e2ee/control-messages/${messageId}/consume`, {
      method: 'POST',
      body: JSON.stringify({ device_id: deviceId }),
    }, requireToken());
  },

  sendEncryptedMessage(input: {
    roomId: string;
    senderDeviceId: string;
    epoch: number;
    ciphertext: Uint8Array;
    idempotencyKey: string;
    controlMessageId?: string;
  }) {
    return requestJson<Record<string, unknown>>(`/rooms/${input.roomId}/messages/encrypted`, {
      method: 'POST',
      body: JSON.stringify({
        encrypted_content: bytesToBase64(input.ciphertext),
        encryption_metadata: {
          protocol: 'mls',
          version: 1,
          epoch: input.epoch,
          sender_device_id: input.senderDeviceId,
          content_type: 'application',
          control_message_id: input.controlMessageId ?? null,
        },
        idempotency_key: input.idempotencyKey,
      }),
    }, requireToken());
  },
};

const mapDeviceInfo = (row: Record<string, unknown>): E2eeDeviceInfo => {
  const id = typeof row.id === 'string' ? row.id : '';
  const status = String(row.status ?? '');
  if (!id.trim() || !['active', 'pending_approval', 'revoked'].includes(status)) {
    throw new Error('E2EE 设备响应格式无效');
  }
  return {
    id,
    deviceLabel: String(row.device_label ?? ''),
    protocolVersion: Number(row.protocol_version),
    credentialFingerprint: String(row.credential_fingerprint ?? ''),
    status: status as E2eeDeviceInfo['status'],
    approvedByDeviceId: row.approved_by_device_id == null ? null : String(row.approved_by_device_id),
    approvedAt: row.approved_at == null ? null : String(row.approved_at),
    revokedAt: row.revoked_at == null ? null : String(row.revoked_at),
    createdAt: String(row.created_at ?? ''),
  };
};

const bytesToBase64 = (value: Uint8Array) => {
  let binary = '';
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary);
};

const base64ToBytes = (value: string) => Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
const toArrayBuffer = (value: Uint8Array) => value.buffer.slice(
  value.byteOffset,
  value.byteOffset + value.byteLength,
) as ArrayBuffer;
