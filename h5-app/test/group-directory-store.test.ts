import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it } from 'vitest';
import { appEnv } from '@/config/env';
import { useChatStore } from '@/stores/chat';
import { useGroupDirectoryStore } from '@/stores/group-directory';

describe('group directory store', () => {
  beforeEach(() => { setActivePinia(createPinia()); appEnv.useMockData = true; });
  it('loads groups, filters them and keeps favorites first', async () => {
    useChatStore().chats = [
      { id: 'r1', roomId: 'r1', name: '项目一群', lastMessage: '', lastMessageTime: 1, unreadCount: 0, type: 'group', isPinned: false, isMuted: false },
      { id: 'r2', roomId: 'r2', name: '运营群', lastMessage: '', lastMessageTime: 2, unreadCount: 0, type: 'group', isPinned: false, isMuted: false },
    ];
    const store = useGroupDirectoryStore();
    await store.load();
    await store.toggleFavorite('r2');
    expect(store.filteredEntries[0]).toMatchObject({ roomId: 'r2', isFavorited: true });
    store.keyword = '项目';
    expect(store.filteredEntries.map((entry) => entry.roomId)).toEqual(['r1']);
  });
});
