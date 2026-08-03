import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { useChatStore } from '@/stores/chat';
import { useAuthStore } from '@/stores/auth';
import { useMessageActionsStore } from '@/stores/message-actions';
import MessageForwardView from '@/views/MessageForwardView.vue';
import MessageReadersView from '@/views/MessageReadersView.vue';

const routeParams = vi.hoisted(() => ({ roomId: 'room-source', messageId: 'message-1' }));
const routerPushMock = vi.hoisted(() => vi.fn());

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: routeParams }),
  useRouter: () => ({ push: routerPushMock }),
}));

describe('message action views', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    routerPushMock.mockReset();
    useAuthStore().session = {
      token: 'token-1',
      user: { id: 'sender', username: 'sender', nickname: 'Sender', email: '' },
    };
  });

  it('renders typed message readers and refreshes the current message', async () => {
    const store = useMessageActionsStore();
    store.readers = [{
      userId: 'u1',
      username: 'alice',
      nickname: 'Alice',
      avatarUrl: null,
      readAt: Date.parse('2026-08-04T00:00:00Z'),
    }];
    store.members = [
      { userId: 'sender', username: 'sender', nickname: 'Sender', avatarUrl: null },
      { userId: 'u1', username: 'alice', nickname: 'Alice', avatarUrl: null },
      { userId: 'u2', username: 'bob', nickname: 'Bob', avatarUrl: null },
    ];
    store.senderId = 'sender';
    const loadReaders = vi.spyOn(store, 'loadReaders').mockResolvedValue();

    const wrapper = mount(MessageReadersView);
    await flushPromises();

    expect(wrapper.text()).toContain('已读成员');
    expect(wrapper.text()).toContain('Alice');
    expect(wrapper.text()).toContain('已读 1');
    expect(wrapper.text()).toContain('未读 1');
    expect(loadReaders).toHaveBeenCalledWith('room-source', 'message-1', 'sender');
  });

  it('selects a target chat and returns to the source after forwarding', async () => {
    const chatStore = useChatStore();
    chatStore.initialized = true;
    chatStore.chats = [{
      id: 'room-target',
      roomId: 'room-target',
      name: '目标群聊',
      lastMessage: '',
      lastMessageTime: 0,
      unreadCount: 0,
      type: 'group',
      isPinned: false,
      isMuted: false,
    }];
    const actionStore = useMessageActionsStore();
    const forwardMessage = vi.spyOn(actionStore, 'forwardMessage').mockResolvedValue({
      succeeded: ['room-target'],
      failed: [],
    });

    const wrapper = mount(MessageForwardView);
    await flushPromises();
    await wrapper.get('.forward-row').trigger('click');
    await wrapper.get('.message-action-submit').trigger('click');
    await flushPromises();

    expect(forwardMessage).toHaveBeenCalledWith('message-1', ['room-target']);
    expect(routerPushMock).toHaveBeenCalledWith({
      name: 'chat-detail',
      params: { roomId: 'room-source' },
    });
  });
});
