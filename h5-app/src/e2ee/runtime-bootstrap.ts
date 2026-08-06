import { e2eeDeviceLifecycle } from '@/e2ee/device-lifecycle';
import { settingsService } from '@/services/settings-service';

interface RuntimeSettings {
  messageRuntime: { contentAuditMode: string };
}

interface RuntimeSettingsService {
  fetchGeneralSettings(): Promise<RuntimeSettings>;
}

interface DeviceLifecycle {
  ensureReady(accountId: string, deviceLabel: string): Promise<unknown>;
  topUpKeyPackages(accountId: string): Promise<unknown>;
}

export class E2eeRuntimeBootstrap {
  private readonly pending = new Map<string, Promise<boolean>>();

  constructor(
    private readonly settings: RuntimeSettingsService = settingsService,
    private readonly lifecycle: DeviceLifecycle = e2eeDeviceLifecycle,
  ) {}

  ensureReady(accountId: string, deviceLabel = 'RedCode H5'): Promise<boolean> {
    const normalized = accountId.trim();
    if (!normalized) return Promise.reject(new Error('E2EE 账号标识不能为空'));
    const existing = this.pending.get(normalized);
    if (existing) return existing;

    const task = this.initialize(normalized, deviceLabel).finally(() => {
      this.pending.delete(normalized);
    });
    this.pending.set(normalized, task);
    return task;
  }

  private async initialize(accountId: string, deviceLabel: string): Promise<boolean> {
    let runtime: RuntimeSettings;
    try {
      runtime = await this.settings.fetchGeneralSettings();
    } catch {
      // 消息发送会重新读取 runtime 并保持 fail closed；Home 的缓存与联系人不应被瞬时设置请求阻断。
      return false;
    }
    if (runtime.messageRuntime.contentAuditMode !== 'e2ee') return false;
    await this.lifecycle.ensureReady(accountId, deviceLabel);
    void this.lifecycle.topUpKeyPackages(accountId).catch(() => undefined);
    return true;
  }
}

export const e2eeRuntimeBootstrap = new E2eeRuntimeBootstrap();
