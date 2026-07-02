import { describe, expect, it } from 'vitest';

const enabled = process.env.H5_APP_LIVE_BACKEND_ENABLED === 'true';
const apiBaseUrl = process.env.H5_APP_API_BASE_URL || 'http://127.0.0.1:8010';

describe.skipIf(!enabled)('h5-app live backend smoke', () => {
  it('registers and logs in with email', async () => {
    const stamp = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const email = `h5-${stamp}@example.com`;
    const password = `H5pass-${stamp}`;

    const registerResponse = await fetch(`${apiBaseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, nickname: email }),
    });
    expect(registerResponse.ok).toBe(true);

    const loginResponse = await fetch(`${apiBaseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    expect(loginResponse.ok).toBe(true);

    const payload = (await loginResponse.json()) as { token?: string; user?: { email?: string } };
    expect(payload.token).toBeTruthy();
    expect(payload.user?.email).toBe(email);
  });
});
