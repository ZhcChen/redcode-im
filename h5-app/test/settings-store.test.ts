import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it } from 'vitest';

import { useAuthStore } from '@/stores/auth';
import { useSettingsStore } from '@/stores/settings';

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
  window.localStorage.setItem('redcode-h5-session', JSON.stringify(authStore.session));
};

describe('settings store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    seedSession();
  });

  it('loads current user and general settings in mock mode', async () => {
    const store = useSettingsStore();

    await store.initialize();

    expect(store.displayName).toBe('U1');
    expect(store.general?.appName).toBe('RedCode IM');
  });

  it('updates nickname and persists auth session user', async () => {
    const store = useSettingsStore();
    await store.initialize();
    store.nicknameDraft = 'New Name';

    await store.updateNickname();

    expect(store.user?.nickname).toBe('New Name');
    expect(useAuthStore().currentUser?.nickname).toBe('New Name');
    expect(window.localStorage.getItem('redcode-h5-session')).toContain('New Name');
  });

  it('changes password and clears password inputs', async () => {
    const store = useSettingsStore();
    store.oldPassword = 'old-pass';
    store.newPassword = 'new-pass';

    await store.changePassword();

    expect(store.oldPassword).toBe('');
    expect(store.newPassword).toBe('');
    expect(store.notice).toBe('密码已更新');
  });

  it('loads policy documents and submits feedback', async () => {
    const store = useSettingsStore();

    await store.loadDocument('privacy');
    store.feedbackContent = 'H5 feedback';
    await store.submitFeedback();

    expect(store.privacyPolicy?.title).toBe('隐私协议');
    expect(store.feedbackContent).toBe('');
    expect(store.notice).toContain('反馈提交成功');
  });
});
