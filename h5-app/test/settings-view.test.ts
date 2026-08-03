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
});
