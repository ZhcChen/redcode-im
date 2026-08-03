import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { messageService } from '@/services/message-service';
import { useMessageActionsStore } from '@/stores/message-actions';

vi.mock('@/services/message-service', () => ({
  messageService: {
    fetchChats: vi.fn().mockResolvedValue([]),
    fetchMessageReaders: vi.fn(),
    forwardMessage: vi.fn(),
  },
}));

vi.mock('@/services/room-service', () => ({
  roomService: {
    listMembers: vi.fn().mockResolvedValue([
      { userId: 'sender', username: 'sender', nickname: 'Sender', role: 'owner' },
      { userId: 'u1', username: 'one', nickname: null, role: 'member' },
      { userId: 'u2', username: 'two', nickname: 'Two', role: 'member' },
      { userId: 'u3', username: 'three', nickname: 'Three', role: 'member' },
    ]),
  },
}));

vi.mock('@/config/env', () => ({ appEnv: { useMockData: false } }));

describe('message actions store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it('loads and sorts message readers by read time', async () => {
    vi.mocked(messageService.fetchMessageReaders).mockResolvedValue([
      { userId: 'u2', username: 'two', nickname: 'Two', avatarUrl: null, readAt: 200 },
      { userId: 'u1', username: 'one', nickname: null, avatarUrl: null, readAt: 100 },
    ]);
    const store = useMessageActionsStore();

    await store.loadReaders('room-1', 'message-1', 'sender');

    expect(store.readers.map((reader) => reader.userId)).toEqual(['u1', 'u2']);
    expect(store.eligibleReaders.map((reader) => reader.userId)).toEqual(['u1', 'u2']);
    expect(store.unreadMembers.map((member) => member.userId)).toEqual(['u3']);
    expect(store.error).toBe('');
  });

  it('forwards to every selected room and reports partial failures', async () => {
    vi.mocked(messageService.forwardMessage)
      .mockResolvedValueOnce({} as never)
      .mockRejectedValueOnce(new Error('target unavailable'));
    const store = useMessageActionsStore();

    const result = await store.forwardMessage('message-1', ['room-a', 'room-b']);

    expect(messageService.forwardMessage).toHaveBeenNthCalledWith(1, 'room-a', 'message-1');
    expect(messageService.forwardMessage).toHaveBeenNthCalledWith(2, 'room-b', 'message-1');
    expect(result).toEqual({ succeeded: ['room-a'], failed: ['room-b'] });
    expect(store.error).toContain('1 个会话转发失败');
  });
});
