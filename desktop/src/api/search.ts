import { invoke } from '@tauri-apps/api/core';

// 消息搜索结果
export interface MessageSearchResult {
  id: string;
  roomId: string;
  roomName: string;
  senderId: string;
  senderName: string;
  content: string;
  messageType: string;
  timestamp: number;
  matchedText?: string; // 匹配的文本片段
  relevanceScore: number; // 相关性评分
}

// 搜索参数
export interface SearchParams {
  query: string;
  roomId?: string;
  senderId?: string;
  messageType?: string;
  dateFrom?: number;
  dateTo?: number;
  limit?: number;
  offset?: number;
}

// 搜索统计
export interface SearchStats {
  totalResults: number;
  searchTimeMs: number;
  query: string;
}

// 索引消息信息
export interface IndexMessage {
  id: string;
  roomId: string;
  roomName: string;
  senderId: string;
  senderName: string;
  content: string;
  messageType: string;
  timestamp: number;
}

// 搜索API
export class SearchApi {
  /**
   * 将前端消息格式转换为 Rust 后端期望的格式（驼峰转下划线）
   */
  private static toRustFormat(message: IndexMessage): any {
    return {
      id: message.id,
      room_id: message.roomId,  // 转换为下划线格式
      room_name: message.roomName,
      sender_id: message.senderId,
      sender_name: message.senderName,
      content: message.content,
      message_type: message.messageType,
      timestamp: message.timestamp
    };
  }

  /**
   * 索引单个消息
   */
  static async indexMessage(message: IndexMessage): Promise<void> {
    const rustMessage = this.toRustFormat(message);
    return invoke('index_message', { message: rustMessage });
  }

  /**
   * 批量索引消息
   */
  static async indexMessages(messages: IndexMessage[]): Promise<void> {
    const rustMessages = messages.map(m => this.toRustFormat(m));
    return invoke('index_messages', { messages: rustMessages });
  }

  /**
   * 删除消息索引
   */
  static async removeMessageIndex(messageId: string): Promise<void> {
    return invoke('remove_message_index', { messageId });
  }

  /**
   * 清空所有索引
   */
  static async clearAllIndices(): Promise<void> {
    return invoke('clear_all_indices');
  }

  /**
   * 搜索消息
   */
  static async searchMessages(
    params: SearchParams
  ): Promise<[MessageSearchResult[], SearchStats]> {
    return invoke('search_messages', { params });
  }

  /**
   * 获取搜索建议
   */
  static async getSearchSuggestions(
    prefix: string,
    limit?: number
  ): Promise<string[]> {
    return invoke('get_search_suggestions', { prefix, limit });
  }

  /**
   * 获取搜索统计信息
   */
  static async getSearchStats(): Promise<{
    totalMessages: number;
    totalRooms: number;
    totalSenders: number;
    dbSizeBytes: number;
    dbSizeMb: string;
  }> {
    return invoke('get_search_stats');
  }

  /**
   * 优化搜索数据库
   */
  static async optimizeSearchDb(): Promise<void> {
    return invoke('optimize_search_db');
  }
}

// 搜索工具函数
export class SearchUtils {
  /**
   * 从Message对象创建IndexMessage
   */
  static messageToIndex(message: any, roomName: string, roomId?: string): IndexMessage {
    // 处理 timestamp：可能是 Date 对象或数字
    let timestamp: number
    if (message.timestamp instanceof Date) {
      timestamp = message.timestamp.getTime()
    } else if (typeof message.timestamp === 'number') {
      timestamp = message.timestamp
    } else if (message.createTime) {
      // 如果没有 timestamp，使用 createTime
      timestamp = new Date(message.createTime).getTime()
    } else {
      timestamp = Date.now()
    }
    
    // 确保 roomId 存在
    const finalRoomId = message.roomId || roomId || ''
    if (!finalRoomId) {
      console.warn('⚠️ 消息缺少 roomId:', { id: message.id, roomName })
    }
    
    return {
      id: message.id,
      roomId: finalRoomId,
      roomName,
      senderId: message.senderId || '',
      senderName: message.senderName || message.senderUsername || '',
      content: typeof message.content === 'string' ? message.content : (message.content?.text || ''),
      messageType: message.messageType || message.type || 'text',
      timestamp,
    };
  }

  /**
   * 格式化搜索结果高亮
   */
  static formatHighlightedText(text: string): string {
    return text.replace(/<mark>/g, '<mark class="search-highlight">')
              .replace(/<\/mark>/g, '</mark>');
  }

  /**
   * 格式化时间戳为可读时间
   */
  static formatTimestamp(timestamp: number): string {
    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (diffDays === 0) {
      // 今天，显示时间
      return date.toLocaleTimeString('zh-CN', {
        hour: '2-digit',
        minute: '2-digit',
      });
    } else if (diffDays === 1) {
      // 昨天
      return '昨天 ' + date.toLocaleTimeString('zh-CN', {
        hour: '2-digit',
        minute: '2-digit',
      });
    } else if (diffDays < 7) {
      // 本周，显示星期
      const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
      return weekdays[date.getDay()] + ' ' + date.toLocaleTimeString('zh-CN', {
        hour: '2-digit',
        minute: '2-digit',
      });
    } else {
      // 更早，显示日期
      return date.toLocaleDateString('zh-CN', {
        month: '2-digit',
        day: '2-digit',
      });
    }
  }

  /**
   * 构建搜索查询（支持高级语法）
   */
  static buildSearchQuery(
    searchText: string,
    filters: {
      roomId?: string;
      senderId?: string;
      messageType?: string;
      dateFrom?: Date;
      dateTo?: Date;
    } = {}
  ): SearchParams {
    const params: SearchParams = {
      query: searchText.trim(),
      limit: 50,
    };

    if (filters.roomId) {
      params.roomId = filters.roomId;
    }

    if (filters.senderId) {
      params.senderId = filters.senderId;
    }

    if (filters.messageType) {
      params.messageType = filters.messageType;
    }

    if (filters.dateFrom) {
      params.dateFrom = filters.dateFrom.getTime();
    }

    if (filters.dateTo) {
      params.dateTo = filters.dateTo.getTime();
    }

    return params;
  }

  /**
   * 验证搜索查询
   */
  static validateSearchQuery(query: string): {
    isValid: boolean;
    error?: string;
  } {
    const trimmed = query.trim();

    if (trimmed.length === 0) {
      return { isValid: false, error: '搜索内容不能为空' };
    }

    if (trimmed.length > 200) {
      return { isValid: false, error: '搜索内容过长，最多200个字符' };
    }

    // 检查是否包含无效字符
    const invalidChars = /[<>]/;
    if (invalidChars.test(trimmed)) {
      return { isValid: false, error: '搜索内容包含无效字符' };
    }

    return { isValid: true };
  }

  /**
   * 获取搜索建议的防抖函数
   */
  static debounceSuggestions(
    callback: (query: string) => void,
    delay: number = 300
  ): (query: string) => void {
    let timeoutId: NodeJS.Timeout;

    return (query: string) => {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => {
        callback(query);
      }, delay);
    };
  }

  /**
   * 高亮搜索关键词
   */
  static highlightKeywords(text: string, keywords: string): string {
    if (!keywords.trim()) {
      return text;
    }

    const keywordList = keywords.split(/\s+/).filter(k => k.length > 0);
    let highlightedText = text;

    keywordList.forEach(keyword => {
      if (keyword.length > 0) {
        const regex = new RegExp(`(${keyword})`, 'gi');
        highlightedText = highlightedText.replace(regex, '<mark class="search-highlight">$1</mark>');
      }
    });

    return highlightedText;
  }
}

// 搜索结果分组
export interface SearchResultsGroup {
  date: string;
  results: MessageSearchResult[];
}

export class SearchResultsUtils {
  /**
   * 按日期分组搜索结果
   */
  static groupResultsByDate(results: MessageSearchResult[]): SearchResultsGroup[] {
    const groups: { [key: string]: MessageSearchResult[] } = {};

    results.forEach(result => {
      const date = new Date(result.timestamp);
      const dateKey = this.getDateKey(date);

      if (!groups[dateKey]) {
        groups[dateKey] = [];
      }
      groups[dateKey].push(result);
    });

    return Object.entries(groups)
      .map(([date, results]) => ({ date, results }))
      .sort((a, b) => b.results[0].timestamp - a.results[0].timestamp);
  }

  /**
   * 获取日期键
   */
  private static getDateKey(date: Date): string {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);
    const compareDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());

    if (compareDate.getTime() === today.getTime()) {
      return '今天';
    } else if (compareDate.getTime() === yesterday.getTime()) {
      return '昨天';
    } else if (date.getFullYear() === now.getFullYear()) {
      return date.toLocaleDateString('zh-CN', {
        month: 'long',
        day: 'numeric',
      });
    } else {
      return date.toLocaleDateString('zh-CN', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      });
    }
  }

  /**
   * 按房间分组搜索结果
   */
  static groupResultsByRoom(results: MessageSearchResult[]): { roomName: string; results: MessageSearchResult[] }[] {
    const groups: { [key: string]: MessageSearchResult[] } = {};

    results.forEach(result => {
      const roomName = result.roomName;

      if (!groups[roomName]) {
        groups[roomName] = [];
      }
      groups[roomName].push(result);
    });

    return Object.entries(groups)
      .map(([roomName, results]) => ({ roomName, results }))
      .sort((a, b) => a.roomName.localeCompare(b.roomName, 'zh-CN'));
  }

  /**
   * 按发送者分组搜索结果
   */
  static groupResultsBySender(results: MessageSearchResult[]): { senderName: string; results: MessageSearchResult[] }[] {
    const groups: { [key: string]: MessageSearchResult[] } = {};

    results.forEach(result => {
      const senderName = result.senderName;

      if (!groups[senderName]) {
        groups[senderName] = [];
      }
      groups[senderName].push(result);
    });

    return Object.entries(groups)
      .map(([senderName, results]) => ({ senderName, results }))
      .sort((a, b) => a.senderName.localeCompare(b.senderName, 'zh-CN'));
  }
}