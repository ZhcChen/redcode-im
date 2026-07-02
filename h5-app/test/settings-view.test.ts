import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { useAuthStore } from '@/stores/auth';
import AboutView from '@/views/settings/AboutView.vue';
import DocumentView from '@/views/settings/DocumentView.vue';
import FeedbackView from '@/views/settings/FeedbackView.vue';
import ProfileSettingsView from '@/views/settings/ProfileSettingsView.vue';

const routeName = vi.hoisted(() => ({ value: 'privacy-policy' }));

vi.mock('vue-router', () => ({
  useRoute: () => ({
    get name() {
      return routeName.value;
    },
  }),
  useRouter: () => ({
    push: vi.fn(),
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
    expect(wrapper.find('input[placeholder="输入昵称"]').exists()).toBe(true);
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
});
