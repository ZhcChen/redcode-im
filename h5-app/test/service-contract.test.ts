import { beforeEach, describe, expect, it, vi } from 'vitest';

import { authService } from '@/services/auth-service';
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
      },
    ])));

    const messages = await messageService.loadMessages('r1');

    expect(messages[0]).toMatchObject({
      id: 'm2',
      isPinned: true,
      pinnedAt: Date.parse('2026-07-02T01:15:00Z'),
      pinnedBy: 'u1',
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
