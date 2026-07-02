import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { useAuthStore } from '@/stores/auth';
import { useChatStore } from '@/stores/chat';
import ChatDetailView from '@/views/ChatDetailView.vue';

vi.mock('vue-router', () => ({
  useRoute: () => ({
    params: { roomId: 'r1' },
  }),
  useRouter: () => ({
    push: vi.fn(),
  }),
}));

describe('ChatDetailView', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
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
      name: '真实项目群',
      avatar: null,
      avatarObjectKey: null,
      lastMessage: '来自详情页',
      lastMessageTime: Date.now(),
      unreadCount: 0,
      type: 'group',
      isPinned: false,
      isMuted: false,
    }];
  });

  it('renders room title, message list and composer', async () => {
    const wrapper = mount(ChatDetailView);
    await flushPromises();

    expect(wrapper.text()).toContain('真实项目群');
    expect(wrapper.find('#message-input').exists()).toBe(true);
    expect(wrapper.text()).toContain('H5 聊天详情已接入本地缓存和发送状态。');
    expect(wrapper.text()).toContain('引用');
    expect(wrapper.text()).toContain('置顶');
  });
});
