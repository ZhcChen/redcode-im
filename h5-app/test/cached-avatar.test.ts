import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import CachedAvatar from '@/components/CachedAvatar.vue';

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
});
