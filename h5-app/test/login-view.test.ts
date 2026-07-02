import { mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import LoginView from '@/views/LoginView.vue';

vi.mock('vue-router', () => ({
  useRouter: () => ({
    replace: vi.fn(),
  }),
}));

const pushText = async (wrapper: ReturnType<typeof mount>, selector: string, value: string) => {
  await wrapper.find(selector).setValue(value);
};

describe('LoginView', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('validates agreement before submitting', async () => {
    const wrapper = mount(LoginView, {
      global: { stubs: ['RouterLink'] },
    });

    await pushText(wrapper, 'input[type="email"]', 'h5@example.com');
    await pushText(wrapper, 'input[type="password"]', 'password');
    await wrapper.find('form').trigger('submit');

    expect(wrapper.text()).toContain('请勾选并阅读');
  });

  it('switches to register mode', async () => {
    const wrapper = mount(LoginView);

    await wrapper.findAll('.login-card__tab')[1].trigger('click');

    expect(wrapper.text()).toContain('注册账号');
    expect(wrapper.find('input[type="password"]').attributes('placeholder')).toBe('请设置您的登录密码');
  });
});
