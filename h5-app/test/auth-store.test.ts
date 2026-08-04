import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { useAuthStore } from '@/stores/auth';
import { accountDataService } from '@/services/account-data-service';

describe('auth store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    useAuthStore().stopSessionSync();
  });

  it('persists mock login session', async () => {
    const store = useAuthStore();

    await store.login('h5_user', 'password');

    expect(store.isAuthenticated).toBe(true);
    expect(store.currentUser?.username).toBe('h5_user');
    expect(window.localStorage.getItem('redcode-h5-session')).toContain('h5_user');
  });

  it('clears session on logout', async () => {
    const store = useAuthStore();
    await store.login('h5_user', 'password');

    await store.logout();

    expect(store.isAuthenticated).toBe(false);
    expect(window.localStorage.getItem('redcode-h5-session')).toBeNull();
  });

  it('clears account-scoped cache when switching users', async () => {
    const store = useAuthStore();
    await store.login('first_user', 'password');
    const clear = vi.spyOn(accountDataService, 'clearAll').mockResolvedValue();
    await store.login('second_user', 'password');
    expect(clear).toHaveBeenCalledOnce();
    expect(clear).toHaveBeenCalledWith('mock-user-first_user');
  });

  it('synchronizes login updates and logout from another browser tab', () => {
    const store = useAuthStore();
    store.startSessionSync();
    const session = { token: 'other-token', user: { id: 'u2', username: 'other', nickname: 'Other', email: 'other@example.com' } };
    window.dispatchEvent(new StorageEvent('storage', { key: 'redcode-h5-session', newValue: JSON.stringify(session) }));
    expect(store.session).toEqual(session);

    window.dispatchEvent(new StorageEvent('storage', { key: 'redcode-h5-session', newValue: null }));
    expect(store.isAuthenticated).toBe(false);
    store.stopSessionSync();
  });

  it('invalidates malformed cross-tab session data', () => {
    const store = useAuthStore();
    store.startSessionSync();
    window.dispatchEvent(new StorageEvent('storage', { key: 'redcode-h5-session', newValue: '{invalid' }));
    expect(store.isAuthenticated).toBe(false);
    expect(store.error).toBe('登录状态已失效');
    store.stopSessionSync();
  });
});
