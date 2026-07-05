import { defineStore } from 'pinia';

import { MessageSearchStorage } from '@/storage/message-search-storage';
import type { ChatMessage, MessageSearchResult, MessageType } from '@/types/chat';

const messageSearchStorage = new MessageSearchStorage();
const DEFAULT_LIMIT = 20;

export const useMessageSearchStore = defineStore('messageSearch', {
  state: () => ({
    keyword: '',
    roomId: '',
    messageType: '' as MessageType | '',
    results: [] as MessageSearchResult[],
    loading: false,
    error: '',
    hasMore: false,
    totalResults: 0,
    searchTimeMs: 0,
    offset: 0,
    limit: DEFAULT_LIMIT,
    lastIndexError: '',
  }),
  getters: {
    hasQuery: (state) => state.keyword.trim().length > 0,
    summary: (state) => {
      if (!state.keyword.trim()) return '输入关键词搜索本地聊天记录';
      if (state.loading && state.results.length === 0) return '正在搜索本地消息...';
      if (state.error) return state.error;
      return `找到 ${state.totalResults} 条结果，用时 ${state.searchTimeMs}ms`;
    },
  },
  actions: {
    setKeyword(keyword: string) {
      this.keyword = keyword;
    },

    setRoomId(roomId: string) {
      this.roomId = roomId;
    },

    setMessageType(messageType: MessageType | '') {
      this.messageType = messageType;
    },

    clear() {
      this.keyword = '';
      this.roomId = '';
      this.messageType = '';
      this.results = [];
      this.error = '';
      this.hasMore = false;
      this.totalResults = 0;
      this.searchTimeMs = 0;
      this.offset = 0;
    },

    async search(options: { append?: boolean } = {}) {
      const query = this.keyword.trim();
      if (!query) {
        this.results = [];
        this.error = '';
        this.hasMore = false;
        this.totalResults = 0;
        this.searchTimeMs = 0;
        this.offset = 0;
        return;
      }

      const offset = options.append ? this.offset : 0;
      this.loading = true;
      this.error = '';
      try {
        const response = await messageSearchStorage.searchMessages({
          query,
          roomId: this.roomId || undefined,
          messageType: this.messageType || undefined,
          limit: this.limit,
          offset,
        });
        this.results = options.append ? [...this.results, ...response.results] : response.results;
        this.totalResults = response.stats.totalResults;
        this.searchTimeMs = response.stats.searchTimeMs;
        this.hasMore = response.hasMore;
        this.offset = offset + response.results.length;
      } catch (error) {
        this.error = error instanceof Error ? error.message : '搜索本地消息失败';
        if (!options.append) {
          this.results = [];
          this.hasMore = false;
          this.totalResults = 0;
          this.searchTimeMs = 0;
          this.offset = 0;
        }
      } finally {
        this.loading = false;
      }
    },

    async loadMore() {
      if (this.loading || !this.hasMore) return;
      await this.search({ append: true });
    },

    async replaceRoomIndex(params: { roomId: string; roomName: string; messages: ChatMessage[] }) {
      try {
        await messageSearchStorage.replaceRoomIndex(params);
        if (this.lastIndexError) this.lastIndexError = '';
      } catch (error) {
        this.lastIndexError = error instanceof Error ? error.message : '消息索引写入失败';
        console.warn('[h5-app] 消息搜索索引写入失败，已忽略', error);
      }
    },
  },
});
