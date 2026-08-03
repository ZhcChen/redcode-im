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

  it('exposes the contact workflow as refresh-safe routes', () => {
    const routes = new Map(router.getRoutes().map((route) => [route.name, route]));
    expect(routes.get('contact-requests')?.path).toBe('/contacts/requests');
    expect(routes.get('contact-add')?.path).toBe('/contacts/add');
    expect(routes.get('contact-profile')?.path).toBe('/contacts/:userId');
    expect(routes.get('contact-report')?.path).toBe('/contacts/:userId/report');
  });

  it('exposes independent group directory and creation routes', () => {
    const routes = new Map(router.getRoutes().map((route) => [route.name, route]));
    expect(routes.get('group-directory')?.path).toBe('/groups');
    expect(routes.get('group-create')?.path).toBe('/groups/create');
    expect(routes.get('group-members')?.path).toBe('/groups/:roomId/members');
    expect(routes.get('group-invite')?.path).toBe('/groups/:roomId/invite');
    expect(routes.get('group-admins')?.path).toBe('/groups/:roomId/admins');
    expect(routes.get('group-rules')?.path).toBe('/groups/:roomId/rules');
    expect(routes.get('group-mutes')?.path).toBe('/groups/:roomId/mutes');
    expect(routes.get('group-join-requests')?.path).toBe('/groups/:roomId/join-requests');
    expect(routes.get('group-invitations')?.path).toBe('/group-invitations');
    expect(routes.get('group-operation-logs')?.path).toBe('/groups/:roomId/operation-logs');
  });

  it('exposes mine and settings as refresh-safe routes', () => {
    const routes = new Map(router.getRoutes().map((route) => [route.name, route]));
    expect(routes.get('mine-profile')?.path).toBe('/mine/profile');
    expect(routes.get('settings')?.path).toBe('/settings');
    expect(routes.get('chat-settings')?.path).toBe('/settings/chat');
    expect(routes.get('settings-deactivate')?.path).toBe('/settings/deactivate');
    expect(routes.get('settings-version')?.path).toBe('/settings/version');
    expect(routes.get('stickers')?.path).toBe('/stickers');
    expect(routes.get('sticker-store')?.path).toBe('/stickers/store');
    expect(routes.get('sticker-pack')?.path).toBe('/stickers/:packId');
  });
});
