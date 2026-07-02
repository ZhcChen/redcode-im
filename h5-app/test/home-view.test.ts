import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { useAuthStore } from '@/stores/auth';
import { useChatStore } from '@/stores/chat';
import { useAppShellStore } from '@/stores/app-shell';
import { useContactsStore } from '@/stores/contacts';
import HomeView from '@/views/HomeView.vue';

vi.mock('vue-router', () => ({
  useRouter: () => ({
    push: vi.fn(),
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

  it('renders contacts, requests and group creation controls', async () => {
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
    const shellStore = useAppShellStore();
    shellStore.switchTab('contacts');
    const contactsStore = useContactsStore();
    contactsStore.initialized = true;
    contactsStore.friends = [{
      id: 'f1',
      user: {
        id: 'u2',
        username: 'mia@example.com',
        nickname: 'Mia',
        email: 'mia@example.com',
      },
      createdAt: '2026-07-02T00:00:00Z',
      remark: null,
    }];
    contactsStore.incomingRequests = [{
      id: 'req1',
      requesterId: 'u3',
      targetUserId: 'u1',
      message: '加个好友',
      status: 'pending',
      createdAt: '2026-07-02T00:00:00Z',
      requester: {
        id: 'u3',
        username: 'neo@example.com',
        nickname: 'Neo',
        email: 'neo@example.com',
      },
      targetUser: null,
    }];

    const wrapper = mount(HomeView);
    await flushPromises();

    expect(wrapper.text()).toContain('新的朋友');
    expect(wrapper.text()).toContain('Neo');
    expect(wrapper.text()).toContain('Mia');
    expect(wrapper.text()).toContain('新建群聊');
  });
});
