import { describe, expect, it } from 'vitest';

import { router } from '@/router';

describe('h5 router contract', () => {
  it('exposes authenticated message read and forward deep links', () => {
    const routes = new Map(router.getRoutes().map((route) => [route.name, route]));

    expect(routes.get('message-reads')).toMatchObject({
      path: '/chats/:roomId/messages/:messageId/reads',
      meta: { requiresAuth: true },
    });
    expect(routes.get('message-forward')).toMatchObject({
      path: '/chats/:roomId/messages/:messageId/forward',
      meta: { requiresAuth: true },
    });
  });
});
