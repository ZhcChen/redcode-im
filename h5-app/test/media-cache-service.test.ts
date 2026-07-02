import { beforeEach, describe, expect, it, vi } from 'vitest';

import { attachmentCacheService } from '@/services/attachment-cache';
import { avatarCacheService } from '@/services/avatar-cache';
import { emojiCacheService } from '@/services/emoji-cache';

const saveSession = () => {
  window.localStorage.setItem(
    'redcode-h5-session',
    JSON.stringify({
      token: 'token-1',
      user: {
        id: 'u1',
        username: 'u1@example.com',
        nickname: 'U1',
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

const blobResponse = (body: string, type: string) =>
  new Response(body, {
    headers: { 'Content-Type': type },
  });

describe('media cache services', () => {
  beforeEach(async () => {
    saveSession();
    vi.stubGlobal('caches', undefined);
    Object.defineProperty(URL, 'createObjectURL', {
      configurable: true,
      value: vi.fn((blob: Blob) => `blob:test/${blob.size}`),
    });
    Object.defineProperty(URL, 'revokeObjectURL', {
      configurable: true,
      value: vi.fn(),
    });
    await avatarCacheService.clearAll();
    await attachmentCacheService.clearAll();
    await emojiCacheService.clearAll();
  });

  it('loads user avatars through signed URL endpoint and reuses blob cache', async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.startsWith('http://127.0.0.1:8010/users/u2/avatar/url')) {
        return mockJson({ success: true, download_url: 'https://cdn.example/avatar.png' });
      }
      if (url === 'https://cdn.example/avatar.png') {
        return blobResponse('avatar', 'image/png');
      }
      throw new Error(`unexpected url: ${url}`);
    });
    vi.stubGlobal('fetch', fetchMock);

    const first = await avatarCacheService.loadUserAvatar({ userId: 'u2', objectKey: 'avatars/u2.png' });
    const second = await avatarCacheService.loadUserAvatar({ userId: 'u2', objectKey: 'avatars/u2.png' });

    expect(first).toMatchObject({ objectKey: 'avatars/u2.png', mimeType: 'image/png' });
    expect(second).toMatchObject({ objectKey: 'avatars/u2.png', mimeType: 'image/png' });
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      'http://127.0.0.1:8010/users/u2/avatar/url?expires_in_seconds=3600',
      expect.objectContaining({ headers: expect.any(Headers) }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(2, 'https://cdn.example/avatar.png', undefined);
  });

  it('loads room avatars through room avatar endpoint', async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.startsWith('http://127.0.0.1:8010/rooms/r1/avatar/url')) {
        return mockJson({ success: true, download_url: 'https://cdn.example/room.png' });
      }
      return blobResponse('room', 'image/png');
    });
    vi.stubGlobal('fetch', fetchMock);

    await avatarCacheService.loadRoomAvatar({ roomId: 'r1', objectKey: 'room_avatars/r1.png' });

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      'http://127.0.0.1:8010/rooms/r1/avatar/url?expires_in_seconds=3600',
      expect.any(Object),
    );
  });

  it('refreshes avatar cache metadata when the object key changes', async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.startsWith('http://127.0.0.1:8010/users/u2/avatar/url')) {
        return mockJson({ success: true, download_url: 'https://cdn.example/avatar.png' });
      }
      return blobResponse('avatar', 'image/png');
    });
    vi.stubGlobal('fetch', fetchMock);

    await avatarCacheService.loadUserAvatar({ userId: 'u2', objectKey: 'avatars/old.png' });
    await avatarCacheService.loadUserAvatar({ userId: 'u2', objectKey: 'avatars/new.png' });

    const metadata = JSON.parse(window.localStorage.getItem('redcode-h5-avatar-cache:meta:user:u2') ?? '{}') as Record<string, unknown>;
    expect(metadata.objectKey).toBe('avatars/new.png');
    expect(fetchMock).toHaveBeenCalledTimes(4);
  });

  it('loads attachments through message attachment download endpoint', async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.startsWith('http://127.0.0.1:8010/rooms/r1/messages/attachments/download')) {
        return mockJson({ success: true, download_url: 'https://cdn.example/file.pdf' });
      }
      return blobResponse('file', 'application/pdf');
    });
    vi.stubGlobal('fetch', fetchMock);

    const entry = await attachmentCacheService.loadAttachment({
      roomId: 'r1',
      objectKey: 'messages/r1/files/file.pdf',
    });

    expect(entry).toMatchObject({
      cacheKey: 'message:messages/r1/files/file.pdf',
      objectKey: 'messages/r1/files/file.pdf',
      mimeType: 'application/pdf',
    });
    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      'http://127.0.0.1:8010/rooms/r1/messages/attachments/download?key=messages%2Fr1%2Ffiles%2Ffile.pdf&expires_in_seconds=600',
      expect.any(Object),
    );
  });

  it('loads emoji object keys through emoji download endpoint', async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.startsWith('http://127.0.0.1:8010/emoji-packs/download-url')) {
        return mockJson({ success: true, download_url: 'https://cdn.example/emoji.gif' });
      }
      return blobResponse('gif', 'image/gif');
    });
    vi.stubGlobal('fetch', fetchMock);

    const entry = await emojiCacheService.loadEmoji({ objectKey: 'emoji-items/panda.gif' });

    expect(entry).toMatchObject({
      cacheKey: 'emoji:emoji-items/panda.gif',
      objectKey: 'emoji-items/panda.gif',
      mimeType: 'image/gif',
    });
    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      'http://127.0.0.1:8010/emoji-packs/download-url?object_key=emoji-items%2Fpanda.gif&expires_in_seconds=3600',
      expect.any(Object),
    );
  });

  it('does not persist failed signed URL downloads', async () => {
    const fetchMock = vi.fn(async () => new Response('failed', { status: 500 }));
    vi.stubGlobal('fetch', fetchMock);

    const entry = await attachmentCacheService.loadAttachment({
      roomId: 'r1',
      objectKey: 'messages/r1/files/missing.pdf',
    });

    expect(entry).toBeNull();
    expect(window.localStorage.getItem('redcode-h5-attachment-cache:meta:message:messages/r1/files/missing.pdf')).toBeNull();
  });
});
