import { describe, it, expect, beforeEach } from 'vitest';
import { SearchApi, SearchUtils, SearchResultsUtils } from '../../src/api/search';
import type { MessageSearchResult, SearchParams, IndexMessage } from '../../src/api/search';

// Mock Tauri API
const mockInvoke = vi.fn();
vi.stubGlobal('invoke', mockInvoke);

describe('Search API', () => {
  beforeEach(() => {
    mockInvoke.mockClear();
  });

  describe('indexMessage', () => {
    it('should index a single message', async () => {
      mockInvoke.mockResolvedValue(undefined);

      const message: IndexMessage = {
        id: 'msg-123',
        roomId: 'room-456',
        roomName: 'Test Room',
        senderId: 'user-789',
        senderName: 'Test User',
        content: 'Test message content',
        messageType: 'text',
        timestamp: Date.now(),
      };

      await SearchApi.indexMessage(message);

      expect(mockInvoke).toHaveBeenCalledWith('index_message', {
        message,
      });
    });

    it('should handle indexing errors', async () => {
      mockInvoke.mockRejectedValue(new Error('Indexing failed'));

      const message: IndexMessage = {
        id: 'msg-123',
        roomId: 'room-456',
        roomName: 'Test Room',
        senderId: 'user-789',
        senderName: 'Test User',
        content: 'Test message content',
        messageType: 'text',
        timestamp: Date.now(),
      };

      await expect(SearchApi.indexMessage(message)).rejects.toThrow('Indexing failed');
    });
  });

  describe('indexMessages', () => {
    it('should batch index multiple messages', async () => {
      mockInvoke.mockResolvedValue(undefined);

      const messages: IndexMessage[] = [
        {
          id: 'msg-1',
          roomId: 'room-456',
          roomName: 'Test Room',
          senderId: 'user-789',
          senderName: 'Test User',
          content: 'Message 1',
          messageType: 'text',
          timestamp: Date.now(),
        },
        {
          id: 'msg-2',
          roomId: 'room-456',
          roomName: 'Test Room',
          senderId: 'user-789',
          senderName: 'Test User',
          content: 'Message 2',
          messageType: 'text',
          timestamp: Date.now(),
        },
      ];

      await SearchApi.indexMessages(messages);

      expect(mockInvoke).toHaveBeenCalledWith('index_messages', {
        messages,
      });
    });

    it('should handle empty message list', async () => {
      mockInvoke.mockResolvedValue(undefined);

      await SearchApi.indexMessages([]);

      expect(mockInvoke).toHaveBeenCalledWith('index_messages', {
        messages: [],
      });
    });
  });

  describe('searchMessages', () => {
    it('should search messages with query', async () => {
      const mockResults: MessageSearchResult[] = [
        {
          id: 'msg-1',
          roomId: 'room-456',
          roomName: 'Test Room',
          senderId: 'user-789',
          senderName: 'Test User',
          content: 'Test message',
          messageType: 'text',
          timestamp: Date.now(),
          matchedText: 'Test message',
          relevanceScore: 0.95,
        },
      ];

      mockInvoke.mockResolvedValue([mockResults, {
        totalResults: 1,
        searchTimeMs: 10,
        query: 'test',
      }]);

      const params: SearchParams = {
        query: 'test',
        limit: 50,
      };

      const [results, stats] = await SearchApi.searchMessages(params);

      expect(results).toHaveLength(1);
      expect(results[0].content).toBe('Test message');
      expect(stats.query).toBe('test');
    });

    it('should search with filters', async () => {
      const mockResults: MessageSearchResult[] = [];

      mockInvoke.mockResolvedValue([mockResults, {
        totalResults: 0,
        searchTimeMs: 5,
        query: 'test',
      }]);

      const params: SearchParams = {
        query: 'test',
        roomId: 'room-456',
        senderId: 'user-789',
        messageType: 'text',
        limit: 10,
      };

      const [results] = await SearchApi.searchMessages(params);

      expect(mockInvoke).toHaveBeenCalledWith('search_messages', {
        params,
      });
    });
  });

  describe('getSearchSuggestions', () => {
    it('should get search suggestions', async () => {
      const mockSuggestions = ['test message', 'testing', 'tests'];
      mockInvoke.mockResolvedValue(mockSuggestions);

      const suggestions = await SearchApi.getSearchSuggestions('test', 10);

      expect(suggestions).toEqual(['test message', 'testing', 'tests']);
      expect(mockInvoke).toHaveBeenCalledWith('get_search_suggestions', {
        prefix: 'test',
        limit: 10,
      });
    });

    it('should return empty array for empty prefix', async () => {
      const suggestions = await SearchApi.getSearchSuggestions('', 10);
      expect(suggestions).toEqual([]);
    });
  });

  describe('getSearchStats', () => {
    it('should get search statistics', async () => {
      const mockStats = {
        totalMessages: 1000,
        totalRooms: 10,
        totalSenders: 50,
        dbSizeBytes: 1024000,
        dbSizeMb: '1.00',
      };

      mockInvoke.mockResolvedValue(mockStats);

      const stats = await SearchApi.getSearchStats();

      expect(stats.totalMessages).toBe(1000);
      expect(stats.totalRooms).toBe(10);
      expect(stats.dbSizeMb).toBe('1.00');
    });
  });
});

describe('Search Utils', () => {
  describe('messageToIndex', () => {
    it('should convert Message to IndexMessage', () => {
      const message: any = {
        id: 'msg-123',
        roomId: 'room-456',
        senderId: 'user-789',
        senderName: 'Test User',
        senderUsername: 'testuser',
        content: 'Test message',
        type: 'text',
        timestamp: new Date('2023-01-01'),
      };

      const roomName = 'Test Room';

      const indexMessage = SearchUtils.messageToIndex(message, roomName);

      expect(indexMessage.id).toBe('msg-123');
      expect(indexMessage.roomId).toBe('room-456');
      expect(indexMessage.roomName).toBe('Test Room');
      expect(indexMessage.senderId).toBe('user-789');
      expect(indexMessage.content).toBe('Test message');
      expect(indexMessage.messageType).toBe('text');
      expect(indexMessage.timestamp).toBe(message.timestamp.getTime());
    });
  });

  describe('formatTimestamp', () => {
    it('should format today\'s timestamp', () => {
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 10, 30);

      const formatted = SearchUtils.formatTimestamp(today.getTime());

      expect(formatted).toMatch(/^\d{2}:\d{2}$/);
    });

    it('should format yesterday\'s timestamp', () => {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(10, 30);

      const formatted = SearchUtils.formatTimestamp(yesterday.getTime());

      expect(formatted).toBe('昨天 10:30');
    });

    it('should format timestamp older than a week', () => {
      const oldDate = new Date();
      oldDate.setDate(oldDate.getDate() - 10);
      oldDate.setFullYear(2023, 0, 15);

      const formatted = SearchUtils.formatTimestamp(oldDate.getTime());

      expect(formatted).toMatch(/^\d{2}-\d{2}$/);
    });
  });

  describe('formatHighlightedText', () => {
    it('should highlight search terms', () => {
      const text = 'Hello world';
      const highlighted = SearchUtils.formatHighlightedText(text);

      expect(highlighted).toContain('<mark class="search-highlight">');
    });
  });

  describe('buildSearchQuery', () => {
    it('should build basic search query', () => {
      const query = SearchUtils.buildSearchQuery('test');

      expect(query.query).toBe('test');
      expect(query.limit).toBe(50);
    });

    it('should build search query with filters', () => {
      const query = SearchUtils.buildSearchQuery('test', {
        roomId: 'room-456',
        senderId: 'user-789',
        messageType: 'text',
      });

      expect(query.query).toBe('test');
      expect(query.roomId).toBe('room-456');
      expect(query.senderId).toBe('user-789');
      expect(query.messageType).toBe('text');
    });

    it('should build search query with date range', () => {
      const dateFrom = new Date('2023-01-01');
      const dateTo = new Date('2023-12-31');

      const query = SearchUtils.buildSearchQuery('test', {
        dateFrom,
        dateTo,
      });

      expect(query.dateFrom).toBe(dateFrom.getTime());
      expect(query.dateTo).toBe(dateTo.getTime());
    });
  });

  describe('validateSearchQuery', () => {
    it('should validate empty query', () => {
      const result = SearchUtils.validateSearchQuery('');

      expect(result.isValid).toBe(false);
      expect(result.error).toBe('搜索内容不能为空');
    });

    it('should validate long query', () => {
      const longQuery = 'a'.repeat(201);
      const result = SearchUtils.validateSearchQuery(longQuery);

      expect(result.isValid).toBe(false);
      expect(result.error).toBe('搜索内容过长，最多200个字符');
    });

    it('should validate invalid characters', () => {
      const invalidQuery = 'test <script>';
      const result = SearchUtils.validateSearchQuery(invalidQuery);

      expect(result.isValid).toBe(false);
      expect(result.error).toBe('搜索内容包含无效字符');
    });

    it('should validate valid query', () => {
      const result = SearchUtils.validateSearchQuery('test query');

      expect(result.isValid).toBe(true);
    });
  });

  describe('highlightKeywords', () => {
    it('should highlight multiple keywords', () => {
      const text = 'This is a test message with test keywords';
      const keywords = 'test keywords';
      const highlighted = SearchUtils.highlightKeywords(text, keywords);

      expect(highlighted).toContain('<mark class="search-highlight">test</mark>');
      expect(highlighted).toContain('<mark class="search-highlight">keywords</mark>');
    });

    it('should not highlight empty keywords', () => {
      const text = 'This is a test message';
      const highlighted = SearchUtils.highlightKeywords(text, '');

      expect(highlighted).toBe(text);
    });
  });

  describe('debounceSuggestions', () => {
    it('should debounce function calls', async () => {
      const callback = vi.fn();
      const debounced = SearchUtils.debounceSuggestions(callback, 100);

      debounced('test1');
      debounced('test2');
      debounced('test3');

      expect(callback).not.toHaveBeenCalled();

      await new Promise(resolve => setTimeout(resolve, 150));

      expect(callback).toHaveBeenCalledTimes(1);
      expect(callback).toHaveBeenCalledWith('test3');
    });
  });
});

describe('Search Results Utils', () => {
  describe('groupResultsByDate', () => {
    it('should group results by date', () => {
      const now = new Date();
      const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

      const results: MessageSearchResult[] = [
        {
          id: '1',
          roomId: 'room1',
          roomName: 'Room 1',
          senderId: 'user1',
          senderName: 'User 1',
          content: 'Message today',
          messageType: 'text',
          timestamp: now.getTime(),
          relevanceScore: 1.0,
        },
        {
          id: '2',
          roomId: 'room1',
          roomName: 'Room 1',
          senderId: 'user1',
          senderName: 'User 1',
          content: 'Message yesterday',
          messageType: 'text',
          timestamp: yesterday.getTime(),
          relevanceScore: 0.9,
        },
      ];

      const groups = SearchResultsUtils.groupResultsByDate(results);

      expect(groups).toHaveLength(2);
      expect(groups[0].date).toBe('今天');
      expect(groups[0].results).toHaveLength(1);
      expect(groups[1].date).toBe('昨天');
      expect(groups[1].results).toHaveLength(1);
    });
  });

  describe('groupResultsByRoom', () => {
    it('should group results by room', () => {
      const results: MessageSearchResult[] = [
        {
          id: '1',
          roomId: 'room1',
          roomName: 'Room 1',
          senderId: 'user1',
          senderName: 'User 1',
          content: 'Message in room 1',
          messageType: 'text',
          timestamp: Date.now(),
          relevanceScore: 1.0,
        },
        {
          id: '2',
          roomId: 'room2',
          roomName: 'Room 2',
          senderId: 'user2',
          senderName: 'User 2',
          content: 'Message in room 2',
          messageType: 'text',
          timestamp: Date.now(),
          relevanceScore: 0.9,
        },
      ];

      const groups = SearchResultsUtils.groupResultsByRoom(results);

      expect(groups).toHaveLength(2);
      expect(groups[0].roomName).toBe('Room 1');
      expect(groups[1].roomName).toBe('Room 2');
    });
  });

  describe('groupResultsBySender', () => {
    it('should group results by sender', () => {
      const results: MessageSearchResult[] = [
        {
          id: '1',
          roomId: 'room1',
          roomName: 'Room 1',
          senderId: 'user1',
          senderName: 'User 1',
          content: 'Message from user 1',
          messageType: 'text',
          timestamp: Date.now(),
          relevanceScore: 1.0,
        },
        {
          id: '2',
          roomId: 'room1',
          roomName: 'Room 1',
          senderId: 'user2',
          senderName: 'User 2',
          content: 'Message from user 2',
          messageType: 'text',
          timestamp: Date.now(),
          relevanceScore: 0.9,
        },
      ];

      const groups = SearchResultsUtils.groupResultsBySender(results);

      expect(groups).toHaveLength(2);
      expect(groups[0].senderName).toBe('User 1');
      expect(groups[1].senderName).toBe('User 2');
    });
  });
});
