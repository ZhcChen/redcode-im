import { SearchApi, SearchUtils, type IndexMessage } from '@/api/search';
import type { Message } from '@/types/models';

/**
 * 消息搜索服务
 * 负责管理消息索引和搜索功能
 */
export class MessageSearchService {
  private static instance: MessageSearchService;
  private isIndexing = false;
  private indexQueue: IndexMessage[] = [];
  private batchSize = 100;
  private indexTimeout: NodeJS.Timeout | null = null;

  private constructor() {}

  static getInstance(): MessageSearchService {
    if (!MessageSearchService.instance) {
      MessageSearchService.instance = new MessageSearchService();
    }
    return MessageSearchService.instance;
  }

  /**
   * 索引单个消息
   */
  async indexMessage(message: Message, roomName: string): Promise<void> {
    const indexMessage = SearchUtils.messageToIndex(message, roomName);
    await SearchApi.indexMessage(indexMessage);
  }

  /**
   * 批量索引消息（优化性能）
   */
  async indexMessages(messages: Message[], roomName: string): Promise<void> {
    if (messages.length === 0) return;

    const indexMessages = messages.map(msg => SearchUtils.messageToIndex(msg, roomName));

    // 分批处理，避免一次性索引太多消息
    for (let i = 0; i < indexMessages.length; i += this.batchSize) {
      const batch = indexMessages.slice(i, i + this.batchSize);
      await SearchApi.indexMessages(batch);

      // 添加小延迟，避免阻塞UI
      if (i + this.batchSize < indexMessages.length) {
        await new Promise(resolve => setTimeout(resolve, 10));
      }
    }
  }

  /**
   * 异步索引消息（不阻塞主线程）
   */
  async indexMessageAsync(message: Message, roomName: string): Promise<void> {
    this.indexQueue.push(SearchUtils.messageToIndex(message, roomName));
    this.scheduleIndexing();
  }

  /**
   * 移除消息索引
   */
  async removeMessageIndex(messageId: string): Promise<void> {
    await SearchApi.removeMessageIndex(messageId);
  }

  /**
   * 清空所有索引
   */
  async clearAllIndices(): Promise<void> {
    await SearchApi.clearAllIndices();
    this.indexQueue = [];
  }

  /**
   * 搜索消息
   */
  async searchMessages(params: {
    query: string;
    roomId?: string;
    senderId?: string;
    messageType?: string;
    dateFrom?: Date;
    dateTo?: Date;
    limit?: number;
    offset?: number;
  }) {
    return SearchApi.searchMessages(params);
  }

  /**
   * 获取搜索建议
   */
  async getSearchSuggestions(prefix: string, limit?: number): Promise<string[]> {
    return SearchApi.getSearchSuggestions(prefix, limit);
  }

  /**
   * 获取搜索统计
   */
  async getSearchStats() {
    return SearchApi.getSearchStats();
  }

  /**
   * 优化搜索数据库
   */
  async optimizeSearchDb(): Promise<void> {
    await SearchApi.optimizeSearchDb();
  }

  /**
   * 安排索引任务
   */
  private scheduleIndexing(): void {
    if (this.indexTimeout) {
      clearTimeout(this.indexTimeout);
    }

    this.indexTimeout = setTimeout(async () => {
      await this.processIndexQueue();
    }, 500); // 500ms延迟，批量处理
  }

  /**
   * 处理索引队列
   */
  private async processIndexQueue(): Promise<void> {
    if (this.isIndexing || this.indexQueue.length === 0) {
      return;
    }

    this.isIndexing = true;

    try {
      // 取出一批消息进行索引
      const batch = this.indexQueue.splice(0, this.batchSize);
      if (batch.length > 0) {
        await SearchApi.indexMessages(batch);
      }

      // 如果还有消息，继续处理
      if (this.indexQueue.length > 0) {
        this.scheduleIndexing();
      }
    } catch (error) {
      console.error('消息索引失败:', error);
    } finally {
      this.isIndexing = false;
    }
  }

  /**
   * 强制处理所有待索引消息
   */
  async flushIndexQueue(): Promise<void> {
    while (this.indexQueue.length > 0) {
      await this.processIndexQueue();
      // 小延迟避免阻塞
      await new Promise(resolve => setTimeout(resolve, 10));
    }
  }

  /**
   * 初始化消息搜索索引
   */
  async initializeSearchIndex(messages: Message[], roomName: string): Promise<void> {
    if (messages.length === 0) return;

    console.log(`🔍 初始化搜索索引，消息数量: ${messages.length}`);

    try {
      // 先清空旧索引（可选，根据需求决定）
      // await this.clearAllIndices();

      // 批量索引所有消息
      await this.indexMessages(messages, roomName);

      console.log('✅ 搜索索引初始化完成');
    } catch (error) {
      console.error('❌ 搜索索引初始化失败:', error);
    }
  }

  /**
   * 更新消息索引
   */
  async updateMessageIndex(
    oldMessage: Message | null,
    newMessage: Message,
    roomName: string
  ): Promise<void> {
    if (oldMessage && oldMessage.id === newMessage.id) {
      // 更新现有消息
      await this.indexMessage(newMessage, roomName);
    } else {
      // 新消息
      await this.indexMessageAsync(newMessage, roomName);
    }
  }

  /**
   * 删除消息索引
   */
  async deleteMessageIndex(messageId: string): Promise<void> {
    await this.removeMessageIndex(messageId);
  }

  /**
   * 获取索引队列状态
   */
  getIndexQueueStatus(): {
    queueLength: number;
    isIndexing: boolean;
  } {
    return {
      queueLength: this.indexQueue.length,
      isIndexing: this.isIndexing,
    };
  }
}

// 导出单例实例
export const messageSearchService = MessageSearchService.getInstance();