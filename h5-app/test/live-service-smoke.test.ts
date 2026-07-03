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
  const username = `${prefix}_${stamp}`.replace(/[^a-zA-Z0-9._-]/g, '').slice(0, 20);
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
  const session = await loginResponse.json();
  window.localStorage.setItem('redcode-h5-session', JSON.stringify(session));
  return { username, password, session };
};

describe.skipIf(!enabled)('h5-app live service smoke', () => {
  it('uses service layer for auth, settings, friends, rooms and messages', async () => {
    const owner = await registerAndLogin('h5-owner');
    const member = await registerAndLogin('h5-member');

    window.localStorage.setItem('redcode-h5-session', JSON.stringify(owner.session));

    const me = await authService.me();
    expect(me?.username).toBe(owner.username);
    const updatedMe = await authService.updateProfile({ nickname: `H5 ${Date.now()}` });
    expect(updatedMe.username).toBe(owner.username);
    const refreshedMe = await authService.me();
    expect(refreshedMe?.nickname).toBe(updatedMe.nickname);

    const settings = await settingsService.fetchGeneralSettings();
    expect(settings.messageRuntime.serverStorageMode).toBeTruthy();

    const users = await friendService.searchUsers(member.username, 5);
    expect(users.some((user) => user.username === member.username)).toBe(true);

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
    await messageService.markMessagesAsRead(room.id, sent.id);

    const chats = await messageService.fetchChats();
    expect(chats.some((chat) => chat.roomId === room.id)).toBe(true);
  });
});
