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
  type E2eeControlMessage,
  type E2eeRoomEpoch,
  type E2eeRoomMemberDevices,
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
  decrypt(state: Uint8Array, roomId: string, ciphertext: Uint8Array): Promise<E2eeCommandResult>;
  joinGroup(state: Uint8Array, welcome: Uint8Array): Promise<E2eeCommandResult>;
  processCommit(state: Uint8Array, roomId: string, commit: Uint8Array): Promise<E2eeCommandResult>;
  removeMember(state: Uint8Array, roomId: string, identity: string): Promise<E2eeCommandResult>;
  listMembers(state: Uint8Array, roomId: string): Promise<E2eeCommandResult>;
}

interface MlsApi {
  getRoomEpoch(roomId: string): Promise<E2eeRoomEpoch>;
  listRoomMemberDevices(roomId: string): Promise<E2eeRoomMemberDevices[]>;
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
  listControlMessages(roomId: string, deviceId: string, afterSequence?: number, limit?: number): Promise<E2eeControlMessage[]>;
  consumeControlMessage(roomId: string, messageId: string, deviceId: string): Promise<void>;
}

export class E2eeDirectMessageError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'E2eeDirectMessageError';
  }
}

export interface E2eeDecryptedText {
  text: string;
  epoch: number;
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
    peerUserId?: string;
    text: string;
  }): Promise<Record<string, unknown>> {
    return this.exclusive(async () => {
      await this.prepare(input);
      return (await this.resumePending(input.accountId, true))!;
    });
  }

  prepareText(input: {
    accountId: string;
    deviceLabel: string;
    roomId: string;
    peerUserId?: string;
    text: string;
  }): Promise<void> {
    return this.exclusive(() => this.prepare(input));
  }

  private async prepare(input: {
    accountId: string;
    deviceLabel: string;
    roomId: string;
    peerUserId?: string;
    text: string;
  }): Promise<void> {
    const text = input.text.trim();
    if (!text) throw new E2eeDirectMessageError('加密消息内容不能为空');
    await this.syncControls(input.accountId, input.deviceLabel, input.roomId);
    let context = await this.storedContext(input.accountId);
    const memberDevices = await this.api.listRoomMemberDevices(input.roomId);
    const memberUserIds = memberDevices
      .map((member) => member.userId)
      .filter((userId) => userId !== input.accountId);
    for (const userId of memberUserIds) {
      const identity = await this.identityApi.fetchRootIdentity(userId);
      await this.trust.observe(input.accountId, identity);
      await this.trust.requireTrusted(input.accountId, userId);
    }

    let epoch = await this.api.getRoomEpoch(input.roomId);
    if (epoch.activeEpoch === 0) {
      await this.bootstrapRoom({
        accountId: input.accountId,
        roomId: input.roomId,
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
  }

  syncControlMessages(input: {
    accountId: string;
    deviceLabel: string;
    roomId: string;
  }): Promise<void> {
    return this.exclusive(() => this.syncControls(input.accountId, input.deviceLabel, input.roomId));
  }

  retryPendingSend(accountId: string): Promise<Record<string, unknown>> {
    return this.exclusive(async () => {
      const response = await this.resumePending(accountId, true);
      if (!response) throw new E2eeDirectMessageError('没有待重试的 E2EE 消息');
      return response;
    });
  }

  decryptText(input: {
    accountId: string;
    deviceLabel: string;
    roomId: string;
    ciphertext: Uint8Array;
  }): Promise<E2eeDecryptedText> {
    return this.exclusive(async () => {
      if (!input.ciphertext.length) throw new E2eeDirectMessageError('E2EE 密文不能为空');
      await this.syncControls(input.accountId, input.deviceLabel, input.roomId);
      const context = await this.storedContext(input.accountId);
      const decrypted = await this.core.decrypt(context.state, input.roomId, input.ciphertext);
      const text = decodeTextPayload(decrypted.field(1));
      await this.storage.write(input.accountId, decrypted.field(0));
      return { text, epoch: safeEpoch(decrypted, 2) };
    });
  }

  private async syncControls(accountId: string, deviceLabel: string, roomId: string) {
    await this.resumePending(accountId);
    await this.lifecycle.ensureReady(accountId, deviceLabel);
    await this.reconcileGroup(accountId, roomId);
    while (true) {
      const context = await this.storedContext(accountId);
      const messages = await this.api.listControlMessages(
        roomId,
        context.profile.deviceId,
        context.profile.lastControlSequences[roomId] ?? 0,
        100,
      );
      if (!messages.length) return;
      const nextState = await this.applyControlBatch(context, roomId, messages);
      if (!nextState) return;
      await this.storage.writePendingOperation(accountId, {
        kind: 'inbound',
        roomId,
        nextState,
        senderDeviceId: context.profile.deviceId,
        idempotencyKey: messages.at(-1)!.id,
        controls: messages.map((message) => ({
          id: message.id,
          epoch: message.epoch,
          membershipRevision: message.membershipRevision,
          contentType: message.contentType,
          envelope: message.envelope,
          sequenceNo: message.sequenceNo,
        })),
      });
      await this.resumePending(accountId);
      if (messages.length < 100) return;
    }
  }

  /**
   * 房间进入 rekey_required 时，把本地 group leaf 集合与服务端房间成员设备集合
   * 做差集收敛：被移除/撤销设备 remove，新设备/新成员 add（commit + welcome）。
   * 提交冲突时恢复旧状态并通过控制消息重新收敛。
   */
  private async reconcileGroup(accountId: string, roomId: string) {
    const epoch = await this.api.getRoomEpoch(roomId);
    if (!epoch || epoch.status !== 'rekey_required') return;
    const context = await this.storedContext(accountId);
    const joined = Boolean(context.profile.lastCommitMessageIds[roomId]);
    if (!joined) return; // 尚未加入房间 group，控制消息同步完成 join 后再收敛
    const memberDevices = await this.api.listRoomMemberDevices(roomId);
    const serverSet = new Set<string>();
    for (const member of memberDevices) {
      for (const device of member.devices) serverSet.add(`${member.userId}/${device.id}`);
    }
    let localMembers: string[];
    try {
      localMembers = this.decodeMembers((await this.core.listMembers(context.state, roomId)).field(0));
    } catch {
      throw new E2eeDirectMessageError('房间 E2EE group 状态缺失，无法收敛成员变化');
    }
    const localSet = new Set(localMembers);
    const toRemove = localMembers.filter((identity) => !serverSet.has(identity));
    const toAdd = [...serverSet].filter((identity) => !localSet.has(identity));
    if (!toRemove.length && !toAdd.length) return;

    let state = context.state;
    const controls: E2eePendingOperation['controls'] = [];
    for (const identity of toRemove) {
      let removed: E2eeCommandResult;
      try {
        removed = await this.core.removeMember(state, roomId, identity);
      } catch (error) {
        // 服务端状态与本地 group 短暂不一致时没有 leaf 可移除，跳过并继续收敛。
        if (error instanceof Error && /member not found/i.test(error.message)) continue;
        throw error;
      }
      state = removed.field(0);
      controls.push({
        id: this.newId(),
        epoch: safeEpoch(removed, 2),
        membershipRevision: epoch.membershipRevision,
        contentType: 'commit',
        envelope: removed.field(1),
      });
    }
    for (const identity of toAdd) {
      const deviceId = identity.slice(identity.indexOf('/') + 1);
      const claimed = await this.api.claimKeyPackage(roomId, context.profile.deviceId, deviceId);
      const added = await this.core.addMember(state, roomId, claimed.keyPackage);
      state = added.field(0);
      const addedEpoch = safeEpoch(added, 3);
      controls.push({
        id: this.newId(),
        epoch: addedEpoch,
        membershipRevision: epoch.membershipRevision,
        contentType: 'commit',
        envelope: added.field(1),
      }, {
        id: this.newId(),
        epoch: addedEpoch,
        membershipRevision: epoch.membershipRevision,
        contentType: 'welcome',
        envelope: added.field(2),
        recipientDeviceId: deviceId,
      });
    }
    if (!controls.length) return;
    await this.storage.writePendingOperation(accountId, {
      kind: 'rekey',
      roomId,
      nextState: state,
      senderDeviceId: context.profile.deviceId,
      idempotencyKey: this.newId(),
      controls,
      previousState: context.state,
    });
    await this.resumePending(accountId);
  }

  private async bootstrapRoom(input: {
    accountId: string;
    roomId: string;
    profile: E2eeDeviceProfile;
    state: Uint8Array;
    membershipRevision: number;
  }) {
    const memberDevices = await this.api.listRoomMemberDevices(input.roomId);
    const missing = memberDevices.filter(
      (member) => member.userId !== input.accountId && !member.devices.length,
    );
    if (missing.length) {
      throw new E2eeDirectMessageError('房间存在没有可用 E2EE 设备的成员');
    }
    const devices = memberDevices
      .filter((member) => member.userId !== input.accountId)
      .flatMap((member) => member.devices);
    if (!devices.length) throw new E2eeDirectMessageError('房间没有其他可用的 E2EE 设备');
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

  private async resumePending(
    accountId: string,
    allowApplication = false,
  ): Promise<Record<string, unknown> | null> {
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
    if (operation.kind === 'rekey') {
      const profile = await this.requiredProfile(accountId);
      const targetEpoch = operation.controls.at(-1)!.epoch;
      try {
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
      } catch (error) {
        // 其他可信设备可能已提交同一 rekey；恢复旧状态并通过控制消息收敛，
        // 避免本地保留未同步的随机 epoch 状态。
        const latest = await this.api.getRoomEpoch(operation.roomId);
        if (latest && latest.activeEpoch >= targetEpoch) {
          await this.storage.write(accountId, operation.previousState!);
          await this.storage.deletePendingOperation(accountId);
          await this.syncControls(accountId, profile.deviceLabel, operation.roomId);
          return null;
        }
        throw error;
      }
      await this.storage.write(accountId, operation.nextState);
      const lastCommitId = operation.controls.filter((item) => item.contentType === 'commit').at(-1)!.id;
      await this.storage.writeDeviceProfile(accountId, {
        ...profile,
        lastCommitMessageIds: {
          ...profile.lastCommitMessageIds,
          [operation.roomId]: lastCommitId,
        },
      });
      await this.storage.deletePendingOperation(accountId);
      return null;
    }
    if (operation.kind === 'inbound') {
      const profile = await this.requiredProfile(accountId);
      const lastCommit = operation.controls.filter((item) => item.contentType === 'commit').at(-1);
      await this.storage.write(accountId, operation.nextState);
      await this.storage.writeDeviceProfile(accountId, {
        ...profile,
        lastControlSequences: {
          ...profile.lastControlSequences,
          [operation.roomId]: operation.controls.at(-1)!.sequenceNo!,
        },
        lastCommitMessageIds: lastCommit
          ? { ...profile.lastCommitMessageIds, [operation.roomId]: lastCommit.id }
          : profile.lastCommitMessageIds,
      });
      for (const control of operation.controls) {
        await this.api.consumeControlMessage(operation.roomId, control.id, operation.senderDeviceId);
      }
      await this.storage.deletePendingOperation(accountId);
      return null;
    }
    if (!allowApplication) throw new E2eeDirectMessageError('存在待手动重试的 E2EE 消息');
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

  private async applyControlBatch(
    context: { profile: E2eeDeviceProfile; state: Uint8Array },
    roomId: string,
    messages: E2eeControlMessage[],
  ): Promise<Uint8Array | null> {
    let state = context.state;
    let joined = Boolean(context.profile.lastCommitMessageIds[roomId]);
    let startIndex = 0;
    if (!joined) {
      const welcomeIndex = messages.findIndex((message) => message.contentType === 'welcome');
      if (welcomeIndex < 0) return null;
      const welcome = messages[welcomeIndex]!;
      const matchingCommit = messages.slice(0, welcomeIndex + 1)
        .filter((message) => message.contentType === 'commit' && message.epoch === welcome.epoch)
        .at(-1);
      if (!matchingCommit) throw new E2eeDirectMessageError('Welcome 缺少对应的 E2EE Commit');
      const result = await this.core.joinGroup(state, welcome.envelope);
      if (safeEpoch(result, 1) !== welcome.epoch) {
        throw new E2eeDirectMessageError('Welcome epoch 与本地状态不一致');
      }
      state = result.field(0);
      joined = true;
      startIndex = welcomeIndex + 1;
    }
    if (!joined) return null;
    for (const message of messages.slice(startIndex)) {
      if (message.contentType !== 'commit') {
        throw new E2eeDirectMessageError('已入群设备收到意外 Welcome');
      }
      const result = await this.core.processCommit(state, roomId, message.envelope);
      if (safeEpoch(result, 1) !== message.epoch) {
        throw new E2eeDirectMessageError('Commit epoch 与本地状态不一致');
      }
      state = result.field(0);
    }
    return state;
  }

  private decodeMembers(field: Uint8Array): string[] {
    if (field.length < 4) throw new E2eeDirectMessageError('E2EE 成员列表格式无效');
    const view = new DataView(field.buffer, field.byteOffset, field.byteLength);
    let offset = 0;
    const count = view.getUint32(offset, false);
    offset += 4;
    const members: string[] = [];
    for (let index = 0; index < count; index += 1) {
      if (offset + 4 > field.length) throw new E2eeDirectMessageError('E2EE 成员列表已截断');
      const length = view.getUint32(offset, false);
      offset += 4;
      if (offset + length > field.length) throw new E2eeDirectMessageError('E2EE 成员列表已截断');
      members.push(new TextDecoder().decode(field.subarray(offset, offset + length)));
      offset += length;
    }
    if (offset !== field.length) throw new E2eeDirectMessageError('E2EE 成员列表包含多余数据');
    return members;
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

const decodeTextPayload = (plaintext: Uint8Array) => {
  try {
    const payload = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(plaintext)) as Record<string, unknown>;
    if (payload.version !== 1 || payload.type !== 'text' || typeof payload.text !== 'string' || !payload.text.trim()) {
      throw new Error('invalid payload');
    }
    return payload.text;
  } catch {
    throw new E2eeDirectMessageError('E2EE 文本消息格式无效');
  }
};

export const e2eeDirectMessageCoordinator = new E2eeDirectMessageCoordinator();
