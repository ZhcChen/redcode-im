import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { appEnv } from '@/config/env';
import { useAuthStore } from '@/stores/auth';
import { useChatStore } from '@/stores/chat';
import GroupMembersView from '@/views/groups/GroupMembersView.vue';
import GroupInviteView from '@/views/groups/GroupInviteView.vue';
import GroupSettingsView from '@/views/GroupSettingsView.vue';

const router = vi.hoisted(() => ({ push: vi.fn(), replace: vi.fn() }));
vi.mock('vue-router', () => ({ useRoute: () => ({ params: { roomId: 'r1' } }), useRouter: () => router }));

describe('group member permissions', () => {
  beforeEach(() => {
    setActivePinia(createPinia()); appEnv.useMockData = true;
    useAuthStore().session = { token: 'token', user: { id: 'mock-current', username: 'owner', nickname: '我', email: '' } };
    useChatStore().chats = [{ id: 'r1', roomId: 'r1', name: '权限群', lastMessage: '', lastMessageTime: 1, unreadCount: 0, type: 'group', isPinned: false, isMuted: false }];
  });

  it('allows the owner to invite and remove ordinary members', async () => {
    const wrapper = mount(GroupMembersView); await flushPromises();
    expect(wrapper.text()).toContain('邀请');
    expect(wrapper.text()).toContain('移除');
    expect(wrapper.findAll('button').filter((button) => button.text() === '移除')).toHaveLength(1);
  });

  it('shows owner-only dissolve action instead of leave', async () => {
    const wrapper = mount(GroupSettingsView); await flushPromises();
    expect(wrapper.text()).toContain('解散群聊');
    expect(wrapper.text()).not.toContain('退出群聊');
    expect(wrapper.text()).toContain('邀请联系人');
  });

  it('hides invite actions when a regular member opens the route directly', async () => {
    useAuthStore().session = { token: 'token', user: { id: 'mock-mia', username: 'mia', nickname: 'Mia', email: '' } };
    const wrapper = mount(GroupInviteView);
    await flushPromises();
    expect(wrapper.text()).toContain('你没有邀请群成员的权限');
    expect(wrapper.findAll('button').some((button) => button.text() === '添加')).toBe(false);
  });
});
