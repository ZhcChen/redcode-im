import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import StickersView from '@/views/stickers/StickersView.vue';
import StickerStoreView from '@/views/stickers/StickerStoreView.vue';
import StickerPackView from '@/views/stickers/StickerPackView.vue';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { packId: 'suite-1' } }),
  useRouter: () => ({ push: vi.fn(), back: vi.fn() }),
}));

describe('sticker views', () => {
  beforeEach(() => setActivePinia(createPinia()));

  it('renders and removes a sticker from the personal collection', async () => {
    const wrapper = mount(StickersView);
    await flushPromises();
    expect(wrapper.text()).toContain('工作日常');
    await wrapper.findAll('button').find((button) => button.text() === '移除')?.trigger('click');
    await wrapper.findAll('button').find((button) => button.text() === '确认')?.trigger('click');
    expect(wrapper.text()).toContain('暂无贴纸');
  });

  it('searches and adds a sticker suite from the store', async () => {
    const wrapper = mount(StickerStoreView);
    await flushPromises();
    await wrapper.findAll('button').find((button) => button.text() === '添加')?.trigger('click');
    expect(wrapper.text()).toContain('已添加 3 个贴纸');
  });

  it('renders a refresh-safe sticker pack detail', async () => {
    const wrapper = mount(StickerPackView);
    await flushPromises();
    expect(wrapper.text()).toContain('工作日常');
    expect(wrapper.text()).toContain('添加贴纸包后可查看全部内容');
  });
});
