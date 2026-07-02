import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it } from 'vitest';

import { resetLocalDatabaseForTests } from '@/storage/local-database';
import { MemorySqlAdapter } from '@/storage/memory-sql-adapter';
import { useChatStore } from '@/stores/chat';
import { useGroupSettingsStore } from '@/stores/group-settings';

describe('group settings store', () => {
  beforeEach(async () => {
    await resetLocalDatabaseForTests(new MemorySqlAdapter());
    setActivePinia(createPinia());
    const chatStore = useChatStore();
    chatStore.chats = [{
      id: 'r1',
      roomId: 'r1',
      name: 'H5 验收群',
      avatar: null,
      avatarObjectKey: null,
      lastMessage: '',
      lastMessageTime: 1,
      unreadCount: 0,
      type: 'group',
      isPinned: false,
      isMuted: false,
    }];
  });

  it('loads mock group settings from chat context', async () => {
    const store = useGroupSettingsStore();

    await store.enterRoom('r1');

    expect(store.room).toMatchObject({ id: 'r1', name: 'H5 验收群' });
    expect(store.members.length).toBeGreaterThan(0);
    expect(store.draftName).toBe('H5 验收群');
  });

  it('toggles pinned state through chat store', async () => {
    const store = useGroupSettingsStore();
    await store.enterRoom('r1');

    await store.togglePinned();

    expect(store.pinned).toBe(true);
    expect(useChatStore().chats[0]?.isPinned).toBe(true);
  });
});
