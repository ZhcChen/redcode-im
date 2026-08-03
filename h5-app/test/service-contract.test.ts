import { beforeEach, describe, expect, it, vi } from 'vitest';

import { authService } from '@/services/auth-service';
import { avatarUploadService } from '@/services/avatar-upload-service';
import { friendService } from '@/services/friend-service';
import { messageService } from '@/services/message-service';
import { roomService } from '@/services/room-service';
import { settingsService } from '@/services/settings-service';

const saveSession = () => {
  window.localStorage.setItem(
    'redcode-h5-session',
    JSON.stringify({
      token: 'token-1',
      user: {
        id: 'u1',
        username: 'u1@example.com',
        nickname: 'u1',
        email: 'u1@example.com',
      },
    }),
  );
};

const mockJson = (payload: unknown, status = 200) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

describe('h5 app service contracts', () => {
  beforeEach(() => {
    saveSession();
  });

  it('searches users with auth token and query params', async () => {
    let capturedInit: RequestInit | undefined;
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      capturedInit = init;
      return mockJson([
        {
          id: 'u2',
          username: 'bear@example.com',
          email: 'bear@example.com',
          nickname: 'Bear',
        },
      ]);
    });
    vi.stubGlobal('fetch', fetchMock);

    const users = await friendService.searchUsers('bear', 10);

    expect(users[0]?.email).toBe('bear@example.com');
    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8010/users/search?keyword=bear&limit=10',
      expect.objectContaining({
        headers: expect.any(Headers),
      }),
    );
    const headers = capturedInit?.headers as Headers;
    expect(headers.get('Authorization')).toBe('Bearer token-1');
  });

  it('creates a group with Flutter-compatible payload', async () => {
    const fetchMock = vi.fn(async () =>
      mockJson({
        room: {
          id: 'r1',
          name: '项目组',
          room_type: 'group',
          owner_id: 'u1',
        },
      }),
    );
    vi.stubGlobal('fetch', fetchMock);

    const room = await roomService.createGroup({
      name: ' 项目组 ',
      memberIds: ['u2', 'u3'],
    });

    expect(room.id).toBe('r1');
    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8010/rooms',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          name: '项目组',
          room_type: 'group',
          member_ids: ['u2', 'u3'],
        }),
      }),
    );
  });

  it('lists, appoints, and removes group admins with backend-compatible contracts', async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      if (init?.method === 'DELETE') return new Response(null, { status: 204 });
      const admin = {
        id: 'ga1', room_id: 'r1', admin_id: 'u2', appointed_by: 'u1',
        role: 'admin', permissions: ['manage_members'], appointed_at: '2026-08-04T00:00:00Z',
      };
      return mockJson(init?.method === 'POST' ? { admin } : { admins: [admin] });
    });
    vi.stubGlobal('fetch', fetchMock);

    const admins = await roomService.listAdmins('r1');
    const appointed = await roomService.appointAdmin('r1', 'u2');
    await roomService.removeAdmin('r1', 'u2');

    expect(admins[0]).toMatchObject({ adminId: 'u2', permissions: ['manage_members'] });
    expect(appointed.appointedBy).toBe('u1');
    expect(fetchMock).toHaveBeenNthCalledWith(2, 'http://127.0.0.1:8010/rooms/r1/admins', expect.objectContaining({
      method: 'POST', body: JSON.stringify({ user_id: 'u2', role: 'admin' }),
    }));
    expect(fetchMock).toHaveBeenNthCalledWith(3, 'http://127.0.0.1:8010/rooms/r1/admins/u2', expect.objectContaining({ method: 'DELETE' }));
  });

  it('runs group rule CRUD with backend-compatible payloads', async () => {
    const rule = {
      id: 'rule1', room_id: 'r1', title: '文明交流', content: '禁止人身攻击', creator_id: 'u1',
      order_index: 0, is_active: true, created_at: '2026-08-04T00:00:00Z', updated_at: '2026-08-04T00:00:00Z',
    };
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      if (init?.method === 'DELETE') return new Response(null, { status: 204 });
      return mockJson(init?.method ? { rule } : { rules: [rule] });
    });
    vi.stubGlobal('fetch', fetchMock);

    const rules = await roomService.listRules('r1');
    await roomService.createRule('r1', { title: ' 文明交流 ', content: ' 禁止人身攻击 ', orderIndex: 0 });
    await roomService.updateRule('r1', 'rule1', { title: '友善交流', content: '尊重他人' });
    await roomService.deleteRule('r1', 'rule1');

    expect(rules[0]).toMatchObject({ id: 'rule1', orderIndex: 0, isActive: true });
    expect(fetchMock).toHaveBeenNthCalledWith(2, 'http://127.0.0.1:8010/rooms/r1/rules', expect.objectContaining({
      method: 'POST', body: JSON.stringify({ title: '文明交流', content: '禁止人身攻击', order_index: 0 }),
    }));
    expect(fetchMock).toHaveBeenNthCalledWith(3, 'http://127.0.0.1:8010/rooms/r1/rules/rule1', expect.objectContaining({
      method: 'PATCH', body: JSON.stringify({ title: '友善交流', content: '尊重他人' }),
    }));
    expect(fetchMock).toHaveBeenNthCalledWith(4, 'http://127.0.0.1:8010/rooms/r1/rules/rule1', expect.objectContaining({ method: 'DELETE' }));
  });

  it('manages member and global mute state with backend-compatible payloads', async () => {
    const mute = {
      id: 'mute1', room_id: 'r1', user_id: 'u2', muted_by: 'u1', reason: '刷屏',
      mute_duration_hours: 24, muted_at: '2026-08-04T00:00:00Z', unmuted_at: null, is_active: true,
    };
    const fetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      if (init?.method === 'DELETE') return new Response(null, { status: 204 });
      if (String(input).endsWith('/global')) return mockJson({ settings: { room_id: 'r1', global_mute_enabled: true } });
      return mockJson(init?.method === 'POST' ? { mute } : { mutes: [mute] });
    });
    vi.stubGlobal('fetch', fetchMock);

    const mutes = await roomService.listMutes('r1');
    await roomService.muteUser('r1', { userId: 'u2', durationHours: 24, reason: ' 刷屏 ' });
    await roomService.unmuteUser('r1', 'u2');
    const settings = await roomService.updateGlobalMute('r1', { enabled: true, reason: '集中讨论', durationMinutes: 60 });

    expect(mutes[0]).toMatchObject({ userId: 'u2', muteDurationHours: 24, isActive: true });
    expect(settings.globalMuteEnabled).toBe(true);
    expect(fetchMock).toHaveBeenNthCalledWith(2, 'http://127.0.0.1:8010/rooms/r1/mutes', expect.objectContaining({
      method: 'POST', body: JSON.stringify({ user_id: 'u2', duration_hours: 24, reason: '刷屏' }),
    }));
    expect(fetchMock).toHaveBeenNthCalledWith(3, 'http://127.0.0.1:8010/rooms/r1/mutes/u2', expect.objectContaining({ method: 'DELETE' }));
    expect(fetchMock).toHaveBeenNthCalledWith(4, 'http://127.0.0.1:8010/rooms/r1/mutes/global', expect.objectContaining({
      method: 'POST', body: JSON.stringify({ enabled: true, reason: '集中讨论', duration_minutes: 60 }),
    }));
  });

  it('creates, reviews, and completes approved group join requests', async () => {
    const joinRequest = {
      id: 'jr1', room_id: 'r1', applicant_id: 'u2', message: '申请加入', status: 0,
      reviewer_id: null, review_message: null, created_at: '2026-08-04T00:00:00Z', reviewed_at: null,
    };
    const fetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      if (url.endsWith('/join')) return mockJson({ ok: true });
      if (url.endsWith('/review')) return mockJson({ request: { ...joinRequest, status: 1 } });
      if (url.endsWith('/settings')) return mockJson({ settings: { room_id: 'r1', join_approval_required: true } });
      return mockJson(init?.method === 'POST' ? { request: joinRequest } : { requests: [joinRequest] });
    });
    vi.stubGlobal('fetch', fetchMock);

    const requests = await roomService.listJoinRequests('r1');
    await roomService.createJoinRequest('r1', ' 申请加入 ');
    const approved = await roomService.reviewJoinRequest('r1', 'jr1', 'approved', ' 欢迎 ');
    await roomService.joinRoom('r1');
    await roomService.updateJoinApproval('r1', true);

    expect(requests[0]?.status).toBe('pending');
    expect(approved.status).toBe('approved');
    expect(fetchMock).toHaveBeenNthCalledWith(3, 'http://127.0.0.1:8010/rooms/r1/join-requests/jr1/review', expect.objectContaining({
      method: 'POST', body: JSON.stringify({ status: 'approved', review_message: '欢迎' }),
    }));
    expect(fetchMock).toHaveBeenNthCalledWith(4, 'http://127.0.0.1:8010/rooms/r1/join', expect.objectContaining({ method: 'POST' }));
    expect(fetchMock).toHaveBeenNthCalledWith(5, 'http://127.0.0.1:8010/rooms/r1/settings', expect.objectContaining({
      method: 'PATCH', body: JSON.stringify({ join_approval_required: true }),
    }));
  });

  it('creates, lists, and responds to group invitations', async () => {
    const invitation = {
      id: 'gi1', room_id: 'r1', room_name: '项目群', room_avatar_url: null,
      inviter_id: 'u1', inviter_name: 'Owner', invitee_id: 'u2', message: '欢迎加入',
      status: 0, invited_at: '2026-08-04T00:00:00Z', responded_at: null, expires_at: '2026-08-11T00:00:00Z',
    };
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      if (init?.method === 'PATCH') return new Response(null, { status: 204 });
      return mockJson(init?.method === 'POST' ? { invitations: [invitation] } : { invitations: [invitation] });
    });
    vi.stubGlobal('fetch', fetchMock);

    const received = await roomService.listReceivedInvitations('all');
    await roomService.createInvitations('r1', ['u2'], ' 欢迎加入 ');
    await roomService.respondToInvitation('r1', 'gi1', 'accepted');

    expect(received[0]).toMatchObject({ roomName: '项目群', inviterName: 'Owner', status: 'pending' });
    expect(fetchMock).toHaveBeenNthCalledWith(1, 'http://127.0.0.1:8010/group-invitations?status=all', expect.any(Object));
    expect(fetchMock).toHaveBeenNthCalledWith(2, 'http://127.0.0.1:8010/rooms/r1/invitations', expect.objectContaining({
      method: 'POST', body: JSON.stringify({ user_ids: ['u2'], message: '欢迎加入' }),
    }));
    expect(fetchMock).toHaveBeenNthCalledWith(3, 'http://127.0.0.1:8010/rooms/r1/invitations/gi1/respond', expect.objectContaining({
      method: 'PATCH', body: JSON.stringify({ status: 'accepted' }),
    }));
  });

  it('maps paginated group operation logs', async () => {
    const fetchMock = vi.fn(async () => mockJson({ logs: [{
      id: 'log1', room_id: 'r1', operator_id: 'u1', target_user_id: 'u2',
      operation_type: 'mute_user', operation_data: { reason: '刷屏' }, created_at: '2026-08-04T00:00:00Z',
    }], total: 1 }));
    vi.stubGlobal('fetch', fetchMock);

    const logs = await roomService.listOperationLogs('r1', 20, 40);

    expect(logs[0]).toMatchObject({ roomId: 'r1', operatorId: 'u1', targetUserId: 'u2', operationType: 'mute_user' });
    expect(fetchMock).toHaveBeenCalledWith('http://127.0.0.1:8010/rooms/r1/operation-logs?limit=20&offset=40', expect.any(Object));
  });

  it('deactivates the authenticated account', async () => {
    const fetchMock = vi.fn(async () => mockJson({ success: true }));
    vi.stubGlobal('fetch', fetchMock);
    await authService.deactivateAccount();
    expect(fetchMock).toHaveBeenCalledWith('http://127.0.0.1:8010/users/me', expect.objectContaining({ method: 'DELETE' }));
  });

  it('checks the latest platform version using the H5 build version', async () => {
    const fetchMock = vi.fn(async () => mockJson({
      has_update: true,
      current_version: '0.1.0',
      version: { version: '2.0.0', release_notes: '稳定性更新', mandatory: false, app_store_url: 'https://store.invalid/app' },
    }));
    vi.stubGlobal('fetch', fetchMock);
    const status = await settingsService.fetchVersionStatus('ios');
    expect(status).toMatchObject({ platform: 'ios', currentVersion: '0.1.0', latestVersion: '2.0.0', hasUpdate: true });
    expect(fetchMock).toHaveBeenCalledWith('http://127.0.0.1:8010/versions/latest?platform=ios&channel=stable&current_version=0.1.0', expect.any(Object));
  });

  it('fetches and responds to friend requests with Flutter-compatible routes', async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes('/respond')) {
        return mockJson({
          id: 'req1',
          requester_id: 'u2',
          target_user_id: 'u1',
          status: 'accepted',
        });
      }
      return mockJson([
        {
          id: 'req1',
          requester_id: 'u2',
          target_user_id: 'u1',
          status: 'pending',
          requester: {
            id: 'u2',
            username: 'bear@example.com',
            email: 'bear@example.com',
            nickname: 'Bear',
          },
        },
      ]);
    });
    vi.stubGlobal('fetch', fetchMock);

    const requests = await friendService.fetchFriendRequests({ direction: 'incoming', status: 'pending' });
    const accepted = await friendService.respondFriendRequest('req1', 'accept');

    expect(requests[0]).toMatchObject({
      id: 'req1',
      requesterId: 'u2',
      requester: expect.objectContaining({ nickname: 'Bear' }),
    });
    expect(accepted.status).toBe('accepted');
    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      'http://127.0.0.1:8010/friends/requests?direction=incoming&status=pending',
      expect.any(Object),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      'http://127.0.0.1:8010/friends/requests/req1/respond',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ action: 'accept' }),
      }),
    );
  });

  it('declines friend requests with backend-compatible action', async () => {
    const fetchMock = vi.fn(async () =>
      mockJson({
        id: 'req1',
        requester_id: 'u2',
        target_user_id: 'u1',
        status: 'declined',
      }),
    );
    vi.stubGlobal('fetch', fetchMock);

    const declined = await friendService.respondFriendRequest('req1', 'decline');

    expect(declined.status).toBe('declined');
    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8010/friends/requests/req1/respond',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ action: 'decline' }),
      }),
    );
  });

  it('loads friends and ensures private chats through friend routes', async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.endsWith('/chat')) {
        return mockJson({ room_id: 'r1', room_type: 'private', created: true });
      }
      return mockJson([
        {
          id: 'f1',
          user: {
            id: 'u2',
            username: 'bear@example.com',
            email: 'bear@example.com',
            nickname: 'Bear',
          },
          created_at: '2026-07-02T00:00:00Z',
        },
      ]);
    });
    vi.stubGlobal('fetch', fetchMock);

    const friends = await friendService.fetchFriends();
    const chat = await friendService.ensurePrivateChat('u2');

    expect(friends[0]?.user.nickname).toBe('Bear');
    expect(chat).toMatchObject({ roomId: 'r1', roomType: 'private', created: true });
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      'http://127.0.0.1:8010/friends/u2/chat',
      expect.objectContaining({ method: 'POST' }),
    );
  });

  it('loads messages with pagination params and maps timestamps', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () =>
        mockJson([
          {
            id: 'm1',
            room_id: 'r1',
            sender_id: 'u2',
            sender_name: 'Bear',
            content: 'hello',
            message_type: 'text',
            created_at: '2026-07-02T01:00:00Z',
          },
        ]),
      ),
    );

    const messages = await messageService.loadMessages('r1', {
      limit: 20,
      beforeId: 'm2',
    });

    expect(messages[0]).toMatchObject({
      id: 'm1',
      roomId: 'r1',
      senderName: 'Bear',
      content: 'hello',
      type: 'text',
    });
    expect(messages[0]?.timestamp).toBe(Date.parse('2026-07-02T01:00:00Z'));
  });

  it('maps backend message parts to H5 attachments', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () =>
        mockJson([
          {
            id: 'm1',
            room_id: 'r1',
            sender_id: 'u2',
            sender_name: 'Bear',
            content: '',
            message_type: 'image',
            created_at: '2026-07-02T01:00:00Z',
            parts: [
              {
                position: 0,
                part_type: 'image',
                attachment: {
                  key: 'messages/r1/images/a.png',
                  name: 'a.png',
                  mime: 'image/png',
                  size: 123,
                },
              },
            ],
          },
        ]),
      ),
    );

    const messages = await messageService.loadMessages('r1');

    expect(messages[0]?.attachments).toEqual([
      {
        key: 'messages/r1/images/a.png',
        name: 'a.png',
        mimeType: 'image/png',
        size: 123,
        cacheKey: 'message:messages/r1/images/a.png',
      },
    ]);
  });

  it('sends rich message payloads with backend-compatible parts', async () => {
    let capturedInit: RequestInit | undefined;
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      capturedInit = init;
      return mockJson({
        message: {
          id: 'm-rich',
          room_id: 'r1',
          sender_id: 'u1',
          sender_name: 'U1',
          content: '',
          message_type: 'image',
          created_at: '2026-07-02T01:00:00Z',
          parts: [
            {
              position: 0,
              part_type: 'image',
              attachment: {
                key: 'messages/r1/images/a.png',
                name: 'a.png',
                mime: 'image/png',
                size: 123,
              },
            },
          ],
        },
      });
    });
    vi.stubGlobal('fetch', fetchMock);

    const message = await messageService.sendRichMessage('r1', [
      {
        type: 'image',
        key: 'messages/r1/images/a.png',
        name: 'a.png',
        mimeType: 'image/png',
        size: 123,
      },
    ]);

    expect(message.attachments?.[0]?.key).toBe('messages/r1/images/a.png');
    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8010/rooms/r1/messages',
      expect.objectContaining({ method: 'POST' }),
    );
    expect(JSON.parse(String(capturedInit?.body))).toEqual({
      parts: [
        {
          type: 'image',
          key: 'messages/r1/images/a.png',
          name: 'a.png',
          mime: 'image/png',
          size: 123,
        },
      ],
    });
  });

  it('maps chat summaries with backend last_message preview', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () =>
        mockJson([
          {
            room_id: 'r1',
            name: '项目群',
            room_type: 'group',
            unread_count: 2,
            is_pinned: true,
            is_muted: false,
            last_message: {
              id: 'm1',
              content: 'latest message',
              message_type: 'text',
              created_at: '2026-07-02T01:20:00Z',
            },
          },
        ]),
      ),
    );

    const chats = await messageService.fetchChats();

    expect(chats[0]).toMatchObject({
      roomId: 'r1',
      name: '项目群',
      lastMessage: 'latest message',
      unreadCount: 2,
      type: 'group',
      isPinned: true,
    });
    expect(chats[0]?.lastMessageTime).toBe(Date.parse('2026-07-02T01:20:00Z'));
  });

  it('maps wrapped send message responses', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () =>
        mockJson({
          message: {
            id: 'm2',
            room_id: 'r1',
            sender_id: 'u1',
            sender_nickname: 'U1',
            content: 'hello wrapped',
            message_type: 'text',
            created_at: '2026-07-02T01:10:00Z',
          },
        }),
      ),
    );

    const sent = await messageService.sendTextMessage('r1', ' hello wrapped ');

    expect(sent).toMatchObject({
      id: 'm2',
      roomId: 'r1',
      senderName: 'U1',
      content: 'hello wrapped',
    });
  });

  it('sends quoted text messages with Flutter-compatible payload', async () => {
    const fetchMock = vi.fn(async () => mockJson({
      message: {
        id: 'm3',
        room_id: 'r1',
        sender_id: 'u1',
        content: 'quoted',
        message_type: 'text',
      },
    }));
    vi.stubGlobal('fetch', fetchMock);

    await messageService.sendTextMessage('r1', ' quoted ', 'm1');

    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8010/rooms/r1/messages',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          content: 'quoted',
          quoted_message_id: 'm1',
        }),
      }),
    );
  });

  it('maps quoted and pinned message fields from backend responses', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => mockJson([
      {
        id: 'm2',
        room_id: 'r1',
        sender_id: 'u1',
        content: 'reply',
        message_type: 'text',
        status: 'read',
        is_pinned: true,
        pinned_at: '2026-07-02T01:15:00Z',
        pinned_by: 'u1',
        quoted_message: {
          id: 'm1',
          room_id: 'r1',
          sender_id: 'u2',
          sender_nickname: 'Bear',
          content: 'source',
          message_type: 'text',
          created_at: '2026-07-02T01:00:00Z',
        },
        forward_message: {
          message_id: 'origin-1',
          room_id: 'origin-room',
          sender_id: 'u2',
          sender_username: 'bear',
          sender_nickname: 'Bear',
        },
      },
    ])));

    const messages = await messageService.loadMessages('r1');

    expect(messages[0]).toMatchObject({
      id: 'm2',
      isPinned: true,
      pinnedAt: Date.parse('2026-07-02T01:15:00Z'),
      pinnedBy: 'u1',
      status: 'read',
      forwardInfo: {
        messageId: 'origin-1',
        roomId: 'origin-room',
        senderId: 'u2',
        senderUsername: 'bear',
        senderNickname: 'Bear',
      },
      quotedMessage: expect.objectContaining({
        id: 'm1',
        senderName: 'Bear',
        content: 'source',
      }),
    });
  });

  it('pins, unpins and deletes messages through backend routes', async () => {
    const fetchMock = vi.fn(async () => mockJson({ success: true }));
    vi.stubGlobal('fetch', fetchMock);

    await messageService.pinMessage('r1', 'm1', true);
    await messageService.pinMessage('r1', 'm1', false);
    await messageService.deleteMessage('r1', 'm1');

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      'http://127.0.0.1:8010/rooms/r1/messages/m1/pin',
      expect.objectContaining({ method: 'POST' }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      'http://127.0.0.1:8010/rooms/r1/messages/m1/pin',
      expect.objectContaining({ method: 'DELETE' }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      3,
      'http://127.0.0.1:8010/rooms/r1/messages/m1',
      expect.objectContaining({ method: 'DELETE' }),
    );
  });

  it('marks room messages as read with Flutter-compatible payload', async () => {
    const fetchMock = vi.fn(async () => mockJson({ success: true }));
    vi.stubGlobal('fetch', fetchMock);

    await messageService.markMessagesAsRead('r1', 'm1');

    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8010/rooms/r1/messages/read',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ message_id: 'm1' }),
      }),
    );
  });

  it('fetches public settings without auth token', async () => {
    let capturedInit: RequestInit | undefined;
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      capturedInit = init;
      return mockJson({
        app_name: 'RedCode IM',
        message_runtime: {
          server_storage_mode: 'persist',
          content_audit_mode: 'plaintext',
        },
      });
    });
    vi.stubGlobal('fetch', fetchMock);

    const settings = await settingsService.fetchGeneralSettings();

    expect(settings.appName).toBe('RedCode IM');
    const headers = capturedInit?.headers as Headers;
    expect(headers.get('Authorization')).toBeNull();
  });

  it('updates profile and changes password through user routes', async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.endsWith('/password')) {
        return mockJson({ success: true });
      }
      return mockJson({
        id: 'u1',
        username: 'u1@example.com',
        email: 'u1@example.com',
        nickname: 'New Name',
      });
    });
    vi.stubGlobal('fetch', fetchMock);

    const updated = await authService.updateProfile({ nickname: ' New Name ' });
    await authService.changePassword('old-pass', 'new-pass');

    expect(updated.nickname).toBe('New Name');
    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      'http://127.0.0.1:8010/users/me',
      expect.objectContaining({
        method: 'PATCH',
        body: JSON.stringify({ nickname: 'New Name' }),
      }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      'http://127.0.0.1:8010/users/me/password',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ old_password: 'old-pass', new_password: 'new-pass' }),
      }),
    );
  });

  it('uploads user avatars through direct upload and commit routes', async () => {
    const calls: Array<{ url: string; init?: RequestInit }> = [];
    const fetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      calls.push({ url, init });
      if (url.endsWith('/users/me/avatar/direct-upload')) {
        return mockJson({
          success: true,
          key: 'avatars/u1/avatar.png',
          signature: {
            url: 'http://127.0.0.1:19080/upload/avatars/u1/avatar.png',
            method: 'PUT',
            headers: { 'Content-Type': 'image/png' },
            key: 'avatars/u1/avatar.png',
          },
        });
      }
      if (url.includes('/upload/avatars/u1/avatar.png')) {
        return new Response('', { status: 200 });
      }
      return mockJson({
        success: true,
        download_url: 'http://127.0.0.1:19080/download/avatars/u1/avatar.png',
      });
    });
    vi.stubGlobal('fetch', fetchMock);

    const file = new File(['avatar'], 'avatar.png', { type: 'image/png' });
    const result = await avatarUploadService.uploadUserAvatar(file);

    expect(result).toEqual({
      objectKey: 'avatars/u1/avatar.png',
      downloadUrl: 'http://127.0.0.1:19080/download/avatars/u1/avatar.png',
    });
    expect(calls[0]?.url).toBe('http://127.0.0.1:8010/users/me/avatar/direct-upload');
    expect(JSON.parse(String(calls[0]?.init?.body))).toEqual({
      filename: 'avatar.png',
      content_type: 'image/png',
      file_size: 6,
    });
    expect((calls[0]?.init?.headers as Headers).get('Authorization')).toBe('Bearer token-1');
    expect(calls[1]).toMatchObject({
      url: 'http://127.0.0.1:19080/upload/avatars/u1/avatar.png',
      init: expect.objectContaining({
        method: 'PUT',
        body: file,
      }),
    });
    expect(calls[2]?.url).toBe('http://127.0.0.1:8010/users/me/avatar/commit');
    expect(JSON.parse(String(calls[2]?.init?.body))).toEqual({
      key: 'avatars/u1/avatar.png',
      delete_previous: true,
      expires_in_seconds: 3600,
    });
    expect((calls[2]?.init?.headers as Headers).get('Authorization')).toBe('Bearer token-1');
  });

  it('uploads room avatars through direct upload and commit routes', async () => {
    const calls: Array<{ url: string; init?: RequestInit }> = [];
    const fetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      calls.push({ url, init });
      if (url.endsWith('/rooms/r1/avatar/direct-upload')) {
        return mockJson({
          success: true,
          key: 'room_avatars/r1/avatar.png',
          signature: {
            url: 'http://127.0.0.1:19080/upload/room_avatars/r1/avatar.png',
            method: 'PUT',
            headers: { 'Content-Type': 'image/png' },
            key: 'room_avatars/r1/avatar.png',
          },
        });
      }
      if (url.includes('/upload/room_avatars/r1/avatar.png')) {
        return new Response('', { status: 200 });
      }
      return mockJson({
        success: true,
        avatar_url: 'http://127.0.0.1:19080/download/room_avatars/r1/avatar.png',
      });
    });
    vi.stubGlobal('fetch', fetchMock);

    const file = new File(['room-avatar'], 'room-avatar.png', { type: 'image/png' });
    const result = await avatarUploadService.uploadRoomAvatar('r1', file);

    expect(result.objectKey).toBe('room_avatars/r1/avatar.png');
    expect(result.downloadUrl).toContain('/download/room_avatars/r1/avatar.png');
    expect(calls[0]?.url).toBe('http://127.0.0.1:8010/rooms/r1/avatar/direct-upload');
    expect(JSON.parse(String(calls[0]?.init?.body))).toEqual({
      filename: 'room-avatar.png',
      content_type: 'image/png',
      file_size: 11,
    });
    expect(calls[1]).toMatchObject({
      url: 'http://127.0.0.1:19080/upload/room_avatars/r1/avatar.png',
      init: expect.objectContaining({
        method: 'PUT',
        body: file,
      }),
    });
    expect(calls[2]?.url).toBe('http://127.0.0.1:8010/rooms/r1/avatar/commit');
    expect(JSON.parse(String(calls[2]?.init?.body))).toEqual({
      key: 'room_avatars/r1/avatar.png',
    });
  });

  it('rejects non-image avatar uploads before network requests', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    await expect(
      avatarUploadService.uploadUserAvatar(new File(['plain'], 'plain.txt', { type: 'text/plain' })),
    ).rejects.toThrow('头像仅支持图片文件');

    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('loads documents and submits feedback through settings routes', async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.endsWith('/feedbacks')) {
        return mockJson({ success: true, message: '反馈提交成功' });
      }
      return mockJson({
        title: url.includes('privacy') ? '隐私协议' : '用户协议',
        content: '<p>content</p>',
        updated_at: '2026-07-02T00:00:00Z',
      });
    });
    vi.stubGlobal('fetch', fetchMock);

    const privacy = await settingsService.fetchPrivacyPolicy();
    const agreement = await settingsService.fetchUserAgreement();
    const feedback = await settingsService.submitFeedback({ content: ' hi ', contact: ' h5@example.com ' });

    expect(privacy.title).toBe('隐私协议');
    expect(agreement.title).toBe('用户协议');
    expect(feedback).toBe('反馈提交成功');
    expect(fetchMock).toHaveBeenNthCalledWith(
      3,
      'http://127.0.0.1:8010/feedbacks',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ content: 'hi', contact: 'h5@example.com' }),
      }),
    );
  });

  it('raises backend error messages as ApiError', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => mockJson({ error: '创建聊天失败' }, 500)));

    await expect(friendService.ensurePrivateChat('u2')).rejects.toMatchObject({
      name: 'ApiError',
      message: '创建聊天失败',
      status: 500,
    });
  });
});
