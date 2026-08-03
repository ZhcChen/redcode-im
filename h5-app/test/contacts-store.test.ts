import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { appEnv } from '@/config/env';
import { roomService } from '@/services/room-service';
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
    appEnv.useMockData = true;
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

  it('updates remarks and removes friends from the persisted contact state', async () => {
    const store = useContactsStore();
    await store.initialize();

    await store.updateFriendRemark('mock-mia', '项目搭档');
    expect(store.friends.find((friend) => friend.user.id === 'mock-mia')?.remark).toBe('项目搭档');

    await store.deleteFriend('mock-mia');
    expect(store.friends.some((friend) => friend.user.id === 'mock-mia')).toBe(false);
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

  it('keeps the created group summary when the immediate backend refresh is stale', async () => {
    appEnv.useMockData = false;
    vi.spyOn(roomService, 'createGroup').mockResolvedValue({
      id: 'r-created',
      name: '刚创建的群',
      roomType: 'group',
      ownerId: 'u1',
    });
    const chatStore = useChatStore();
    vi.spyOn(chatStore, 'refreshChats').mockImplementation(async () => {
      chatStore.chats = [];
    });
    const store = useContactsStore();
    store.initialized = true;
    store.friends = [{
      id: 'f1',
      user: {
        id: 'u2',
        username: 'u2@example.com',
        nickname: 'U2',
        email: 'u2@example.com',
      },
      createdAt: '2026-07-02T00:00:00Z',
      remark: null,
    }];
    store.groupName = '刚创建的群';
    store.toggleGroupMember('u2');

    const roomId = await store.createGroup();

    expect(roomId).toBe('r-created');
    expect(chatStore.chats.find((chat) => chat.roomId === roomId)).toMatchObject({
      name: '刚创建的群',
      type: 'group',
    });
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
