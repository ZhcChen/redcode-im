import { describe, expect, it } from 'vitest';

const enabled = process.env.H5_APP_LIVE_BACKEND_ENABLED === 'true';
const apiBaseUrl = process.env.H5_APP_API_BASE_URL || 'http://127.0.0.1:8010';

describe.skipIf(!enabled)('h5-app live backend smoke', () => {
  it('registers and logs in with account', async () => {
    const stamp = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const username = `h5_${stamp}`.replace(/[^a-zA-Z0-9._-]/g, '').slice(0, 20);
    const password = `H5pass-${stamp}`;

    const registerResponse = await fetch(`${apiBaseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password, nickname: username }),
    });
    expect(registerResponse.ok).toBe(true);

    const loginResponse = await fetch(`${apiBaseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    expect(loginResponse.ok).toBe(true);

    const payload = (await loginResponse.json()) as { token?: string; user?: { username?: string } };
    expect(payload.token).toBeTruthy();
    expect(payload.user?.username).toBe(username);

    const meResponse = await fetch(`${apiBaseUrl}/auth/me`, {
      headers: { Authorization: `Bearer ${payload.token}` },
    });
    expect(meResponse.ok).toBe(true);
  });
});
