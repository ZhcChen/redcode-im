import { beforeEach, describe, expect, it, vi } from 'vitest';

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

  it('raises backend error messages as ApiError', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => mockJson({ error: '创建聊天失败' }, 500)));

    await expect(friendService.ensurePrivateChat('u2')).rejects.toMatchObject({
      name: 'ApiError',
      message: '创建聊天失败',
      status: 500,
    });
  });
});
