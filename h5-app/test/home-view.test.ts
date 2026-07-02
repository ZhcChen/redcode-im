import { mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { useAuthStore } from '@/stores/auth';
import { useChatStore } from '@/stores/chat';
import HomeView from '@/views/HomeView.vue';

vi.mock('vue-router', () => ({
  useRouter: () => ({
    replace: vi.fn(),
  }),
}));

describe('HomeView chat tab', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('renders chat list from chat store instead of static mock rows', () => {
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
        lastMessage: '来自后端会话列表',
        lastMessageTime: Date.parse('2026-07-02T09:30:00+08:00'),
        unreadCount: 4,
        type: 'group',
        isPinned: false,
        isMuted: false,
      },
    ];

    const wrapper = mount(HomeView);

    expect(wrapper.text()).toContain('真实项目群');
    expect(wrapper.text()).toContain('来自后端会话列表');
    expect(wrapper.text()).toContain('4');
    expect(wrapper.text()).not.toContain('H5 App 已接入邮箱注册和登录流程');
  });
});
