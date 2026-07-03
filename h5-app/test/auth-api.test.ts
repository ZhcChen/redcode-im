import { describe, expect, it, vi } from 'vitest';

import { loginWithAccount, registerWithAccount } from '@/api/auth';

describe('auth api', () => {
  it('normalizes mock account login responses', async () => {
    const session = await loginWithAccount(' Bear_01 ', 'password', true);

    expect(session.token).toBe('mock-token');
    expect(session.user.username).toBe('bear_01');
    expect(session.user.email).toBe('bear_01@account.redcode.local');
    expect(session.user.nickname).toBe('bear_01');
  });

  it('calls backend register with username and no email dependency', async () => {
    const fetchMock = vi.fn(async () => {
      return new Response(
        JSON.stringify({
          id: 'u1',
          username: 'new_user',
          email: 'new_user@account.redcode.local',
          nickname: 'new_user',
          status: 'active',
        }),
        { status: 200 },
      );
    });
    vi.stubGlobal('fetch', fetchMock);

    const user = await registerWithAccount(' New_User ', 'secret');

    expect(user.username).toBe('new_user');
    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8010/auth/register',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          username: 'new_user',
          password: 'secret',
          nickname: 'new_user',
        }),
      }),
    );
  });
});
