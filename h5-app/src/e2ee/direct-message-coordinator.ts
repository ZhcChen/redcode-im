import type { E2eeDeviceProfile } from '@/e2ee/device-profile';
import { e2eeDeviceLifecycle } from '@/e2ee/device-lifecycle';
import {
  E2eeIdentityTrustManager,
  type E2eeIdentityTrustStore,
  type E2eeRootIdentity,
} from '@/e2ee/identity-trust';
import type { E2eePendingOperation } from '@/e2ee/pending-operation';
import { e2eeSecureStateStorage } from '@/e2ee/secure-state-storage';
import { e2eeSession, type E2eeCommandResult } from '@/e2ee/session';
import { e2eeIdentityService } from '@/services/e2ee-identity-service';
import {
  e2eeMlsApiService,
  type E2eePeerDevice,
  type E2eeRoomEpoch,
} from '@/services/e2ee-mls-api-service';

interface CoordinatorStorage extends E2eeIdentityTrustStore {
  read(accountId: string): Promise<Uint8Array | null>;
  write(accountId: string, state: Uint8Array): Promise<void>;
  readDeviceProfile(accountId: string): Promise<E2eeDeviceProfile | null>;
  writeDeviceProfile(accountId: string, profile: E2eeDeviceProfile): Promise<void>;
  readPendingOperation(accountId: string): Promise<E2eePendingOperation | null>;
  writePendingOperation(accountId: string, operation: E2eePendingOperation): Promise<void>;
  deletePendingOperation(accountId: string): Promise<void>;
}

interface DeviceLifecycle {
  ensureReady(accountId: string, deviceLabel: string): Promise<unknown>;
}

interface IdentityApi {
  fetchRootIdentity(userId: string): Promise<E2eeRootIdentity>;
}

interface SessionCore {
  createGroup(state: Uint8Array, roomId: string): Promise<E2eeCommandResult>;
  addMember(state: Uint8Array, roomId: string, keyPackage: Uint8Array): Promise<E2eeCommandResult>;
  encrypt(state: Uint8Array, roomId: string, plaintext: Uint8Array): Promise<E2eeCommandResult>;
}

interface MlsApi {
  getRoomEpoch(roomId: string): Promise<E2eeRoomEpoch>;
  listPeerDevices(userId: string): Promise<E2eePeerDevice[]>;
  claimKeyPackage(roomId: string, consumerDeviceId: string, targetDeviceId: string): Promise<{ keyPackage: Uint8Array }>;
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
  }): Promise<unknown>;
  sendEncryptedMessage(input: {
    roomId: string;
    senderDeviceId: string;
    epoch: number;
    ciphertext: Uint8Array;
    idempotencyKey: string;
    controlMessageId?: string;
  }): Promise<Record<string, unknown>>;
}

export class E2eeDirectMessageError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'E2eeDirectMessageError';
  }
}

export class E2eeDirectMessageCoordinator {
  private tail: Promise<void> = Promise.resolve();
  private readonly trust: E2eeIdentityTrustManager;

  constructor(
    private readonly storage: CoordinatorStorage = e2eeSecureStateStorage,
    private readonly lifecycle: DeviceLifecycle = e2eeDeviceLifecycle,
    private readonly identityApi: IdentityApi = e2eeIdentityService,
    private readonly api: MlsApi = e2eeMlsApiService,
    private readonly core: SessionCore = e2eeSession,
    private readonly newId: () => string = () => crypto.randomUUID(),
  ) {
    this.trust = new E2eeIdentityTrustManager(storage);
  }

  sendText(input: {
    accountId: string;
    deviceLabel: string;
    roomId: string;
    peerUserId: string;
    text: string;
  }): Promise<Record<string, unknown>> {
    return this.exclusive(async () => {
      const text = input.text.trim();
      if (!text) throw new E2eeDirectMessageError('加密消息内容不能为空');
      await this.resumePending(input.accountId);
      await this.lifecycle.ensureReady(input.accountId, input.deviceLabel);
      let context = await this.storedContext(input.accountId);
      const identity = await this.identityApi.fetchRootIdentity(input.peerUserId);
      await this.trust.observe(input.accountId, identity);
      await this.trust.requireTrusted(input.accountId, input.peerUserId);

      let epoch = await this.api.getRoomEpoch(input.roomId);
      if (epoch.activeEpoch === 0) {
        await this.bootstrapRoom({
          accountId: input.accountId,
          roomId: input.roomId,
          peerUserId: input.peerUserId,
          profile: context.profile,
          state: context.state,
          membershipRevision: epoch.membershipRevision,
        });
        context = await this.storedContext(input.accountId);
        epoch = await this.api.getRoomEpoch(input.roomId);
      }
      if (epoch.status !== 'active') throw new E2eeDirectMessageError('房间 E2EE 状态尚未就绪');
      const controlMessageId = context.profile.lastCommitMessageIds[input.roomId];
      if (!controlMessageId) throw new E2eeDirectMessageError('房间缺少当前 E2EE Commit 索引');

      const plaintext = new TextEncoder().encode(JSON.stringify({ version: 1, type: 'text', text }));
      const encrypted = await this.core.encrypt(context.state, input.roomId, plaintext);
      const encryptedEpoch = safeEpoch(encrypted, 2);
      if (encryptedEpoch !== epoch.activeEpoch) throw new E2eeDirectMessageError('本地 E2EE epoch 已过期');
      await this.storage.writePendingOperation(input.accountId, {
        kind: 'application',
        roomId: input.roomId,
        nextState: encrypted.field(0),
        senderDeviceId: context.profile.deviceId,
        idempotencyKey: this.newId(),
        controls: [],
        ciphertext: encrypted.field(1),
        epoch: encryptedEpoch,
        controlMessageId,
      });
      return (await this.resumePending(input.accountId))!;
    });
  }

  private async bootstrapRoom(input: {
    accountId: string;
    roomId: string;
    peerUserId: string;
    profile: E2eeDeviceProfile;
    state: Uint8Array;
    membershipRevision: number;
  }) {
    const devices = await this.api.listPeerDevices(input.peerUserId);
    if (!devices.length) throw new E2eeDirectMessageError('联系人没有可用的 E2EE 设备');
    let state = (await this.core.createGroup(input.state, input.roomId)).field(0);
    const controls: E2eePendingOperation['controls'] = [];
    for (const device of devices) {
      const claimed = await this.api.claimKeyPackage(input.roomId, input.profile.deviceId, device.id);
      const added = await this.core.addMember(state, input.roomId, claimed.keyPackage);
      state = added.field(0);
      const epoch = safeEpoch(added, 3);
      controls.push({
        id: this.newId(),
        epoch,
        membershipRevision: input.membershipRevision,
        contentType: 'commit',
        envelope: added.field(1),
      }, {
        id: this.newId(),
        epoch,
        membershipRevision: input.membershipRevision,
        contentType: 'welcome',
        envelope: added.field(2),
        recipientDeviceId: device.id,
      });
    }
    await this.storage.writePendingOperation(input.accountId, {
      kind: 'bootstrap',
      roomId: input.roomId,
      nextState: state,
      senderDeviceId: input.profile.deviceId,
      idempotencyKey: this.newId(),
      controls,
    });
    await this.resumePending(input.accountId);
  }

  private async resumePending(accountId: string): Promise<Record<string, unknown> | null> {
    const operation = await this.storage.readPendingOperation(accountId);
    if (!operation) return null;
    if (operation.kind === 'bootstrap') {
      for (const control of operation.controls) {
        await this.api.submitControlMessage({
          roomId: operation.roomId,
          messageId: control.id,
          epoch: control.epoch,
          membershipRevision: control.membershipRevision,
          senderDeviceId: operation.senderDeviceId,
          contentType: control.contentType,
          envelope: control.envelope,
          recipientDeviceId: control.recipientDeviceId,
          idempotencyKey: control.id,
        });
      }
      const profile = await this.requiredProfile(accountId);
      const lastCommitId = operation.controls.filter((item) => item.contentType === 'commit').at(-1)!.id;
      await this.storage.write(accountId, operation.nextState);
      await this.storage.writeDeviceProfile(accountId, {
        ...profile,
        lastCommitMessageIds: { ...profile.lastCommitMessageIds, [operation.roomId]: lastCommitId },
      });
      await this.storage.deletePendingOperation(accountId);
      return null;
    }
    const response = await this.api.sendEncryptedMessage({
      roomId: operation.roomId,
      senderDeviceId: operation.senderDeviceId,
      epoch: operation.epoch!,
      ciphertext: operation.ciphertext!,
      idempotencyKey: operation.idempotencyKey,
      controlMessageId: operation.controlMessageId,
    });
    await this.storage.write(accountId, operation.nextState);
    await this.storage.deletePendingOperation(accountId);
    return response;
  }

  private async requiredProfile(accountId: string) {
    const profile = await this.storage.readDeviceProfile(accountId);
    if (!profile) throw new E2eeDirectMessageError('E2EE 设备档案缺失');
    return profile;
  }

  private async storedContext(accountId: string) {
    const profile = await this.requiredProfile(accountId);
    const state = await this.storage.read(accountId);
    if (!state) throw new E2eeDirectMessageError('E2EE 协议状态缺失');
    return { profile, state };
  }

  private exclusive<T>(action: () => Promise<T>): Promise<T> {
    const result = this.tail.then(action, action);
    this.tail = result.then(() => undefined, () => undefined);
    return result;
  }
}

const safeEpoch = (result: E2eeCommandResult, index: number) => {
  const epoch = result.epoch(index);
  if (epoch > BigInt(Number.MAX_SAFE_INTEGER)) throw new E2eeDirectMessageError('E2EE epoch 超出安全范围');
  return Number(epoch);
};

export const e2eeDirectMessageCoordinator = new E2eeDirectMessageCoordinator();
