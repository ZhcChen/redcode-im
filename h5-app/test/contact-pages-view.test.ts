import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { appEnv } from '@/config/env';
import ContactAddView from '@/views/contacts/ContactAddView.vue';
import ContactProfileView from '@/views/contacts/ContactProfileView.vue';
import ContactReportView from '@/views/contacts/ContactReportView.vue';
import ContactRequestsView from '@/views/contacts/ContactRequestsView.vue';

const route = vi.hoisted(() => ({ params: { userId: 'mock-mia' } }));
const router = vi.hoisted(() => ({ push: vi.fn(), replace: vi.fn(), back: vi.fn() }));
vi.mock('vue-router', () => ({ useRoute: () => route, useRouter: () => router }));

describe('contact workflow views', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    appEnv.useMockData = true;
    router.push.mockReset(); router.replace.mockReset(); router.back.mockReset();
  });

  it('renders incoming and outgoing request tabs', async () => {
    const wrapper = mount(ContactRequestsView);
    await flushPromises();
    expect(wrapper.text()).toContain('收到 1');
    expect(wrapper.text()).toContain('发出 0');
    expect(wrapper.text()).toContain('Neo');
  });

  it('searches users with an application message and locks requested targets', async () => {
    const wrapper = mount(ContactAddView);
    await flushPromises();
    await wrapper.get('input[placeholder="搜索账号 / 昵称"]').setValue('bear');
    await wrapper.get('input[placeholder="介绍一下自己"]').setValue('一起协作');
    await wrapper.get('form').trigger('submit.prevent');
    await flushPromises();
    await wrapper.findAll('button').find((button) => button.text() === '添加')?.trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('已申请');
  });

  it('loads a contact profile and exposes real profile actions', async () => {
    const wrapper = mount(ContactProfileView);
    await flushPromises();
    expect(wrapper.text()).toContain('Mia');
    expect(wrapper.text()).toContain('保存备注');
    expect(wrapper.text()).toContain('发送消息');
    expect(wrapper.text()).toContain('举报该用户');
    expect(wrapper.text()).toContain('删除好友');
  });

  it('requires report content and an image evidence file', () => {
    const wrapper = mount(ContactReportView);
    expect(wrapper.get('input[aria-label="选择举报截图"]').attributes('accept')).toBe('image/*');
    expect(wrapper.findAll('button').find((button) => button.text() === '提交举报')?.attributes('disabled')).toBeDefined();
  });
});
