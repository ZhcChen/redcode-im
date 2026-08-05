import { describe, expect, it, vi } from 'vitest';

import type { E2eeDeviceProfile } from '@/e2ee/device-profile';
import { E2eeDirectMessageCoordinator } from '@/e2ee/direct-message-coordinator';
import type { E2eeIdentityTrustRecord } from '@/e2ee/identity-trust';
import type { E2eePendingOperation } from '@/e2ee/pending-operation';
import { E2eeCommandResult } from '@/e2ee/session';
import type { E2eeDeviceInfo } from '@/services/e2ee-mls-api-service';

describe('E2eeDirectMessageCoordinator', () => {
  it('replays interrupted bootstrap before encrypting without plaintext API fields', async () => {
    const storage = new MemoryStorage();
    const profile: E2eeDeviceProfile = {
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: {},
    };
    storage.state = new Uint8Array([1]);
    storage.profile = profile;
    const core = {
      createGroup: vi.fn(async () => new E2eeCommandResult([new Uint8Array([2])])),
      addMember: vi.fn(async () => new E2eeCommandResult([
        new Uint8Array([3]),
        new Uint8Array([10]),
        new Uint8Array([11]),
        epochBytes(1),
      ])),
      encrypt: vi.fn(async () => new E2eeCommandResult([
        new Uint8Array([4]),
        new Uint8Array([82, 67, 77, 76, 12]),
        epochBytes(1),
      ])),
      decrypt: vi.fn(),
      joinGroup: vi.fn(),
      processCommit: vi.fn(),
      removeMember: vi.fn(),
    };
    let activeEpoch = 0;
    let failWelcomeOnce = true;
    const controlIds: string[] = [];
    const api = {
      getRoomEpoch: vi.fn(async () => ({
        membershipRevision: 1,
        activeEpoch,
        status: activeEpoch === 0 ? 'pending' : 'active',
      })),
      listPeerDevices: vi.fn(async () => [{
        id: 'device-b',
        protocolVersion: 1,
        credentialFingerprint: new Uint8Array(32),
      }]),
      claimKeyPackage: vi.fn(async () => ({ keyPackage: new Uint8Array([9]) })),
      submitControlMessage: vi.fn(async (input: { contentType: string; messageId: string; epoch: number }) => {
        controlIds.push(input.messageId);
        if (input.contentType === 'commit') activeEpoch = input.epoch;
        if (input.contentType === 'welcome' && failWelcomeOnce) {
          failWelcomeOnce = false;
          throw new Error('temporary');
        }
        return {};
      }),
      sendEncryptedMessage: vi.fn(async (_input: {
        ciphertext: Uint8Array;
      }) => ({ message: { id: 'server-message' } })),
      listControlMessages: vi.fn(async () => []),
      consumeControlMessage: vi.fn(async () => {}),
      listDevices: vi.fn(async () => []),
    };
    const ids = ['commit-a', 'welcome-a', 'bootstrap-a', 'message-a'];
    const coordinator = new E2eeDirectMessageCoordinator(
      storage,
      { ensureReady: vi.fn(async () => ({})) },
      { fetchRootIdentity: vi.fn(async (userId: string) => ({
        userId,
        publicKey: new Uint8Array(32).fill(3),
        fingerprint: new Uint8Array(32).fill(4),
        protocolVersion: 1,
      })) },
      api,
      core,
      () => ids.shift()!,
    );

    await expect(coordinator.sendText({
      accountId: 'account-a',
      deviceLabel: 'ignored',
      roomId: 'room-a',
      peerUserId: 'account-b',
      text: 'first attempt',
    })).rejects.toThrow('temporary');
    expect(storage.pending).not.toBeNull();

    const response = await coordinator.sendText({
      accountId: 'account-a',
      deviceLabel: 'ignored',
      roomId: 'room-a',
      peerUserId: 'account-b',
      text: 'secret text',
    });

    expect(response).toEqual({ message: { id: 'server-message' } });
    expect(controlIds).toEqual(['commit-a', 'welcome-a', 'commit-a', 'welcome-a']);
    expect(api.claimKeyPackage).toHaveBeenCalledOnce();
    expect(api.sendEncryptedMessage).toHaveBeenCalledOnce();
    expect(Array.from(api.sendEncryptedMessage.mock.calls[0]![0].ciphertext))
      .toEqual([82, 67, 77, 76, 12]);
    expect(storage.pending).toBeNull();
    expect(storage.profile?.lastCommitMessageIds['room-a']).toBe('commit-a');
  });

  it('restores welcome and later commits before acknowledging controls', async () => {
    const storage = new MemoryStorage();
    storage.state = new Uint8Array([1]);
    storage.profile = {
      deviceId: 'device-b',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: {},
    };
    const controls = [{
      id: 'commit-1', epoch: 1, membershipRevision: 1, contentType: 'commit' as const,
      envelope: new Uint8Array([10]), sequenceNo: 1,
    }, {
      id: 'welcome-1', epoch: 1, membershipRevision: 1, contentType: 'welcome' as const,
      envelope: new Uint8Array([11]), sequenceNo: 2,
    }, {
      id: 'commit-2', epoch: 2, membershipRevision: 1, contentType: 'commit' as const,
      envelope: new Uint8Array([12]), sequenceNo: 3,
    }];
    let failWelcomeOnce = true;
    const consumeIds: string[] = [];
    const api = {
      getRoomEpoch: vi.fn(),
      listPeerDevices: vi.fn(),
      claimKeyPackage: vi.fn(),
      submitControlMessage: vi.fn(),
      sendEncryptedMessage: vi.fn(),
      listControlMessages: vi.fn(async (_roomId: string, _deviceId: string, after = 0) => (
        controls.filter((control) => control.sequenceNo > after)
      )),
      consumeControlMessage: vi.fn(async (_roomId: string, messageId: string) => {
        consumeIds.push(messageId);
        if (messageId === 'welcome-1' && failWelcomeOnce) {
          failWelcomeOnce = false;
          throw new Error('temporary');
        }
      }),
      listDevices: vi.fn(async () => []),
    };
    const core = {
      createGroup: vi.fn(),
      addMember: vi.fn(),
      encrypt: vi.fn(),
      decrypt: vi.fn(async () => new E2eeCommandResult([
        new Uint8Array([4]),
        new TextEncoder().encode(JSON.stringify({ version: 1, type: 'text', text: 'hello Bob' })),
        epochBytes(2),
      ])),
      joinGroup: vi.fn(async () => new E2eeCommandResult([
        new Uint8Array([2]), epochBytes(1),
      ])),
      processCommit: vi.fn(async () => new E2eeCommandResult([
        new Uint8Array([3]), epochBytes(2),
      ])),
      removeMember: vi.fn(),
    };
    const coordinator = new E2eeDirectMessageCoordinator(
      storage,
      { ensureReady: vi.fn(async () => ({})) },
      {} as never,
      api,
      core,
    );

    await expect(coordinator.syncControlMessages({
      accountId: 'account-b', deviceLabel: 'ignored', roomId: 'room-a',
    })).rejects.toThrow('temporary');
    expect(storage.pending).not.toBeNull();

    await coordinator.syncControlMessages({
      accountId: 'account-b', deviceLabel: 'ignored', roomId: 'room-a',
    });
    const decrypted = await coordinator.decryptText({
      accountId: 'account-b',
      deviceLabel: 'ignored',
      roomId: 'room-a',
      ciphertext: new Uint8Array([82, 67, 77, 76]),
    });

    expect(core.joinGroup).toHaveBeenCalledOnce();
    expect(core.processCommit).toHaveBeenCalledOnce();
    expect(consumeIds).toEqual(['commit-1', 'welcome-1', 'commit-1', 'welcome-1', 'commit-2']);
    expect(storage.profile?.lastControlSequences['room-a']).toBe(3);
    expect(storage.profile?.lastCommitMessageIds['room-a']).toBe('commit-2');
    expect(decrypted).toEqual({ text: 'hello Bob', epoch: 2 });
    expect(Array.from(storage.state ?? [])).toEqual([4]);
    expect(storage.pending).toBeNull();
  });

  it('blocks sends when the peer root identity changes without touching MLS APIs', async () => {
    const storage = new MemoryStorage();
    storage.state = new Uint8Array([1]);
    storage.profile = {
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: {},
    };
    storage.records['peer-b'] = {
      trusted: {
        userId: 'peer-b',
        publicKey: new Uint8Array(32).fill(3),
        fingerprint: new Uint8Array(32).fill(4),
        protocolVersion: 1,
      },
      trustedAt: '2026-08-04T00:00:00.000Z',
    };
    const api = {
      getRoomEpoch: vi.fn(),
      listPeerDevices: vi.fn(),
      claimKeyPackage: vi.fn(),
      submitControlMessage: vi.fn(),
      sendEncryptedMessage: vi.fn(),
      listControlMessages: vi.fn(async () => []),
      consumeControlMessage: vi.fn(),
      listDevices: vi.fn(async () => []),
    };
    const coordinator = new E2eeDirectMessageCoordinator(
      storage,
      { ensureReady: vi.fn(async () => ({})) },
      { fetchRootIdentity: vi.fn(async (userId: string) => ({
        userId,
        publicKey: new Uint8Array(32).fill(5),
        fingerprint: new Uint8Array(32).fill(6),
        protocolVersion: 1,
      })) },
      api,
      {
        createGroup: vi.fn(),
        addMember: vi.fn(),
        encrypt: vi.fn(),
        decrypt: vi.fn(),
        joinGroup: vi.fn(),
        processCommit: vi.fn(),
        removeMember: vi.fn(),
      },
    );

    await expect(coordinator.sendText({
      accountId: 'account-a',
      deviceLabel: 'ignored',
      roomId: 'room-a',
      peerUserId: 'peer-b',
      text: 'secret text',
    })).rejects.toThrow('身份已变化');

    expect(api.claimKeyPackage).not.toHaveBeenCalled();
    expect(api.submitControlMessage).not.toHaveBeenCalled();
    expect(api.sendEncryptedMessage).not.toHaveBeenCalled();
    expect(storage.pending).toBeNull();
  });

  it('fails clearly when the peer has no E2EE device', async () => {
    const storage = new MemoryStorage();
    storage.state = new Uint8Array([1]);
    storage.profile = {
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: {},
    };
    const api = {
      getRoomEpoch: vi.fn(async () => ({
        membershipRevision: 1,
        activeEpoch: 0,
        status: 'pending',
      })),
      listPeerDevices: vi.fn(async () => []),
      claimKeyPackage: vi.fn(),
      submitControlMessage: vi.fn(),
      sendEncryptedMessage: vi.fn(),
      listControlMessages: vi.fn(async () => []),
      consumeControlMessage: vi.fn(),
      listDevices: vi.fn(async () => []),
    };
    const coordinator = new E2eeDirectMessageCoordinator(
      storage,
      { ensureReady: vi.fn(async () => ({})) },
      { fetchRootIdentity: vi.fn(async (userId: string) => ({
        userId,
        publicKey: new Uint8Array(32).fill(3),
        fingerprint: new Uint8Array(32).fill(4),
        protocolVersion: 1,
      })) },
      api,
      {
        createGroup: vi.fn(),
        addMember: vi.fn(),
        encrypt: vi.fn(),
        decrypt: vi.fn(),
        joinGroup: vi.fn(),
        processCommit: vi.fn(),
        removeMember: vi.fn(),
      },
    );

    await expect(coordinator.sendText({
      accountId: 'account-a',
      deviceLabel: 'ignored',
      roomId: 'room-a',
      peerUserId: 'peer-b',
      text: 'secret text',
    })).rejects.toThrow('联系人没有可用的 E2EE 设备');

    expect(api.claimKeyPackage).not.toHaveBeenCalled();
    expect(api.submitControlMessage).not.toHaveBeenCalled();
    expect(api.sendEncryptedMessage).not.toHaveBeenCalled();
    expect(storage.pending).toBeNull();
  });

  it('fails bootstrap clearly when no key package is claimable', async () => {
    const storage = new MemoryStorage();
    storage.state = new Uint8Array([1]);
    storage.profile = {
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: {},
    };
    const api = {
      getRoomEpoch: vi.fn(async () => ({
        membershipRevision: 1,
        activeEpoch: 0,
        status: 'pending',
      })),
      listPeerDevices: vi.fn(async () => [{
        id: 'device-b',
        protocolVersion: 1,
        credentialFingerprint: new Uint8Array(32),
      }]),
      claimKeyPackage: vi.fn(async () => {
        throw new Error('KeyPackage 不存在或已被领取');
      }),
      submitControlMessage: vi.fn(),
      sendEncryptedMessage: vi.fn(),
      listControlMessages: vi.fn(async () => []),
      consumeControlMessage: vi.fn(),
      listDevices: vi.fn(async () => []),
    };
    const coordinator = new E2eeDirectMessageCoordinator(
      storage,
      { ensureReady: vi.fn(async () => ({})) },
      { fetchRootIdentity: vi.fn(async (userId: string) => ({
        userId,
        publicKey: new Uint8Array(32).fill(3),
        fingerprint: new Uint8Array(32).fill(4),
        protocolVersion: 1,
      })) },
      api,
      {
        createGroup: vi.fn(async () => new E2eeCommandResult([new Uint8Array([2])])),
        addMember: vi.fn(),
        encrypt: vi.fn(),
        decrypt: vi.fn(),
        joinGroup: vi.fn(),
        processCommit: vi.fn(),
        removeMember: vi.fn(),
      },
    );

    await expect(coordinator.sendText({
      accountId: 'account-a',
      deviceLabel: 'ignored',
      roomId: 'room-a',
      peerUserId: 'peer-b',
      text: 'secret text',
    })).rejects.toThrow('KeyPackage 不存在或已被领取');

    expect(api.claimKeyPackage).toHaveBeenCalledOnce();
    expect(api.submitControlMessage).not.toHaveBeenCalled();
    expect(api.sendEncryptedMessage).not.toHaveBeenCalled();
    expect(storage.pending).toBeNull();
  });

  it('rejects stale local epoch before persisting pending application state', async () => {
    const storage = new MemoryStorage();
    storage.state = new Uint8Array([1]);
    storage.profile = {
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: { 'room-a': 'commit-1' },
    };
    const api = {
      getRoomEpoch: vi.fn(async () => ({
        membershipRevision: 1,
        activeEpoch: 2,
        status: 'active',
      })),
      listPeerDevices: vi.fn(),
      claimKeyPackage: vi.fn(),
      submitControlMessage: vi.fn(),
      sendEncryptedMessage: vi.fn(),
      listControlMessages: vi.fn(async () => []),
      consumeControlMessage: vi.fn(),
      listDevices: vi.fn(async () => []),
    };
    const coordinator = new E2eeDirectMessageCoordinator(
      storage,
      { ensureReady: vi.fn(async () => ({})) },
      { fetchRootIdentity: vi.fn(async (userId: string) => ({
        userId,
        publicKey: new Uint8Array(32).fill(3),
        fingerprint: new Uint8Array(32).fill(4),
        protocolVersion: 1,
      })) },
      api,
      {
        createGroup: vi.fn(),
        addMember: vi.fn(),
        encrypt: vi.fn(async () => new E2eeCommandResult([
          new Uint8Array([4]),
          new Uint8Array([82, 67, 77, 76, 12]),
          epochBytes(1),
        ])),
        decrypt: vi.fn(),
        joinGroup: vi.fn(),
        processCommit: vi.fn(),
        removeMember: vi.fn(),
      },
    );

    await expect(coordinator.sendText({
      accountId: 'account-a',
      deviceLabel: 'ignored',
      roomId: 'room-a',
      peerUserId: 'peer-b',
      text: 'secret text',
    })).rejects.toThrow('本地 E2EE epoch 已过期');

    expect(api.sendEncryptedMessage).not.toHaveBeenCalled();
    expect(storage.pending).toBeNull();
  });

  it('rekeys the room by removing revoked devices and submitting the commit', async () => {
    const storage = new MemoryStorage();
    storage.state = new Uint8Array([1]);
    storage.profile = {
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: { 'room-a': 'commit-1' },
    };
    const submitted: Array<{ contentType: string; epoch: number; messageId: string }> = [];
    const api = {
      getRoomEpoch: vi.fn(async () => ({
        membershipRevision: 2,
        activeEpoch: 1,
        status: 'rekey_required',
      })),
      listDevices: vi.fn(async () => deviceInfo([
        { id: 'device-a', status: 'active' },
        { id: 'device-revoked', status: 'revoked' },
      ])),
      listPeerDevices: vi.fn(),
      claimKeyPackage: vi.fn(),
      submitControlMessage: vi.fn(async (input: { contentType: string; epoch: number; messageId: string }) => {
        submitted.push(input);
        return {};
      }),
      sendEncryptedMessage: vi.fn(),
      listControlMessages: vi.fn(async () => []),
      consumeControlMessage: vi.fn(),
    };
    const coordinator = new E2eeDirectMessageCoordinator(
      storage,
      { ensureReady: vi.fn(async () => ({})) },
      { fetchRootIdentity: vi.fn(async (userId: string) => ({
        userId,
        publicKey: new Uint8Array(32).fill(3),
        fingerprint: new Uint8Array(32).fill(4),
        protocolVersion: 1,
      })) },
      api,
      {
        createGroup: vi.fn(),
        addMember: vi.fn(),
        encrypt: vi.fn(),
        decrypt: vi.fn(),
        joinGroup: vi.fn(),
        processCommit: vi.fn(),
        removeMember: vi.fn(async () => new E2eeCommandResult([
          new Uint8Array([5]),
          new Uint8Array([20]),
          epochBytes(2),
        ])),
      },
    );

    await coordinator.syncControlMessages({
      accountId: 'account-a',
      deviceLabel: 'ignored',
      roomId: 'room-a',
    });

    expect(coreRemoveMember(coordinator)).toHaveBeenCalledWith(
      expect.any(Uint8Array),
      'room-a',
      'account-a/device-revoked',
    );
    expect(submitted).toEqual([expect.objectContaining({
      contentType: 'commit',
      epoch: 2,
      membershipRevision: 2,
    })]);
    expect(storage.pending).toBeNull();
    expect(storage.profile?.lastCommitMessageIds['room-a']).toBe(submitted[0]?.messageId);
  });

  it('restores the previous state when another device wins the rekey race', async () => {
    const storage = new MemoryStorage();
    storage.state = new Uint8Array([1]);
    storage.profile = {
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: { 'room-a': 'commit-1' },
    };
    let epochStatus: 'rekey_required' | 'active' = 'rekey_required';
    const api = {
      getRoomEpoch: vi.fn(async () => ({
        membershipRevision: 2,
        activeEpoch: epochStatus === 'rekey_required' ? 1 : 2,
        status: epochStatus,
      })),
      listDevices: vi.fn(async () => deviceInfo([
        { id: 'device-a', status: 'active' },
        { id: 'device-revoked', status: 'revoked' },
      ])),
      listPeerDevices: vi.fn(),
      claimKeyPackage: vi.fn(),
      submitControlMessage: vi.fn(async () => {
        epochStatus = 'active';
        throw new Error('Commit epoch 必须为 2');
      }),
      sendEncryptedMessage: vi.fn(),
      listControlMessages: vi.fn(async () => []),
      consumeControlMessage: vi.fn(),
    };
    const coordinator = new E2eeDirectMessageCoordinator(
      storage,
      { ensureReady: vi.fn(async () => ({})) },
      {} as never,
      api,
      {
        createGroup: vi.fn(),
        addMember: vi.fn(),
        encrypt: vi.fn(),
        decrypt: vi.fn(),
        joinGroup: vi.fn(),
        processCommit: vi.fn(),
        removeMember: vi.fn(async () => new E2eeCommandResult([
          new Uint8Array([5]),
          new Uint8Array([20]),
          epochBytes(2),
        ])),
      },
    );

    // 其他设备已推进 epoch：本地恢复旧状态并通过控制消息收敛，不保留未同步状态。
    await coordinator.syncControlMessages({
      accountId: 'account-a',
      deviceLabel: 'ignored',
      roomId: 'room-a',
    });

    expect(Array.from(storage.state ?? [])).toEqual([1]);
    expect(storage.pending).toBeNull();
    expect(api.submitControlMessage).toHaveBeenCalledOnce();
  });

  it('skips revoked devices that never joined the room during rekey', async () => {
    const storage = new MemoryStorage();
    storage.state = new Uint8Array([1]);
    storage.profile = {
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: { 'room-a': 'commit-1' },
    };
    const api = {
      getRoomEpoch: vi.fn(async () => ({
        membershipRevision: 2,
        activeEpoch: 1,
        status: 'rekey_required',
      })),
      listDevices: vi.fn(async () => deviceInfo([
        { id: 'device-a', status: 'active' },
        { id: 'device-other-room', status: 'revoked' },
      ])),
      listPeerDevices: vi.fn(),
      claimKeyPackage: vi.fn(),
      submitControlMessage: vi.fn(),
      sendEncryptedMessage: vi.fn(),
      listControlMessages: vi.fn(async () => []),
      consumeControlMessage: vi.fn(),
    };
    const coordinator = new E2eeDirectMessageCoordinator(
      storage,
      { ensureReady: vi.fn(async () => ({})) },
      {} as never,
      api,
      {
        createGroup: vi.fn(),
        addMember: vi.fn(),
        encrypt: vi.fn(),
        decrypt: vi.fn(),
        joinGroup: vi.fn(),
        processCommit: vi.fn(),
        removeMember: vi.fn(async () => {
          throw new Error('MLS group member not found');
        }),
      },
    );

    await coordinator.syncControlMessages({
      accountId: 'account-a',
      deviceLabel: 'ignored',
      roomId: 'room-a',
    });

    expect(api.submitControlMessage).not.toHaveBeenCalled();
    expect(storage.pending).toBeNull();
  });
});

const coreRemoveMember = (coordinator: unknown) => (
  (coordinator as { core: { removeMember: ReturnType<typeof vi.fn> } }).core.removeMember
);

const deviceInfo = (devices: Array<{ id: string; status: 'active' | 'revoked' }>): E2eeDeviceInfo[] => (
  devices.map((device) => ({
    id: device.id,
    deviceLabel: 'Browser',
    protocolVersion: 1,
    credentialFingerprint: 'x',
    status: device.status,
    approvedByDeviceId: null,
    approvedAt: null,
    revokedAt: device.status === 'revoked' ? '2026-08-04T00:00:00.000Z' : null,
    createdAt: '2026-08-04T00:00:00.000Z',
  }))
);

class MemoryStorage {
  state: Uint8Array | null = null;
  profile: E2eeDeviceProfile | null = null;
  pending: E2eePendingOperation | null = null;
  records: Record<string, E2eeIdentityTrustRecord> = {};

  async read() { return this.state?.slice() ?? null; }
  async write(_accountId: string, state: Uint8Array) { this.state = state.slice(); }
  async readDeviceProfile() { return this.profile ? structuredClone(this.profile) : null; }
  async writeDeviceProfile(_accountId: string, profile: E2eeDeviceProfile) { this.profile = structuredClone(profile); }
  async readPendingOperation() { return this.pending ? structuredClone(this.pending) : null; }
  async writePendingOperation(_accountId: string, operation: E2eePendingOperation) { this.pending = structuredClone(operation); }
  async deletePendingOperation() { this.pending = null; }
  async readRecords() { return structuredClone(this.records); }
  async writeRecords(_accountId: string, records: Record<string, E2eeIdentityTrustRecord>) { this.records = structuredClone(records); }
  async deleteRecords() { this.records = {}; }
}

const epochBytes = (epoch: number) => {
  const value = new Uint8Array(8);
  new DataView(value.buffer).setBigUint64(0, BigInt(epoch), false);
  return value;
};
