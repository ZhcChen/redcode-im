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
  ): Promise<unknown>;
  publishKeyPackage(deviceId: string, keyPackage: Uint8Array): Promise<unknown>;
}

export class E2eeDeviceNotReadyError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'E2eeDeviceNotReadyError';
  }
}

export class E2eeDeviceLifecycle {
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
      await this.mlsApi.registerDevice(readyProfile.deviceId, readyProfile.deviceLabel, material);
      readyProfile = { ...readyProfile, registered: true };
      await this.storage.writeDeviceProfile(accountId, readyProfile);
    }

    if (!readyProfile.keyPackagePublished) {
      const generated = await this.core.generateKeyPackage(state);
      state = generated.field(0);
      await this.storage.write(accountId, state);
      await this.mlsApi.publishKeyPackage(readyProfile.deviceId, generated.field(1));
      readyProfile = { ...readyProfile, keyPackagePublished: true };
      await this.storage.writeDeviceProfile(accountId, readyProfile);
    }

    return { profile: readyProfile, state };
  }
}

export const e2eeDeviceLifecycle = new E2eeDeviceLifecycle();
