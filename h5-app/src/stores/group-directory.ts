import { defineStore } from 'pinia';
import { appEnv } from '@/config/env';
import { roomService } from '@/services/room-service';
import type { GroupDirectoryEntry } from '@/types/room';
import { useChatStore } from './chat';

export const useGroupDirectoryStore = defineStore('groupDirectory', {
  state: () => ({ entries: [] as GroupDirectoryEntry[], keyword: '', loading: false, error: '' }),
  getters: {
    filteredEntries: (state) => {
      const query = state.keyword.trim().toLowerCase();
      const rows = query ? state.entries.filter((entry) => [entry.name, entry.description].some((value) => String(value ?? '').toLowerCase().includes(query))) : state.entries;
      return rows.slice().sort((a, b) => Number(b.isFavorited) - Number(a.isFavorited) || a.name.localeCompare(b.name, 'zh-CN'));
    },
  },
  actions: {
    async load() {
      this.loading = true; this.error = '';
      try {
        if (appEnv.useMockData) {
          this.entries = useChatStore().chats.filter((chat) => chat.type === 'group').map((chat) => ({
            roomId: chat.roomId, name: chat.name, description: String(chat.raw?.description ?? '') || null,
            avatarUrl: chat.avatar ?? null, avatarObjectKey: chat.avatarObjectKey ?? null,
            memberCount: Number(chat.raw?.member_count ?? 0), isFavorited: false, favoritedAt: null,
          }));
        } else this.entries = await roomService.listGroupDirectory();
      } catch (error) { this.error = error instanceof Error ? error.message : '加载群目录失败'; }
      finally { this.loading = false; }
    },
    async toggleFavorite(roomId: string) {
      const entry = this.entries.find((item) => item.roomId === roomId);
      if (!entry) return;
      const next = !entry.isFavorited;
      this.entries = this.entries.map((item) => item.roomId === roomId ? { ...item, isFavorited: next, favoritedAt: next ? new Date().toISOString() : null } : item);
      try { if (!appEnv.useMockData) await roomService.favoriteGroupDirectory(roomId, next); }
      catch (error) {
        this.entries = this.entries.map((item) => item.roomId === roomId ? entry : item);
        this.error = error instanceof Error ? error.message : '更新群目录收藏失败';
      }
    },
  },
});
