import { describe, expect, it, vi } from 'vitest';

import type { E2eeDeviceProfile } from '@/e2ee/device-profile';
import { E2eeDirectMessageCoordinator } from '@/e2ee/direct-message-coordinator';
import type { E2eeIdentityTrustRecord } from '@/e2ee/identity-trust';
import type { E2eePendingOperation } from '@/e2ee/pending-operation';
import { E2eeCommandResult } from '@/e2ee/session';

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
});

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
