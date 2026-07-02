import { describe, expect, it } from 'vitest';

import { authService } from '@/services/auth-service';
import { friendService } from '@/services/friend-service';
import { messageService } from '@/services/message-service';
import { roomService } from '@/services/room-service';
import { settingsService } from '@/services/settings-service';

const enabled = process.env.H5_APP_LIVE_BACKEND_ENABLED === 'true';
const apiBaseUrl = process.env.H5_APP_API_BASE_URL || 'http://127.0.0.1:8010';

const registerAndLogin = async (prefix: string) => {
  const stamp = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const email = `${prefix}-${stamp}@example.com`;
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
  const session = await loginResponse.json();
  window.localStorage.setItem('redcode-h5-session', JSON.stringify(session));
  return { email, password, session };
};

describe.skipIf(!enabled)('h5-app live service smoke', () => {
  it('uses service layer for auth, settings, friends, rooms and messages', async () => {
    const owner = await registerAndLogin('h5-owner');
    const member = await registerAndLogin('h5-member');

    window.localStorage.setItem('redcode-h5-session', JSON.stringify(owner.session));

    const me = await authService.me();
    expect(me?.email).toBe(owner.email);

    const settings = await settingsService.fetchGeneralSettings();
    expect(settings.messageRuntime.serverStorageMode).toBeTruthy();

    const users = await friendService.searchUsers(member.email, 5);
    expect(users.some((user) => user.email === member.email)).toBe(true);

    const room = await roomService.createGroup({
      name: 'h5 service smoke',
      memberIds: [member.session.user.id],
    });
    expect(room.id).toBeTruthy();

    const sent = await messageService.sendTextMessage(room.id, 'hello from h5 service');
    expect(sent.roomId).toBe(room.id);
    expect(sent.content).toBe('hello from h5 service');

    const messages = await messageService.loadMessages(room.id, { limit: 20 });
    expect(messages.some((message) => message.content === 'hello from h5 service')).toBe(true);

    const chats = await messageService.fetchChats();
    expect(chats.some((chat) => chat.roomId === room.id)).toBe(true);
  });
});
