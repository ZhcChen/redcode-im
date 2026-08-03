import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { appEnv } from '@/config/env';
import { useAuthStore } from '@/stores/auth';
import { useChatStore } from '@/stores/chat';
import GroupMembersView from '@/views/groups/GroupMembersView.vue';
import GroupInviteView from '@/views/groups/GroupInviteView.vue';
import GroupAdminsView from '@/views/groups/GroupAdminsView.vue';
import GroupRulesView from '@/views/groups/GroupRulesView.vue';
import GroupMutesView from '@/views/groups/GroupMutesView.vue';
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
    expect(wrapper.text()).toContain('管理员设置');
    expect(wrapper.text()).toContain('群规');
    expect(wrapper.text()).toContain('禁言管理');
  });

  it('hides invite actions when a regular member opens the route directly', async () => {
    useAuthStore().session = { token: 'token', user: { id: 'mock-mia', username: 'mia', nickname: 'Mia', email: '' } };
    const wrapper = mount(GroupInviteView);
    await flushPromises();
    expect(wrapper.text()).toContain('你没有邀请群成员的权限');
    expect(wrapper.findAll('button').some((button) => button.text() === '添加')).toBe(false);
  });

  it('allows the owner to appoint and revoke an admin', async () => {
    const wrapper = mount(GroupAdminsView);
    await flushPromises();

    await wrapper.findAll('button').find((button) => button.text() === '设为管理员')?.trigger('click');
    await wrapper.findAll('button').find((button) => button.text() === '确认')?.trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('管理员已任命');
    expect(wrapper.text()).toContain('1 位管理员');

    await wrapper.findAll('button').find((button) => button.text() === '撤销')?.trigger('click');
    await wrapper.findAll('button').find((button) => button.text() === '确认')?.trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('管理员身份已撤销');
    expect(wrapper.text()).toContain('0 位管理员');
  });

  it('hides admin management actions from regular members', async () => {
    useAuthStore().session = { token: 'token', user: { id: 'mock-mia', username: 'mia', nickname: 'Mia', email: '' } };
    const wrapper = mount(GroupAdminsView);
    await flushPromises();
    expect(wrapper.text()).toContain('你没有管理群管理员的权限');
    expect(wrapper.text()).not.toContain('设为管理员');
  });

  it('allows managers to create, edit, and delete group rules', async () => {
    const wrapper = mount(GroupRulesView);
    await flushPromises();
    await wrapper.get('input[placeholder="请输入群规标题"]').setValue('文明交流');
    await wrapper.get('textarea[placeholder="请输入群规内容"]').setValue('禁止人身攻击');
    await wrapper.get('form').trigger('submit');
    await flushPromises();
    expect(wrapper.text()).toContain('群规已添加');
    expect(wrapper.text()).toContain('文明交流');

    await wrapper.findAll('button').find((button) => button.text() === '编辑')?.trigger('click');
    await wrapper.get('input[placeholder="请输入群规标题"]').setValue('友善交流');
    await wrapper.get('form').trigger('submit');
    await flushPromises();
    expect(wrapper.text()).toContain('群规已更新');
    expect(wrapper.text()).toContain('友善交流');

    await wrapper.findAll('button').find((button) => button.text() === '删除')?.trigger('click');
    await wrapper.findAll('button').find((button) => button.text() === '确认删除')?.trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('群规已删除');
    expect(wrapper.text()).toContain('暂无群规，可以添加第一条规则');
  });

  it('shows group rules without management controls to regular members', async () => {
    useAuthStore().session = { token: 'token', user: { id: 'mock-mia', username: 'mia', nickname: 'Mia', email: '' } };
    const wrapper = mount(GroupRulesView);
    await flushPromises();
    expect(wrapper.text()).toContain('暂无群规');
    expect(wrapper.find('form').exists()).toBe(false);
  });

  it('allows managers to update global mute and mute ordinary members', async () => {
    const wrapper = mount(GroupMutesView);
    await flushPromises();

    await wrapper.get('input[aria-label="开启全体禁言"]').setValue(true);
    await wrapper.get('form').trigger('submit');
    await flushPromises();
    expect(wrapper.text()).toContain('全体禁言已开启');

    await wrapper.findAll('select')[1]?.setValue('mock-mia');
    await wrapper.get('input[placeholder="填写成员禁言原因"]').setValue('连续刷屏');
    await wrapper.findAll('button').find((button) => button.text() === '确认禁言')?.trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('成员已禁言');
    expect(wrapper.text()).toContain('连续刷屏');

    await wrapper.findAll('button').find((button) => button.text() === '解除禁言')?.trigger('click');
    await wrapper.findAll('button').find((button) => button.text() === '确认解除')?.trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('成员已解除禁言');
    expect(wrapper.text()).toContain('暂无被禁言的成员');
  });

  it('hides mute management controls from regular members', async () => {
    useAuthStore().session = { token: 'token', user: { id: 'mock-mia', username: 'mia', nickname: 'Mia', email: '' } };
    const wrapper = mount(GroupMutesView);
    await flushPromises();
    expect(wrapper.text()).toContain('你没有管理群禁言的权限');
    expect(wrapper.find('form').exists()).toBe(false);
  });
});
