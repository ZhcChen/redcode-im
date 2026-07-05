import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { resetLocalDatabaseForTests } from '@/storage/local-database';
import { MemorySqlAdapter } from '@/storage/memory-sql-adapter';
import { MessageSearchStorage } from '@/storage/message-search-storage';
import { useAuthStore } from '@/stores/auth';
import { useChatStore } from '@/stores/chat';
import MessageSearchView from '@/views/MessageSearchView.vue';

const routerPush = vi.fn();
let routeQuery: Record<string, string> = {};

vi.mock('vue-router', () => ({
  useRoute: () => ({
    query: routeQuery,
  }),
  useRouter: () => ({
    push: routerPush,
  }),
}));

describe('MessageSearchView', () => {
  let adapter: MemorySqlAdapter;

  beforeEach(async () => {
    adapter = new MemorySqlAdapter();
    await resetLocalDatabaseForTests(adapter);
    setActivePinia(createPinia());
    routeQuery = {};
    routerPush.mockReset();
    const authStore = useAuthStore();
    authStore.session = {
      token: 'token-1',
      user: {
        id: 'u1',
        username: 'u1@example.com',
        nickname: 'U1',
        email: 'u1@example.com',
      },
    };
    const chatStore = useChatStore();
    chatStore.initialized = true;
    chatStore.chats = [{
      id: 'r1',
      roomId: 'r1',
      name: '搜索项目群',
      avatar: null,
      avatarObjectKey: null,
      lastMessage: 'browser sqlite cache',
      lastMessageTime: 1,
      unreadCount: 0,
      type: 'group',
      isPinned: false,
      isMuted: false,
    }];
    await new MessageSearchStorage(async () => adapter).replaceRoomIndex({
      roomId: 'r1',
      roomName: '搜索项目群',
      messages: [{
        id: 'm1',
        roomId: 'r1',
        senderId: 'u2',
        senderName: 'Bear',
        content: 'browser sqlite cache',
        type: 'text',
        timestamp: 2000,
      }],
    });
  });

  it('searches local messages and opens the selected chat result', async () => {
    const wrapper = mount(MessageSearchView);
    await flushPromises();

    await wrapper.find('input[placeholder="输入关键词、联系人或群名"]').setValue('sqlite');
    await wrapper.find('form').trigger('submit.prevent');
    await flushPromises();

    expect(wrapper.text()).toContain('搜索项目群');
    expect(wrapper.text()).toContain('browser sqlite cache');

    await wrapper.find('.message-search__result-button').trigger('click');

    expect(routerPush).toHaveBeenCalledWith({
      name: 'chat-detail',
      params: { roomId: 'r1' },
      query: { messageId: 'm1' },
    });
  });

  it('applies initial room and keyword from route query', async () => {
    routeQuery = { roomId: 'r1', q: 'browser' };

    const wrapper = mount(MessageSearchView);
    await flushPromises();

    expect(wrapper.find('select').element.value).toBe('r1');
    expect(wrapper.text()).toContain('browser sqlite cache');
  });
});
