import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it } from 'vitest';

import { appEnv } from '@/config/env';
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
    appEnv.useMockData = true;
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

  it('uploads avatar and persists auth session user', async () => {
    const store = useSettingsStore();
    await store.initialize();

    await store.uploadAvatar(new File(['avatar'], 'avatar.png', { type: 'image/png' }));

    expect(store.user?.avatarObjectKey).toContain('avatars/u1/');
    expect(useAuthStore().currentUser?.avatarObjectKey).toBe(store.user?.avatarObjectKey);
    expect(window.localStorage.getItem('redcode-h5-session')).toContain('avatars/u1/');
    expect(store.notice).toBe('头像已更新');
  });

  it('keeps previous user when avatar validation fails', async () => {
    const store = useSettingsStore();
    await store.initialize();
    const previousUser = { ...store.user };

    await expect(
      store.uploadAvatar(new File(['plain'], 'plain.txt', { type: 'text/plain' })),
    ).rejects.toThrow('头像仅支持图片文件');

    expect(store.user).toEqual(previousUser);
    expect(useAuthStore().currentUser?.avatarObjectKey).toBeUndefined();
    expect(store.error).toBe('头像仅支持图片文件');
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
