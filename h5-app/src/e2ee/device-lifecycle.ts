import { ApiError } from '@/api/http';
import type { E2eeDeviceProfile } from '@/e2ee/device-profile';
import { e2eeSecureStateStorage } from '@/e2ee/secure-state-storage';
import { e2eeSession, type E2eeCommandResult } from '@/e2ee/session';
import { e2eeIdentityService } from '@/services/e2ee-identity-service';
import {
  e2eeMlsApiService,
  registrationMaterialFromCommand,
  registrationMaterialFromRestoredCommand,
  type E2eeDeviceRegistrationMaterial,
} from '@/services/e2ee-mls-api-service';

interface DeviceStorage {
  read(accountId: string): Promise<Uint8Array | null>;
  write(accountId: string, state: Uint8Array): Promise<void>;
  readDeviceProfile(accountId: string): Promise<E2eeDeviceProfile | null>;
  writeDeviceProfile(accountId: string, profile: E2eeDeviceProfile): Promise<void>;
}

interface SessionCore {
  initializeWithRoot(deviceIdentity: string, rootPublicKey?: Uint8Array): Promise<E2eeCommandResult>;
  publicMaterial(state: Uint8Array): Promise<E2eeCommandResult>;
  generateKeyPackage(state: Uint8Array): Promise<E2eeCommandResult>;
}

interface IdentityApi {
  fetchRootIdentity(userId: string): Promise<{ publicKey: Uint8Array }>;
}

interface MlsApi {
  registerDevice(
    deviceId: string,
    deviceLabel: string,
    material: E2eeDeviceRegistrationMaterial,
  ): Promise<{ status: string }>;
  publishKeyPackage(deviceId: string, keyPackage: Uint8Array): Promise<unknown>;
  publishKeyPackages(deviceId: string, keyPackages: Uint8Array[]): Promise<unknown>;
  fetchKeyPackageInventory(deviceId: string): Promise<{
    available: number;
    maxAvailable: number;
  }>;
  listDevices(): Promise<Array<{ id: string; status: string }>>;
}

export class E2eeDeviceNotReadyError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'E2eeDeviceNotReadyError';
  }
}

const KEY_PACKAGE_LOW_WATERMARK = 10;
const KEY_PACKAGE_TARGET = 40;
const KEY_PACKAGE_BATCH_LIMIT = 20;
const REPLENISH_RETRY_AFTER_MS = 60_000;

export class E2eeDeviceLifecycle {
  private readonly replenishLocks = new Map<string, Promise<{ replenished: number }>>();
  private readonly nextRetryAt = new Map<string, number>();

  constructor(
    private readonly storage: DeviceStorage = e2eeSecureStateStorage,
    private readonly core: SessionCore = e2eeSession,
    private readonly identityApi: IdentityApi = e2eeIdentityService,
    private readonly mlsApi: MlsApi = e2eeMlsApiService,
    private readonly newDeviceId: () => string = () => crypto.randomUUID(),
  ) {}

  async ensureReady(accountId: string, deviceLabel: string) {
    let state = await this.storage.read(accountId);
    let profile = await this.storage.readDeviceProfile(accountId);
    if (state && !profile) {
      throw new E2eeDeviceNotReadyError('E2EE 设备状态不完整，拒绝重新生成身份');
    }
    if (!state && profile?.registered) {
      throw new E2eeDeviceNotReadyError('E2EE 已注册设备状态缺失，拒绝重新生成身份');
    }

    let material: E2eeDeviceRegistrationMaterial;
    if (!state) {
      let rootPublicKey: Uint8Array | undefined;
      try {
        rootPublicKey = (await this.identityApi.fetchRootIdentity(accountId)).publicKey;
      } catch (error) {
        if (!(error instanceof ApiError) || error.status !== 404) throw error;
      }
      profile ??= {
        deviceId: this.newDeviceId(),
        deviceLabel,
        registered: false,
        keyPackagePublished: false,
        lastControlSequences: {},
        lastCommitMessageIds: {},
      };
      await this.storage.writeDeviceProfile(accountId, profile);
      material = registrationMaterialFromCommand(
        await this.core.initializeWithRoot(`${accountId}/${profile.deviceId}`, rootPublicKey),
      );
      state = material.state;
      await this.storage.write(accountId, state);
    } else {
      material = registrationMaterialFromRestoredCommand(await this.core.publicMaterial(state));
    }

    if (!profile) throw new E2eeDeviceNotReadyError('E2EE 设备档案缺失');
    let readyProfile = profile;

    if (!readyProfile.registered) {
      const registered = await this.mlsApi.registerDevice(
        readyProfile.deviceId,
        readyProfile.deviceLabel,
        material,
      );
      const status = String(registered.status ?? '');
      if (status === 'pending_approval') {
        // 非首设备保持 pending，服务端拒绝发布 KeyPackage，等待可信设备批准。
        readyProfile = {
          ...readyProfile,
          registered: true,
          keyPackagePublished: false,
          deviceStatus: 'pending_approval',
        };
        await this.storage.writeDeviceProfile(accountId, readyProfile);
        return { profile: readyProfile, state };
      }
      readyProfile = { ...readyProfile, registered: true, deviceStatus: 'active' };
      await this.storage.writeDeviceProfile(accountId, readyProfile);
    }

    if (readyProfile.deviceStatus === 'pending_approval') {
      // 已批准设备恢复能力：服务端状态变为 active 后继续发布 KeyPackage。
      const devices = await this.mlsApi.listDevices();
      const current = devices.find((device) => device.id === readyProfile.deviceId);
      if (current?.status !== 'active') {
        return { profile: readyProfile, state };
      }
      readyProfile = { ...readyProfile, deviceStatus: 'active' };
      await this.storage.writeDeviceProfile(accountId, readyProfile);
    }

    if (readyProfile.deviceStatus !== 'pending_approval' && !readyProfile.keyPackagePublished) {
      const generated = await this.core.generateKeyPackage(state);
      state = generated.field(0);
      await this.storage.write(accountId, state);
      await this.mlsApi.publishKeyPackage(readyProfile.deviceId, generated.field(1));
      readyProfile = { ...readyProfile, keyPackagePublished: true, deviceStatus: 'active' };
      await this.storage.writeDeviceProfile(accountId, readyProfile);
    }

    return { profile: readyProfile, state };
  }

  /**
   * 按低水位补充本设备 KeyPackage 库存。账号级互斥：并发调用共享同一个
   * Promise；失败后进入退避窗口，不阻塞已建立房间的消息链。
   */
  async topUpKeyPackages(accountId: string): Promise<{ replenished: number }> {
    const existing = this.replenishLocks.get(accountId);
    if (existing) return existing;
    const task = this.doTopUp(accountId).finally(() => {
      this.replenishLocks.delete(accountId);
    });
    this.replenishLocks.set(accountId, task);
    return task;
  }

  private async doTopUp(accountId: string): Promise<{ replenished: number }> {
    const profile = await this.storage.readDeviceProfile(accountId);
    if (!profile?.registered || profile.deviceStatus === 'pending_approval' || !profile.keyPackagePublished) {
      if (profile?.deviceStatus === 'pending_approval') {
        throw new E2eeDeviceNotReadyError('E2EE 设备待批准，批准后才能补充 KeyPackage');
      }
      throw new E2eeDeviceNotReadyError('E2EE 设备未完成初始化，无法补充 KeyPackage');
    }
    const retryAt = this.nextRetryAt.get(accountId);
    if (retryAt !== undefined && Date.now() < retryAt) {
      return { replenished: 0 };
    }

    const inventory = await this.mlsApi.fetchKeyPackageInventory(profile.deviceId);
    if (inventory.available >= KEY_PACKAGE_LOW_WATERMARK) {
      this.nextRetryAt.delete(accountId);
      return { replenished: 0 };
    }

    const needed = Math.min(
      KEY_PACKAGE_TARGET - inventory.available,
      KEY_PACKAGE_BATCH_LIMIT,
    );
    if (needed <= 0) {
      this.nextRetryAt.delete(accountId);
      return { replenished: 0 };
    }

    try {
      let state = await this.storage.read(accountId);
      if (!state) throw new E2eeDeviceNotReadyError('E2EE 设备状态缺失');
      const keyPackages: Uint8Array[] = [];
      for (let index = 0; index < needed; index += 1) {
        const generated = await this.core.generateKeyPackage(state);
        state = generated.field(0);
        keyPackages.push(generated.field(1));
      }
      await this.storage.write(accountId, state);
      const result = await this.mlsApi.publishKeyPackages(profile.deviceId, keyPackages);
      const inserted = typeof result === 'object' && result !== null
        ? Number((result as { inserted?: unknown }).inserted)
        : keyPackages.length;
      this.nextRetryAt.delete(accountId);
      return { replenished: Number.isFinite(inserted) ? inserted : keyPackages.length };
    } catch (error) {
      this.nextRetryAt.set(accountId, Date.now() + REPLENISH_RETRY_AFTER_MS);
      throw error;
    }
  }
}

export const e2eeDeviceLifecycle = new E2eeDeviceLifecycle();
