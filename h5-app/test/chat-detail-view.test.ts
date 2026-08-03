import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { useAuthStore } from '@/stores/auth';
import { useChatStore } from '@/stores/chat';
import ChatDetailView from '@/views/ChatDetailView.vue';

let routeRoomId = 'r1';
const routerPushMock = vi.hoisted(() => vi.fn());

vi.mock('vue-router', () => ({
  useRoute: () => ({
    params: { roomId: routeRoomId },
  }),
  useRouter: () => ({
    push: routerPushMock,
  }),
}));

describe('ChatDetailView', () => {
  beforeEach(() => {
    routeRoomId = 'r1';
    routerPushMock.mockReset();
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
    chatStore.chats = [
      {
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
      },
      {
        id: 'favorite-real',
        roomId: 'favorite-real',
        name: '收藏夹',
        avatar: null,
        avatarObjectKey: null,
        lastMessage: '保存的消息和文件会出现在这里',
        lastMessageTime: Date.now(),
        unreadCount: 0,
        type: 'favorite',
        isPinned: true,
        isMuted: false,
      },
    ];
  });

  it('renders room title, message list and composer', async () => {
    const wrapper = mount(ChatDetailView);
    await flushPromises();

    expect(wrapper.text()).toContain('真实项目群');
    expect(wrapper.find('#message-input').exists()).toBe(true);
    expect(wrapper.get('input[aria-label="选择图片"]').attributes('accept')).toBe('image/*');
    expect(wrapper.find('input[aria-label="选择文件"]').exists()).toBe(true);
    expect(wrapper.get('button[aria-label="发送图片"]').text()).toBe('图片');
    expect(wrapper.get('button[aria-label="发送文件"]').text()).toBe('文件');
    expect(wrapper.text()).toContain('H5 聊天详情已接入本地缓存和发送状态。');
    expect(wrapper.text()).toContain('引用');
    expect(wrapper.text()).toContain('置顶');
    expect(wrapper.text()).toContain('转发');
    expect(wrapper.text()).toContain('已读详情');

    await wrapper.findAll('button').find((button) => button.text() === '转发')?.trigger('click');
    expect(routerPushMock).toHaveBeenCalledWith({
      name: 'message-forward',
      params: expect.objectContaining({ roomId: 'r1' }),
    });
  });

  it('resolves the favorite route alias to the real favorite room id', async () => {
    routeRoomId = 'favorite';

    const wrapper = mount(ChatDetailView);
    await flushPromises();

    expect(wrapper.text()).toContain('收藏夹');
  });
});
