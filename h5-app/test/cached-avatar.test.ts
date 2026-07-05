import { flushPromises, mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import CachedAvatar from '@/components/CachedAvatar.vue';

const loadUserAvatarMock = vi.hoisted(() => vi.fn());
const revokeMock = vi.hoisted(() => vi.fn());

vi.mock('@/services/avatar-cache', () => ({
  avatarCacheService: {
    loadUserAvatar: loadUserAvatarMock,
    loadRoomAvatar: vi.fn(),
    revoke: revokeMock,
  },
}));

describe('CachedAvatar', () => {
  it('falls back to the label initial when no object key is present', () => {
    const wrapper = mount(CachedAvatar, {
      props: {
        kind: 'user',
        entityId: 'u1',
        objectKey: null,
        label: 'Mia',
      },
    });

    expect(wrapper.text()).toBe('M');
    expect(wrapper.find('img').exists()).toBe(false);
  });

  it('falls back to the label initial when cached image cannot render', async () => {
    loadUserAvatarMock.mockResolvedValue({
      cacheKey: 'user:u1',
      objectKey: 'avatars/u1/avatar.png',
      objectUrl: 'blob:broken-image',
      mimeType: 'image/png',
      size: 16,
      cachedAt: Date.now(),
    });

    const wrapper = mount(CachedAvatar, {
      props: {
        kind: 'user',
        entityId: 'u1',
        objectKey: 'avatars/u1/avatar.png',
        label: 'Mia',
      },
    });

    await flushPromises();
    expect(wrapper.find('img').exists()).toBe(true);
    await wrapper.find('img').trigger('error');

    expect(wrapper.text()).toBe('M');
    expect(wrapper.find('img').exists()).toBe(false);
  });
});
