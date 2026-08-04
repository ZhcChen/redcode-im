import { describe, expect, it } from 'vitest';

import { friendService } from '@/services/friend-service';
import { mapMessageAttachments, messageService } from '@/services/message-service';
import { messageAttachmentUploadService } from '@/services/message-attachment-upload-service';
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

const iosRequestJson = async <T>(
  session: AuthSession,
  path: string,
  init: RequestInit = {},
): Promise<T> => {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${session.token}`,
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...init.headers,
    },
  });
  expect(response.ok).toBe(true);
  return response.json() as Promise<T>;
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

    const readers = await messageService.fetchMessageReaders(room.id, h5Message.id);
    expect(readers.some((reader) => reader.userId === iosSession.user.id)).toBe(true);

    const forwardTarget = await roomService.createGroup({
      name: `ios h5 forward ${Date.now()}`,
      memberIds: [iosSession.user.id],
    });
    const forwarded = await messageService.forwardMessage(forwardTarget.id, h5Message.id);
    const iosForwardedMessages = await iosLoadMessages(iosSession, forwardTarget.id);
    expect(forwarded.roomId).toBe(forwardTarget.id);
    expect(forwarded.content).toBe(h5Text);
    expect(forwarded.forwardInfo).toMatchObject({
      messageId: h5Message.id,
      senderId: h5Session.user.id,
    });
    expect(iosForwardedMessages.some((message) => message.id === forwarded.id && message.content === h5Text)).toBe(true);
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
    const part = await messageAttachmentUploadService.upload(
      room.id,
      new File([payload], 'h5-smoke.txt', { type: 'text/plain' }),
      'file',
    );
    const h5Message = await messageService.sendRichMessage(room.id, [part]);
    const iosVisibleMessages = await iosLoadMessages(iosSession, room.id);

    expect(h5Message.attachments?.[0]?.key).toBe(part.key);
    expect(iosVisibleMessages.some((message) => message.id === h5Message.id && message.attachments?.[0]?.key === part.key)).toBe(true);
  });

  it('keeps H5 and iOS-compatible friend state interoperable after refresh', async () => {
    const h5Session = await registerAndLogin('h5-friend');
    const iosSession = await registerAndLogin('ios-friend');
    useH5Session(h5Session);

    const sentRequest = await friendService.sendFriendRequest(iosSession.user.id, 'hello from h5');
    const incoming = await iosRequestJson<Array<Record<string, unknown>>>(
      iosSession,
      '/friends/requests?direction=incoming&status=pending',
    );
    expect(incoming.some((request) => {
      const requester = request.requester as Record<string, unknown> | undefined;
      return request.id === sentRequest.id && requester?.id === h5Session.user.id;
    })).toBe(true);

    const accepted = await iosRequestJson<Record<string, unknown>>(
      iosSession,
      `/friends/requests/${sentRequest.id}/respond`,
      { method: 'POST', body: JSON.stringify({ action: 'accept' }) },
    );
    expect(String(accepted.id)).toBe(sentRequest.id);

    useH5Session(h5Session);
    const h5Friends = await friendService.fetchFriends();
    expect(h5Friends.some((friend) => friend.user.id === iosSession.user.id)).toBe(true);
  });

  it('shares approved membership and H5 group governance with iOS-compatible clients', async () => {
    const ownerSession = await registerAndLogin('h5-owner');
    const iosSession = await registerAndLogin('ios-joiner');
    const seedMemberSession = await registerAndLogin('h5-seed');
    useH5Session(ownerSession);

    const room = await roomService.createGroup({
      name: `h5 governed group ${Date.now()}`,
      memberIds: [seedMemberSession.user.id],
    });
    const approvalSettings = await roomService.updateJoinApproval(room.id, true);
    expect(approvalSettings.joinApprovalRequired).toBe(true);

    const created = await iosRequestJson<{ request: Record<string, unknown> }>(
      iosSession,
      `/rooms/${room.id}/join-requests`,
      { method: 'POST', body: JSON.stringify({ message: 'join from ios' }) },
    );
    const requestId = String(created.request.id);
    expect(requestId).toBeTruthy();

    useH5Session(ownerSession);
    const pendingRequests = await roomService.listJoinRequests(room.id);
    expect(pendingRequests.some((request) => request.id === requestId && request.applicantId === iosSession.user.id)).toBe(true);
    const reviewed = await roomService.reviewJoinRequest(room.id, requestId, 'approved', 'approved by h5');
    expect(reviewed.status).toBe('approved');

    await iosRequestJson<Record<string, unknown>>(iosSession, `/rooms/${room.id}/join`, { method: 'POST' });

    const rule = await roomService.createRule(room.id, {
      title: 'Cross-platform rule',
      content: 'State must be visible after refresh',
      orderIndex: 0,
    });
    const members = await iosRequestJson<Array<Record<string, unknown>> | { members?: Array<Record<string, unknown>> }>(
      iosSession,
      `/rooms/${room.id}/members`,
    );
    const memberRows = Array.isArray(members) ? members : members.members ?? [];
    expect(memberRows.some((member) => member.user_id === iosSession.user.id)).toBe(true);

    const rules = await iosRequestJson<{ rules?: Array<Record<string, unknown>> }>(iosSession, `/rooms/${room.id}/rules`);
    expect(rules.rules?.some((item) => item.id === rule.id && item.title === 'Cross-platform rule')).toBe(true);
  });
});

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
