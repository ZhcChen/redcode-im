import { describe, expect, it } from 'vitest';

import { mapMessageAttachments, messageService } from '@/services/message-service';
import { roomService } from '@/services/room-service';
import type { AuthSession, BackendLoginResponse } from '@/types/auth';
import type { ChatMessage } from '@/types/chat';

const enabled = process.env.H5_APP_LIVE_BACKEND_ENABLED === 'true';
const apiBaseUrl = process.env.H5_APP_API_BASE_URL || 'http://127.0.0.1:8010';

const sessionStorageKey = 'redcode-h5-session';

const registerAndLogin = async (prefix: string): Promise<AuthSession> => {
  const stamp = Math.random().toString(16).slice(2, 10);
  const username = `${prefix}_${stamp}`.replace(/[^a-zA-Z0-9._-]/g, '').slice(0, 20);
  const password = `Interop-${stamp}`;
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

  return mapSession(await loginResponse.json() as BackendLoginResponse);
};

const useH5Session = (session: AuthSession) => {
  window.localStorage.setItem(sessionStorageKey, JSON.stringify(session));
};

const iosSendTextMessage = async (
  session: AuthSession,
  roomId: string,
  content: string,
): Promise<ChatMessage> => {
  const response = await fetch(`${apiBaseUrl}/rooms/${roomId}/messages`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${session.token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ content }),
  });
  expect(response.ok).toBe(true);
  const payload = await response.json() as { message?: Record<string, unknown> } & Record<string, unknown>;
  return mapMessage(payload.message ?? payload, roomId);
};

const iosLoadMessages = async (session: AuthSession, roomId: string): Promise<ChatMessage[]> => {
  const response = await fetch(`${apiBaseUrl}/rooms/${roomId}/messages?limit=20`, {
    headers: { Authorization: `Bearer ${session.token}` },
  });
  expect(response.ok).toBe(true);
  const payload = await response.json() as Record<string, unknown>[];
  return payload.map((row) => mapMessage(row, roomId));
};

const iosMarkMessagesAsRead = async (session: AuthSession, roomId: string, messageId: string) => {
  const response = await fetch(`${apiBaseUrl}/rooms/${roomId}/messages/read`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${session.token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ message_id: messageId }),
  });
  expect(response.ok).toBe(true);
};

describe.skipIf(!enabled)('h5-app ios interop live smoke', () => {
  it('sends and reads messages through H5 service and iOS-compatible HTTP contract', async () => {
    const h5Session = await registerAndLogin('h5-interop');
    const iosSession = await registerAndLogin('ios-interop');
    useH5Session(h5Session);

    const room = await roomService.createGroup({
      name: `ios h5 interop ${Date.now()}`,
      memberIds: [iosSession.user.id],
    });
    const h5Text = `hello from h5 ${Date.now()}`;
    const iosText = `hello from ios ${Date.now()}`;

    const h5Message = await messageService.sendTextMessage(room.id, h5Text);
    const iosMessage = await iosSendTextMessage(iosSession, room.id, iosText);
    const h5VisibleMessages = await messageService.loadMessages(room.id, { limit: 20 });
    const iosVisibleMessages = await iosLoadMessages(iosSession, room.id);

    expect(room.id).toBeTruthy();
    expect(h5Message.content).toBe(h5Text);
    expect(iosMessage.content).toBe(iosText);
    expect(h5VisibleMessages.some((message) => message.id === h5Message.id && message.content === h5Text)).toBe(true);
    expect(h5VisibleMessages.some((message) => message.id === iosMessage.id && message.content === iosText)).toBe(true);
    expect(iosVisibleMessages.some((message) => message.id === h5Message.id && message.content === h5Text)).toBe(true);
    expect(iosVisibleMessages.some((message) => message.id === iosMessage.id && message.content === iosText)).toBe(true);

    await messageService.markMessagesAsRead(room.id, iosMessage.id);
    await iosMarkMessagesAsRead(iosSession, room.id, h5Message.id);
  });

  it('sends H5 rich media messages that iOS-compatible clients can read', async () => {
    const h5Session = await registerAndLogin('h5-media');
    const iosSession = await registerAndLogin('ios-media');
    useH5Session(h5Session);

    const room = await roomService.createGroup({
      name: `h5 ios media ${Date.now()}`,
      memberIds: [iosSession.user.id],
    });
    const payload = `h5-media-smoke-${Date.now()}`;
    const metadata = {
      filename: 'h5-smoke.txt',
      content_type: 'text/plain',
      file_size: new TextEncoder().encode(payload).byteLength,
    };
    const descriptor = await h5Request<Record<string, unknown>>(
      h5Session,
      `/rooms/${room.id}/messages/attachments/signature`,
      {
        method: 'POST',
        body: JSON.stringify({ part_type: 'file', ...metadata }),
      },
    );
    const signature = descriptor.signature as Record<string, unknown> | undefined;
    const uploadUrl = String(signature?.url ?? '');
    expect(uploadUrl).toBeTruthy();

    const uploadResponse = await fetch(uploadUrl, {
      method: String(signature?.method ?? 'PUT'),
      headers: signature?.headers as HeadersInit | undefined,
      body: payload,
    });
    expect(uploadResponse.ok).toBe(true);

    const key = String(descriptor.key ?? signature?.key ?? '');
    expect(key).toBeTruthy();
    await h5Request(
      h5Session,
      `/rooms/${room.id}/messages/attachments/commit`,
      {
        method: 'POST',
        body: JSON.stringify({
          key,
          file_size: metadata.file_size,
        }),
      },
    );

    const h5Message = await messageService.sendRichMessage(room.id, [
      {
        type: 'file',
        key,
        name: metadata.filename,
        mimeType: metadata.content_type,
        size: metadata.file_size,
      },
    ]);
    const iosVisibleMessages = await iosLoadMessages(iosSession, room.id);

    expect(h5Message.attachments?.[0]?.key).toBe(key);
    expect(iosVisibleMessages.some((message) => message.id === h5Message.id && message.attachments?.[0]?.key === key)).toBe(true);
  });
});

const h5Request = async <T = unknown>(
  session: AuthSession,
  path: string,
  init: RequestInit = {},
): Promise<T> => {
  const headers = new Headers(init.headers);
  headers.set('Authorization', `Bearer ${session.token}`);
  headers.set('Content-Type', 'application/json');
  const response = await fetch(`${apiBaseUrl}${path}`, {
    ...init,
    headers,
  });
  expect(response.ok).toBe(true);
  return response.json() as Promise<T>;
};

const mapSession = (response: BackendLoginResponse): AuthSession => {
  const username = response.user.username ?? response.user.email ?? response.user.id ?? 'interop-user';
  return {
    token: response.token,
    refreshToken: response.refresh_token ?? null,
    user: {
      id: response.user.id ?? username,
      username,
      nickname: response.user.nickname ?? username,
      email: response.user.email ?? '',
      status: response.user.status ?? 'active',
      avatarUrl: response.user.avatar_url ?? null,
      avatarObjectKey: response.user.avatar_object_key ?? null,
    },
  };
};

const mapMessage = (row: Record<string, unknown>, fallbackRoomId: string): ChatMessage => ({
  id: String(row.id ?? row.message_id ?? ''),
  roomId: String(row.room_id ?? fallbackRoomId),
  senderId: String(row.sender_id ?? ''),
  senderName: String(row.sender_name ?? row.sender_nickname ?? row.sender_username ?? ''),
  content: String(row.content ?? ''),
  type: String(row.message_type ?? row.type ?? 'text') as ChatMessage['type'],
  timestamp: Date.parse(String(row.created_at ?? row.timestamp ?? new Date().toISOString())),
  isDeleted: Boolean(row.is_deleted ?? false),
  isPinned: Boolean(row.is_pinned ?? false),
  attachments: mapMessageAttachments(row.parts ?? row.attachments),
  raw: row,
});
