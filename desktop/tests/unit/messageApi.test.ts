import { describe, it, expect, beforeEach, vi } from 'vitest';
import { MessageApi } from '../../src/api/message';
import type { Message, MessagePartPayloadInput } from '../../src/types/models';

// Mock HTTP module
const mockHttpModule = {
  get: vi.fn(),
  post: vi.fn(),
  del: vi.fn(),
};

vi.mock('../../src/api/http', () => ({
  get: mockHttpModule.get,
  post: mockHttpModule.post,
  del: mockHttpModule.del,
}));

describe('Message API', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getMessageListByChatGroupId', () => {
    it('should fetch message list successfully', async () => {
      const mockResponse = {
        success: true,
        data: [
          {
            id: 'msg-1',
            room_id: 'room-123',
            sender_id: 'user-456',
            sender_username: 'testuser',
            content: 'Test message',
            message_type: 'text',
            created_at: '2023-01-01T00:00:00Z',
            is_deleted: false,
            parts: [],
          },
        ],
        code: 200,
        message: 'Success',
      };

      mockHttpModule.get.mockResolvedValue(mockResponse);

      const result = await MessageApi.getMessageListByChatGroupId({
        groupId: 'room-123',
        currentUserId: 'user-456',
      });

      expect(result.success).toBe(true);
      expect(result.data).toHaveLength(1);
      expect(result.data?.[0].id).toBe('msg-1');
      expect(mockHttpModule.get).toHaveBeenCalledWith(
        '/rooms/room-123/messages',
        {}
      );
    });

    it('should handle empty message list', async () => {
      const mockResponse = {
        success: true,
        data: [],
        code: 200,
        message: 'Success',
      };

      mockHttpModule.get.mockResolvedValue(mockResponse);

      const result = await MessageApi.getMessageListByChatGroupId({
        groupId: 'room-123',
      });

      expect(result.success).toBe(true);
      expect(result.data).toEqual([]);
    });

    it('should handle API error', async () => {
      const mockResponse = {
        success: false,
        data: null,
        code: 500,
        message: 'Server error',
      };

      mockHttpModule.get.mockResolvedValue(mockResponse);

      const result = await MessageApi.getMessageListByChatGroupId({
        groupId: 'room-123',
      });

      expect(result.success).toBe(false);
      expect(result.data).toBeNull();
    });
  });

  describe('sendTextMessage', () => {
    it('should send text message successfully', async () => {
      const mockResponse = {
        success: true,
        data: {
          id: 'msg-123',
          room_id: 'room-123',
          sender_id: 'user-456',
          content: 'Hello, world!',
          message_type: 'text',
          created_at: '2023-01-01T00:00:00Z',
          is_deleted: false,
          parts: [],
        },
        code: 200,
        message: 'Message sent',
      };

      mockHttpModule.post.mockResolvedValue(mockResponse);

      const result = await MessageApi.sendTextMessage({
        groupId: 'room-123',
        content: 'Hello, world!',
        currentUserId: 'user-456',
      });

      expect(result.success).toBe(true);
      expect(result.data?.content).toBe('Hello, world!');
      expect(mockHttpModule.post).toHaveBeenCalledWith(
        '/rooms/room-123/messages',
        {
          content: 'Hello, world!',
        }
      );
    });

    it('should handle empty content', async () => {
      const result = await MessageApi.sendTextMessage({
        groupId: 'room-123',
        content: '',
      });

      expect(result.success).toBe(false);
      expect(result.message).toBe('消息内容不能为空');
    });

    it('should include replyToMessageId when provided', async () => {
      const mockResponse = {
        success: true,
        data: {
          id: 'msg-123',
          room_id: 'room-123',
          sender_id: 'user-456',
          content: 'Reply message',
          message_type: 'text',
          created_at: '2023-01-01T00:00:00Z',
          is_deleted: false,
          parts: [],
        },
        code: 200,
        message: 'Message sent',
      };

      mockHttpModule.post.mockResolvedValue(mockResponse);

      await MessageApi.sendTextMessage({
        groupId: 'room-123',
        content: 'Reply message',
        replyToMessageId: 'msg-456',
        currentUserId: 'user-456',
      });

      expect(mockHttpModule.post).toHaveBeenCalledWith(
        '/rooms/room-123/messages',
        {
          content: 'Reply message',
          quoted_message_id: 'msg-456',
        }
      );
    });
  });

  describe('sendMessage', () => {
    it('should send message with parts', async () => {
      const mockResponse = {
        success: true,
        data: {
          id: 'msg-123',
          room_id: 'room-123',
          sender_id: 'user-456',
          content: 'File message',
          message_type: 'file',
          created_at: '2023-01-01T00:00:00Z',
          is_deleted: false,
          parts: [
            {
              position: 0,
              part_type: 'file',
              attachment: {
                key: 'file-123',
                name: 'test.txt',
                mime: 'text/plain',
                size: 1024,
              },
            },
          ],
        },
        code: 200,
        message: 'Message sent',
      };

      mockHttpModule.post.mockResolvedValue(mockResponse);

      const parts: MessagePartPayloadInput[] = [
        {
          type: 'file',
          key: 'file-123',
          name: 'test.txt',
          mime: 'text/plain',
          size: 1024,
        },
      ];

      const result = await MessageApi.sendMessage({
        groupId: 'room-123',
        content: 'File message',
        parts,
        currentUserId: 'user-456',
      });

      expect(result.success).toBe(true);
      expect(result.data?.content).toBe('File message');
      expect(mockHttpModule.post).toHaveBeenCalledWith(
        '/rooms/room-123/messages',
        {
          content: 'File message',
          parts: [
            {
              type: 'file',
              key: 'file-123',
              name: 'test.txt',
              mime: 'text/plain',
              size: 1024,
            },
          ],
        }
      );
    });

    it('should require either content or parts', async () => {
      const result = await MessageApi.sendMessage({
        groupId: 'room-123',
      });

      expect(result.success).toBe(false);
      expect(result.message).toBe('消息内容不能为空');
    });
  });

  describe('markMessagesAsRead', () => {
    it('should mark single message as read', async () => {
      const mockResponse = {
        success: true,
        data: {},
        code: 200,
        message: 'Success',
      };

      mockHttpModule.post.mockResolvedValue(mockResponse);

      const result = await MessageApi.markMessagesAsRead({
        groupId: 'room-123',
        messageIds: ['msg-1'],
      });

      expect(result.success).toBe(true);
      expect(mockHttpModule.post).toHaveBeenCalledWith(
        '/rooms/room-123/messages/read',
        {
          message_id: 'msg-1',
        }
      );
    });

    it('should mark multiple messages as read', async () => {
      const mockResponse = {
        success: true,
        data: {},
        code: 200,
        message: 'Success',
      };

      mockHttpModule.post.mockResolvedValue(mockResponse);

      const result = await MessageApi.markMessagesAsRead({
        groupId: 'room-123',
        messageIds: ['msg-1', 'msg-2', 'msg-3'],
      });

      expect(result.success).toBe(true);
      expect(mockHttpModule.post).toHaveBeenCalledWith(
        '/rooms/room-123/messages/read_until',
        {
          message_id: 'msg-3',
        }
      );
    });

    it('should handle empty message IDs', async () => {
      const result = await MessageApi.markMessagesAsRead({
        groupId: 'room-123',
        messageIds: [],
      });

      expect(result.success).toBe(false);
      expect(result.message).toBe('缺少消息 ID，无法标记为已读');
    });
  });

  describe('deleteMessage', () => {
    it('should delete message successfully', async () => {
      const mockResponse = {
        success: true,
        data: null,
        code: 200,
        message: 'Message deleted',
      };

      mockHttpModule.del.mockResolvedValue(mockResponse);

      const result = await MessageApi.deleteMessage({
        groupId: 'room-123',
        messageId: 'msg-456',
      });

      expect(result.success).toBe(true);
      expect(result.data).toBeNull();
      expect(mockHttpModule.del).toHaveBeenCalledWith(
        '/rooms/room-123/messages/msg-456'
      );
    });
  });

  describe('pinMessage', () => {
    it('should pin message successfully', async () => {
      const mockResponse = {
        success: true,
        data: {
          is_pinned: true,
          message: {
            id: 'msg-123',
            room_id: 'room-123',
            sender_id: 'user-456',
            content: 'Pinned message',
            message_type: 'text',
            created_at: '2023-01-01T00:00:00Z',
            is_deleted: false,
            pinned_at: '2023-01-01T00:00:00Z',
            pinned_by: 'user-456',
            parts: [],
          },
        },
        code: 200,
        message: 'Message pinned',
      };

      mockHttpModule.post.mockResolvedValue(mockResponse);

      const result = await MessageApi.pinMessage({
        groupId: 'room-123',
        messageId: 'msg-123',
        currentUserId: 'user-456',
      });

      expect(result.success).toBe(true);
      expect(result.data?.isPinned).toBe(true);
      expect(result.data?.pinnedAt).toBeInstanceOf(Date);
      expect(mockHttpModule.post).toHaveBeenCalledWith(
        '/rooms/room-123/messages/msg-123/pin',
        {}
      );
    });
  });

  describe('unpinMessage', () => {
    it('should unpin message successfully', async () => {
      const mockResponse = {
        success: true,
        data: {
          is_pinned: false,
        },
        code: 200,
        message: 'Message unpinned',
      };

      mockHttpModule.del.mockResolvedValue(mockResponse);

      const result = await MessageApi.unpinMessage({
        groupId: 'room-123',
        messageId: 'msg-123',
      });

      expect(result.success).toBe(true);
      expect(result.data?.isPinned).toBe(false);
      expect(mockHttpModule.del).toHaveBeenCalledWith(
        '/rooms/room-123/messages/msg-123/pin'
      );
    });
  });

  describe('forwardMessage', () => {
    it('should forward message successfully', async () => {
      const mockResponse = {
        success: true,
        data: [
          {
            message_id: 'forwarded-1',
            room_id: 'room-456',
            sender_id: 'user-123',
            source_type: 'group',
            source_name: 'Test Group',
          },
        ],
        code: 200,
        message: 'Message forwarded',
      };

      mockHttpModule.post.mockResolvedValue(mockResponse);

      const result = await MessageApi.forwardMessage({
        groupId: 'room-123',
        messageId: 'msg-456',
        targetRoomIds: ['room-456', 'room-789'],
      });

      expect(result.success).toBe(true);
      expect(result.data).toHaveLength(1);
      expect(result.data?.[0].sourceName).toBe('Test Group');
      expect(mockHttpModule.post).toHaveBeenCalledWith(
        '/rooms/room-123/messages/forward',
        {
          message_id: 'msg-456',
          target_room_ids: ['room-456', 'room-789'],
        }
      );
    });
  });

  describe('getUnreadMessageCount', () => {
    it('should get unread count for specific room', async () => {
      const mockResponse = {
        success: true,
        data: 5,
        code: 200,
        message: 'Success',
      };

      mockHttpModule.get.mockResolvedValue(mockResponse);

      const result = await MessageApi.getUnreadMessageCount({
        groupId: 'room-123',
      });

      expect(result.success).toBe(true);
      expect(result.data).toBe(5);
      expect(mockHttpModule.get).toHaveBeenCalledWith(
        '/rooms/room-123/unread_count'
      );
    });

    it('should get all unread counts', async () => {
      const mockResponse = {
        success: true,
        data: {
          total: 10,
          rooms: [
            { roomId: 'room-123', count: 5 },
            { roomId: 'room-456', count: 5 },
          ],
        },
        code: 200,
        message: 'Success',
      };

      mockHttpModule.get.mockResolvedValue(mockResponse);

      const result = await MessageApi.getUnreadMessageCount();

      expect(result.success).toBe(true);
      expect(result.data).toBeDefined();
      expect(mockHttpModule.get).toHaveBeenCalledWith('/unread_counts');
    });
  });

  describe('updateNotificationSettings', () => {
    it('should update notification settings', async () => {
      const mockResponse = {
        success: true,
        data: {
          notificationSettings: 1, // Mentions only
        },
        code: 200,
        message: 'Settings updated',
      };

      mockHttpModule.post.mockResolvedValue(mockResponse);

      const result = await MessageApi.updateNotificationSettings({
        roomId: 'room-123',
        notificationSettings: 1, // Mentions only
      });

      expect(result.success).toBe(true);
      expect(result.data?.notificationSettings).toBe(1);
      expect(mockHttpModule.post).toHaveBeenCalledWith(
        '/rooms/room-123/notification-settings',
        {
          notification_settings: 1,
        }
      );
    });
  });

  describe('ensureChatRoom', () => {
    it('should ensure chat room with friend', async () => {
      const mockResponse = {
        success: true,
        data: {
          room_id: 'room-123',
        },
        code: 200,
        message: 'Chat room created',
      };

      mockHttpModule.post.mockResolvedValue(mockResponse);

      const result = await MessageApi.ensureChatRoom({
        friendId: 'user-456',
      });

      expect(result.success).toBe(true);
      expect(result.data?.roomId).toBe('room-123');
      expect(mockHttpModule.post).toHaveBeenCalledWith(
        '/friends/user-456/chat',
        {}
      );
    });
  });
});
