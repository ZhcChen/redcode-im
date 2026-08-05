import { describe, expect, it, vi } from 'vitest';

import { ApiError } from '@/api/http';
import type { E2eeDeviceProfile } from '@/e2ee/device-profile';
import { E2eeDeviceLifecycle } from '@/e2ee/device-lifecycle';
import { E2eeCommandResult } from '@/e2ee/session';

describe('E2eeDeviceLifecycle', () => {
  it('retries interrupted provisioning without replacing device identity', async () => {
    const storage = new MemoryDeviceStorage();
    const initializedState = new Uint8Array([1]);
    const generatedState = new Uint8Array([2]);
    const publicFields = [
      new Uint8Array(32).fill(2),
      new Uint8Array(32).fill(3),
      new Uint8Array([4]),
      new Uint8Array(32).fill(5),
      new Uint8Array(32).fill(6),
    ];
    const core = {
      initializeWithRoot: vi.fn(async () => new E2eeCommandResult([
        initializedState,
        new Uint8Array([9]),
        ...publicFields,
      ])),
      publicMaterial: vi.fn(async (state: Uint8Array) => new E2eeCommandResult([
        state,
        ...publicFields,
      ])),
      generateKeyPackage: vi.fn(async () => new E2eeCommandResult([
        generatedState,
        new Uint8Array([8]),
      ])),
    };
    const identityApi = {
      fetchRootIdentity: vi.fn(async () => {
        throw new ApiError('missing', 404, null);
      }),
    };
    let publishCalls = 0;
    const mlsApi = {
      registerDevice: vi.fn(async () => ({ status: 'active' })),
      publishKeyPackage: vi.fn(async () => {
        publishCalls += 1;
        if (publishCalls === 1) throw new Error('temporary');
        return {};
      }),
      publishKeyPackages: vi.fn(async () => ({ inserted: 0 })),
      fetchKeyPackageInventory: vi.fn(async () => ({ available: 40, maxAvailable: 500 })),
      listDevices: vi.fn(async () => []),
    };
    const lifecycle = new E2eeDeviceLifecycle(
      storage,
      core,
      identityApi,
      mlsApi,
      () => '018f5be3-3277-7d45-a6f3-bd2ebc89f321',
    );

    await expect(lifecycle.ensureReady('account-a', 'Browser')).rejects.toThrow('temporary');
    expect(storage.profile?.registered).toBe(true);
    expect(storage.profile?.keyPackagePublished).toBe(false);

    const ready = await lifecycle.ensureReady('account-a', 'ignored');

    expect(ready.profile.deviceId).toBe('018f5be3-3277-7d45-a6f3-bd2ebc89f321');
    expect(ready.profile.deviceLabel).toBe('Browser');
    expect(ready.profile.keyPackagePublished).toBe(true);
    expect(ready.state).toEqual(generatedState);
    expect(core.initializeWithRoot).toHaveBeenCalledOnce();
    expect(mlsApi.registerDevice).toHaveBeenCalledOnce();
    expect(mlsApi.publishKeyPackage).toHaveBeenCalledTimes(2);
  });

  it('fails closed when profile and protocol state diverge', async () => {
    const storage = new MemoryDeviceStorage();
    storage.state = new Uint8Array([1]);
    const lifecycle = new E2eeDeviceLifecycle(
      storage,
      {} as never,
      {} as never,
      {} as never,
    );

    await expect(lifecycle.ensureReady('account-a', 'Browser'))
      .rejects.toThrow('拒绝重新生成身份');
  });

  it('replenishes key packages above the low watermark with an account lock', async () => {
    const storage = new MemoryDeviceStorage();
    storage.profile = {
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: {},
    };
    storage.state = new Uint8Array([1]);
    let generationCalls = 0;
    const core = {
      initializeWithRoot: vi.fn(),
      publicMaterial: vi.fn(),
      generateKeyPackage: vi.fn(async () => {
        generationCalls += 1;
        return new E2eeCommandResult([
          new Uint8Array([generationCalls]),
          new Uint8Array([20 + generationCalls]),
        ]);
      }),
    };
    const mlsApi = {
      registerDevice: vi.fn(async () => ({ status: 'active' })),
      publishKeyPackage: vi.fn(async () => ({})),
      publishKeyPackages: vi.fn(async (_deviceId: string, keyPackages: Uint8Array[]) => ({
        inserted: keyPackages.length,
      })),
      fetchKeyPackageInventory: vi.fn(async () => ({ available: 3, maxAvailable: 500 })),
      listDevices: vi.fn(async () => []),
    };
    const lifecycle = new E2eeDeviceLifecycle(
      storage,
      core,
      {} as never,
      mlsApi,
    );

    const first = lifecycle.topUpKeyPackages('account-a');
    const second = lifecycle.topUpKeyPackages('account-a');

    expect(await first).toEqual({ replenished: 20 });
    expect(await second).toEqual({ replenished: 20 });
    expect(mlsApi.fetchKeyPackageInventory).toHaveBeenCalledTimes(1);
    expect(core.generateKeyPackage).toHaveBeenCalledTimes(20);
    expect(mlsApi.publishKeyPackages).toHaveBeenCalledTimes(1);
  });

  it('skips replenishment when inventory is above the low watermark', async () => {
    const storage = new MemoryDeviceStorage();
    storage.profile = {
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: {},
    };
    storage.state = new Uint8Array([1]);
    const mlsApi = {
      registerDevice: vi.fn(async () => ({ status: 'active' })),
      publishKeyPackage: vi.fn(async () => ({})),
      publishKeyPackages: vi.fn(async () => ({ inserted: 0 })),
      fetchKeyPackageInventory: vi.fn(async () => ({ available: 30, maxAvailable: 500 })),
      listDevices: vi.fn(async () => []),
    };
    const lifecycle = new E2eeDeviceLifecycle(
      storage,
      { generateKeyPackage: vi.fn() } as never,
      {} as never,
      mlsApi,
    );

    expect(await lifecycle.topUpKeyPackages('account-a')).toEqual({ replenished: 0 });
    expect(mlsApi.publishKeyPackages).not.toHaveBeenCalled();
  });

  it('backs off after a failed replenishment and recovers on retry', async () => {
    const storage = new MemoryDeviceStorage();
    storage.profile = {
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: {},
    };
    storage.state = new Uint8Array([1]);
    const mlsApi = {
      registerDevice: vi.fn(async () => ({ status: 'active' })),
      publishKeyPackage: vi.fn(async () => ({})),
      publishKeyPackages: vi.fn<(deviceId: string, keyPackages: Uint8Array[]) =>
        Promise<{ inserted: number }>>(async () => {
        throw new Error('network offline');
      }),
      fetchKeyPackageInventory: vi.fn(async () => ({ available: 1, maxAvailable: 500 })),
      listDevices: vi.fn(async () => []),
    };
    const lifecycle = new E2eeDeviceLifecycle(
      storage,
      {
        generateKeyPackage: vi.fn(async () => new E2eeCommandResult([
          new Uint8Array([2]),
          new Uint8Array([3]),
        ])),
      } as never,
      {} as never,
      mlsApi,
    );

    await expect(lifecycle.topUpKeyPackages('account-a')).rejects.toThrow('network offline');
    // 退避窗口内不再尝试
    expect(await lifecycle.topUpKeyPackages('account-a')).toEqual({ replenished: 0 });
    expect(mlsApi.fetchKeyPackageInventory).toHaveBeenCalledTimes(1);

    // 退避到期后重试成功
    vi.useFakeTimers();
    vi.setSystemTime(Date.now() + 61_000);
    mlsApi.publishKeyPackages.mockResolvedValue({ inserted: 20 });
    expect(await lifecycle.topUpKeyPackages('account-a')).toEqual({ replenished: 20 });
    vi.useRealTimers();
  });

  it('keeps a second device pending until a trusted device approves it', async () => {
    const storage = new MemoryDeviceStorage();
    const publicFields = [
      new Uint8Array(32).fill(2),
      new Uint8Array(32).fill(3),
      new Uint8Array([4]),
      new Uint8Array(32).fill(5),
      new Uint8Array(32).fill(6),
    ];
    const core = {
      initializeWithRoot: vi.fn(async () => new E2eeCommandResult([
        new Uint8Array([1]),
        new Uint8Array([9]),
        ...publicFields,
      ])),
      publicMaterial: vi.fn(async (state: Uint8Array) => new E2eeCommandResult([
        state,
        ...publicFields,
      ])),
      generateKeyPackage: vi.fn(async () => new E2eeCommandResult([
        new Uint8Array([2]),
        new Uint8Array([8]),
      ])),
    };
    const mlsApi = {
      registerDevice: vi.fn(async () => ({ status: 'pending_approval' })),
      publishKeyPackage: vi.fn(async () => ({})),
      publishKeyPackages: vi.fn(async () => ({ inserted: 0 })),
      fetchKeyPackageInventory: vi.fn(async () => ({ available: 3, maxAvailable: 500 })),
      listDevices: vi.fn(async () => []),
    };
    const lifecycle = new E2eeDeviceLifecycle(
      storage,
      core,
      { fetchRootIdentity: vi.fn(async () => ({ publicKey: new Uint8Array(32).fill(7) })) },
      mlsApi,
      () => '018f5be3-3277-7d45-a6f3-bd2ebc89f321',
    );

    const ready = await lifecycle.ensureReady('account-a', 'Browser');

    expect(ready.profile.deviceStatus).toBe('pending_approval');
    expect(ready.profile.keyPackagePublished).toBe(false);
    expect(mlsApi.publishKeyPackage).not.toHaveBeenCalled();
    await expect(lifecycle.topUpKeyPackages('account-a')).rejects.toThrow('待批准');
  });

  it('publishes key packages after the pending device is approved', async () => {
    const storage = new MemoryDeviceStorage();
    storage.state = new Uint8Array([1]);
    storage.profile = {
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: false,
      deviceStatus: 'pending_approval',
      lastControlSequences: {},
      lastCommitMessageIds: {},
    };
    const mlsApi = {
      registerDevice: vi.fn(async () => ({ status: 'active' })),
      publishKeyPackage: vi.fn(async () => ({})),
      publishKeyPackages: vi.fn(async () => ({ inserted: 0 })),
      fetchKeyPackageInventory: vi.fn(async () => ({ available: 3, maxAvailable: 500 })),
      listDevices: vi.fn(async () => [{ id: 'device-a', status: 'active' }]),
    };
    const lifecycle = new E2eeDeviceLifecycle(
      storage,
      {
        publicMaterial: vi.fn(async (state: Uint8Array) => new E2eeCommandResult([
          state,
          new Uint8Array(32).fill(2),
          new Uint8Array(32).fill(3),
          new Uint8Array([4]),
          new Uint8Array(32).fill(5),
          new Uint8Array(32).fill(6),
        ])),
        generateKeyPackage: vi.fn(async () => new E2eeCommandResult([
          new Uint8Array([2]),
          new Uint8Array([8]),
        ])),
      } as never,
      {} as never,
      mlsApi,
    );

    const ready = await lifecycle.ensureReady('account-a', 'ignored');

    expect(ready.profile.deviceStatus).toBe('active');
    expect(ready.profile.keyPackagePublished).toBe(true);
    expect(mlsApi.listDevices).toHaveBeenCalledOnce();
    expect(mlsApi.publishKeyPackage).toHaveBeenCalledOnce();
  });
});

class MemoryDeviceStorage {
  state: Uint8Array | null = null;
  profile: E2eeDeviceProfile | null = null;

  async read() {
    return this.state?.slice() ?? null;
  }

  async write(_accountId: string, state: Uint8Array) {
    this.state = state.slice();
  }

  async readDeviceProfile() {
    return this.profile ? { ...this.profile } : null;
  }

  async writeDeviceProfile(_accountId: string, profile: E2eeDeviceProfile) {
    this.profile = { ...profile };
  }
}
