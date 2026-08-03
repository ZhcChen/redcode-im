import { beforeEach, describe, expect, it, vi } from 'vitest';

import { messageService } from '@/services/message-service';

const requestJsonMock = vi.hoisted(() => vi.fn());

vi.mock('@/api/http', () => ({
  requestJson: requestJsonMock,
  withQuery: vi.fn(),
}));

vi.mock('@/services/session', () => ({
  requireToken: () => 'token-1',
}));

describe('message action service contracts', () => {
  beforeEach(() => {
    requestJsonMock.mockReset();
  });

  it('maps message readers from the existing reads endpoint', async () => {
    requestJsonMock.mockResolvedValue([{
      user_id: 'u1',
      username: 'alice',
      nickname: 'Alice',
      avatar_url: null,
      read_at: '2026-08-04T00:00:00Z',
    }]);

    const readers = await messageService.fetchMessageReaders('room-1', 'message-1');

    expect(requestJsonMock).toHaveBeenCalledWith(
      '/rooms/room-1/messages/message-1/reads',
      {},
      'token-1',
    );
    expect(readers[0]).toMatchObject({ userId: 'u1', nickname: 'Alice' });
    expect(readers[0]?.readAt).toBe(Date.parse('2026-08-04T00:00:00Z'));
  });

  it('uses the backend forward endpoint and maps the returned message', async () => {
    requestJsonMock.mockResolvedValue({
      message: {
        id: 'forwarded-1',
        room_id: 'target-room',
        sender_id: 'u1',
        content: 'hello',
        message_type: 'text',
        created_at: '2026-08-04T00:00:00Z',
      },
    });

    const message = await messageService.forwardMessage('target-room', 'source-message');

    expect(requestJsonMock).toHaveBeenCalledWith(
      '/rooms/target-room/messages/forward',
      { method: 'POST', body: JSON.stringify({ original_message_id: 'source-message' }) },
      'token-1',
    );
    expect(message).toMatchObject({ id: 'forwarded-1', roomId: 'target-room' });
  });
});
