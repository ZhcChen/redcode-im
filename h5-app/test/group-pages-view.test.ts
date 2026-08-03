import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { appEnv } from '@/config/env';
import { useChatStore } from '@/stores/chat';
import GroupCreateView from '@/views/groups/GroupCreateView.vue';
import GroupDirectoryView from '@/views/groups/GroupDirectoryView.vue';

const router = vi.hoisted(() => ({ push: vi.fn(), replace: vi.fn() }));
vi.mock('vue-router', () => ({ useRouter: () => router }));

describe('group directory and create views', () => {
  beforeEach(() => { setActivePinia(createPinia()); appEnv.useMockData = true; router.push.mockReset(); router.replace.mockReset(); });
  it('renders searchable group directory actions', async () => {
    useChatStore().chats = [{ id: 'r1', roomId: 'r1', name: '项目群', lastMessage: '', lastMessageTime: 1, unreadCount: 0, type: 'group', isPinned: false, isMuted: false }];
    const wrapper = mount(GroupDirectoryView); await flushPromises();
    expect(wrapper.text()).toContain('项目群'); expect(wrapper.text()).toContain('收藏'); expect(wrapper.text()).toContain('设置');
  });
  it('requires a name and at least one contact before creating', async () => {
    const wrapper = mount(GroupCreateView); await flushPromises();
    const create = wrapper.findAll('button').find((button) => button.text() === '创建');
    expect(create?.attributes('disabled')).toBeDefined();
    expect(wrapper.text()).toContain('Mia');
  });
});
