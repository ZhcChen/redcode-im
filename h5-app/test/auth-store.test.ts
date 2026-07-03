import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it } from 'vitest';

import { useAuthStore } from '@/stores/auth';

describe('auth store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
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

    store.logout();

    expect(store.isAuthenticated).toBe(false);
    expect(window.localStorage.getItem('redcode-h5-session')).toBeNull();
  });
});
