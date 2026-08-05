import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { useAuthStore } from '@/stores/auth';
import AboutView from '@/views/settings/AboutView.vue';
import DocumentView from '@/views/settings/DocumentView.vue';
import FeedbackView from '@/views/settings/FeedbackView.vue';
import ProfileSettingsView from '@/views/settings/ProfileSettingsView.vue';
import MineProfileView from '@/views/settings/MineProfileView.vue';
import SettingsOverviewView from '@/views/settings/SettingsOverviewView.vue';
import ChatSettingsView from '@/views/settings/ChatSettingsView.vue';
import { chatSettingsService } from '@/services/chat-settings-service';
import { accountDataService } from '@/services/account-data-service';
import DeactivateAccountView from '@/views/settings/DeactivateAccountView.vue';
import VersionStatusView from '@/views/settings/VersionStatusView.vue';
import AccountSecurityView from '@/views/settings/AccountSecurityView.vue';
import { e2eeDeviceManager } from '@/e2ee/device-manager';
import { e2eeSecureStateStorage } from '@/e2ee/secure-state-storage';
import type { E2eeDeviceInfo } from '@/services/e2ee-mls-api-service';

const routeName = vi.hoisted(() => ({ value: 'privacy-policy' }));

vi.mock('vue-router', () => ({
  useRoute: () => ({
    get name() {
      return routeName.value;
    },
  }),
  useRouter: () => ({
    push: vi.fn(),
    replace: vi.fn(),
  }),
}));

const seedSession = () => {
  const authStore = useAuthStore();
  authStore.session = {
    token: 'token-1',
    user: {
      id: 'u1',
      username: 'u1@example.com',
      nickname: 'U1',
      email: 'u1@example.com',
    },
  };
};

describe('settings views', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    seedSession();
    routeName.value = 'privacy-policy';
  });

  it('renders profile settings with current user', async () => {
    const wrapper = mount(ProfileSettingsView);
    await flushPromises();

    expect(wrapper.text()).toContain('个人资料');
    expect(wrapper.text()).toContain('U1');
    expect(wrapper.text()).toContain('更换头像');
    expect(wrapper.find('input[placeholder="输入昵称"]').exists()).toBe(true);
    expect(wrapper.find('input[type="file"][accept="image/*"]').exists()).toBe(true);
  });

  it('renders privacy policy document content', async () => {
    const wrapper = mount(DocumentView);
    await flushPromises();

    expect(wrapper.text()).toContain('隐私协议');
    expect(wrapper.text()).toContain('RedCode IM 尊重并保护你的隐私');
  });

  it('renders about and feedback pages', async () => {
    const about = mount(AboutView);
    await flushPromises();
    expect(about.text()).toContain('RedCode IM');
    expect(about.text()).toContain('意见反馈');

    const feedback = mount(FeedbackView);
    expect(feedback.text()).toContain('告诉我们你的想法');
    expect(feedback.find('textarea').exists()).toBe(true);
  });

  it('renders E2EE devices and approves a pending device', async () => {
    const devices: E2eeDeviceInfo[] = [
      {
        id: 'device-a',
        deviceLabel: '当前浏览器',
        protocolVersion: 1,
        credentialFingerprint: btoa(String.fromCharCode(...new Uint8Array(32).fill(1))),
        status: 'active',
        approvedByDeviceId: null,
        approvedAt: null,
        revokedAt: null,
        createdAt: '2026-08-04T00:00:00.000Z',
      },
      {
        id: 'device-b',
        deviceLabel: '新浏览器',
        protocolVersion: 1,
        credentialFingerprint: btoa(String.fromCharCode(...new Uint8Array(32).fill(2))),
        status: 'pending_approval',
        approvedByDeviceId: null,
        approvedAt: null,
        revokedAt: null,
        createdAt: '2026-08-04T00:00:00.000Z',
      },
    ];
    vi.spyOn(e2eeSecureStateStorage, 'readDeviceProfile').mockResolvedValue({
      deviceId: 'device-a',
      deviceLabel: 'Browser',
      registered: true,
      keyPackagePublished: true,
      lastControlSequences: {},
      lastCommitMessageIds: {},
    });
    vi.spyOn(e2eeDeviceManager, 'listDevices').mockResolvedValue(devices);
    const approve = vi.spyOn(e2eeDeviceManager, 'approveDevice').mockResolvedValue({
      ...devices[1]!,
      status: 'active',
    });

    const wrapper = mount(AccountSecurityView);
    await flushPromises();

    expect(wrapper.text()).toContain('E2EE 设备');
    expect(wrapper.text()).toContain('当前设备');
    expect(wrapper.text()).toContain('新浏览器');
    await wrapper.findAll('button').find((button) => button.text() === '批准')!.trigger('click');
    await flushPromises();
    expect(approve).toHaveBeenCalledWith('u1', devices[1]);
  });

  it('renders mine profile and the independent settings overview', () => {
    const profile = mount(MineProfileView);
    expect(profile.text()).toContain('U1');
    expect(profile.text()).toContain('编辑个人资料');

    const settings = mount(SettingsOverviewView);
    expect(settings.text()).toContain('账号与安全');
    expect(settings.text()).toContain('聊天设置');
    expect(settings.text()).toContain('关于 RedCode IM');
  });

  it('updates chat background and clears local cache after confirmation', async () => {
    const clear = vi.spyOn(chatSettingsService, 'clearLocalCache').mockResolvedValue();
    const wrapper = mount(ChatSettingsView);
    await wrapper.find('.background-option--mint').trigger('click');
    expect(chatSettingsService.getBackground()).toBe('mint');
    await wrapper.findAll('button').find((button) => button.text() === '清理本地缓存')?.trigger('click');
    await wrapper.findAll('button').find((button) => button.text() === '确认清理')?.trigger('click');
    await flushPromises();
    expect(clear).toHaveBeenCalledOnce();
    expect(wrapper.text()).toContain('本地缓存已清理');
  });

  it('requires acknowledgement and keyword before deactivating the account', async () => {
    const clear = vi.spyOn(accountDataService, 'clearAll').mockResolvedValue();
    const wrapper = mount(DeactivateAccountView);
    expect(wrapper.get('button.settings-danger').attributes('disabled')).toBeDefined();
    await wrapper.get('input[type="checkbox"]').setValue(true);
    await wrapper.get('button.settings-danger').trigger('click');
    const confirm = wrapper.findAll('button').find((button) => button.text() === '确认注销');
    expect(confirm?.attributes('disabled')).toBeDefined();
    await wrapper.get('input[placeholder="注销"]').setValue('注销');
    await confirm?.trigger('click');
    await flushPromises();
    expect(clear).toHaveBeenCalledOnce();
    expect(useAuthStore().isAuthenticated).toBe(false);
  });

  it('renders build and platform version status with Web degradation', async () => {
    const wrapper = mount(VersionStatusView);
    await flushPromises();
    expect(wrapper.text()).toContain('当前 H5 版本');
    expect(wrapper.text()).toContain('0.1.0');
    expect(wrapper.text()).toContain('暂无该平台发布记录');
    expect(wrapper.text()).toContain('不在浏览器内下载或安装原生应用');
  });
});
