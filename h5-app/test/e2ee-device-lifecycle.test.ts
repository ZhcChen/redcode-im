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
      registerDevice: vi.fn(async () => ({})),
      publishKeyPackage: vi.fn(async () => {
        publishCalls += 1;
        if (publishCalls === 1) throw new Error('temporary');
        return {};
      }),
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
