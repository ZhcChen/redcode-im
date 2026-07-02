import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it } from 'vitest';

import { useAuthStore } from '@/stores/auth';

describe('auth store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('persists mock login session', async () => {
    const store = useAuthStore();

    await store.login('h5@example.com', 'password');

    expect(store.isAuthenticated).toBe(true);
    expect(store.currentUser?.email).toBe('h5@example.com');
    expect(window.localStorage.getItem('redcode-h5-session')).toContain('h5@example.com');
  });

  it('clears session on logout', async () => {
    const store = useAuthStore();
    await store.login('h5@example.com', 'password');

    store.logout();

    expect(store.isAuthenticated).toBe(false);
    expect(window.localStorage.getItem('redcode-h5-session')).toBeNull();
  });
});
