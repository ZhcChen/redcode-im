import { describe, expect, it, vi } from 'vitest';

import { loginWithEmail, registerWithEmail } from '@/api/auth';

describe('auth api', () => {
  it('normalizes mock email login responses', async () => {
    const session = await loginWithEmail(' Bear@Example.COM ', 'password', true);

    expect(session.token).toBe('mock-token');
    expect(session.user.email).toBe('bear@example.com');
    expect(session.user.nickname).toBe('bear');
  });

  it('calls backend register with nickname equal to normalized email', async () => {
    const fetchMock = vi.fn(async () => {
      return new Response(
        JSON.stringify({
          id: 'u1',
          username: 'new@example.com',
          email: 'new@example.com',
          nickname: 'new@example.com',
          status: 'active',
        }),
        { status: 200 },
      );
    });
    vi.stubGlobal('fetch', fetchMock);

    const user = await registerWithEmail(' New@Example.COM ', 'secret');

    expect(user.email).toBe('new@example.com');
    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8010/auth/register',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          email: 'new@example.com',
          password: 'secret',
          nickname: 'new@example.com',
        }),
      }),
    );
  });
});
