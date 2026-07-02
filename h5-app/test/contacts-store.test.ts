import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it } from 'vitest';

import { resetLocalDatabaseForTests } from '@/storage/local-database';
import { MemorySqlAdapter } from '@/storage/memory-sql-adapter';
import { useAppShellStore } from '@/stores/app-shell';
import { useChatStore } from '@/stores/chat';
import { useContactsStore } from '@/stores/contacts';

const saveSession = () => {
  window.localStorage.setItem(
    'redcode-h5-session',
    JSON.stringify({
      token: 'token-1',
      user: {
        id: 'u1',
        username: 'u1@example.com',
        nickname: 'U1',
        email: 'u1@example.com',
      },
    }),
  );
};

describe('contacts store', () => {
  beforeEach(async () => {
    await resetLocalDatabaseForTests(new MemorySqlAdapter());
    setActivePinia(createPinia());
    saveSession();
  });

  it('initializes mock contacts, caches friends and updates pending badge', async () => {
    const store = useContactsStore();

    await store.initialize();

    expect(store.friends.map((friend) => friend.user.id)).toContain('mock-mia');
    expect(store.pendingIncomingCount).toBe(1);
    expect(useAppShellStore().pendingFriends).toBe(1);
  });

  it('responds to incoming friend requests and restores badge state', async () => {
    const store = useContactsStore();
    await store.initialize();

    await store.respondRequest('mock-request-1', 'accept');

    expect(store.incomingRequests[0]).toMatchObject({ status: 'accepted' });
    expect(useAppShellStore().pendingFriends).toBe(0);
    expect(store.friends.some((friend) => friend.user.id === 'mock-neo')).toBe(true);
  });

  it('searches users and records outgoing friend requests', async () => {
    const store = useContactsStore();

    await store.searchUsers('bear');
    await store.sendFriendRequest(store.searchResults[0]?.id ?? '', 'hello');

    expect(store.searchResults[0]).toMatchObject({ email: 'bear@example.com' });
    expect(store.outgoingRequests[0]).toMatchObject({
      targetUserId: 'mock-search-bear',
      message: 'hello',
      status: 'pending',
    });
  });

  it('creates a group from selected friends and clears draft', async () => {
    const chatStore = useChatStore();
    chatStore.initialized = true;
    const store = useContactsStore();
    await store.initialize();
    store.groupName = 'H5 项目群';
    store.toggleGroupMember('mock-mia');

    const roomId = await store.createGroup();

    expect(roomId).toMatch(/^mock-group-/);
    expect(store.groupName).toBe('');
    expect(store.selectedFriendIds).toEqual([]);
    expect(chatStore.chats.some((chat) => chat.roomId === roomId && chat.type === 'group')).toBe(true);
  });

  it('opens a mock private chat and inserts it into chat summaries', async () => {
    const chatStore = useChatStore();
    chatStore.initialized = true;
    const store = useContactsStore();
    await store.initialize();

    const roomId = await store.openPrivateChat('mock-mia');

    expect(roomId).toBe('mock-private-mock-mia');
    expect(chatStore.chats.find((chat) => chat.roomId === roomId)).toMatchObject({
      name: 'Mia',
      type: 'private',
    });
  });
});
