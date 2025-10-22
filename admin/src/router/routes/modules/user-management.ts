import { DEFAULT_LAYOUT } from '../base';
import type { AppRouteRecordRaw } from '../types';

const USER_MANAGEMENT: AppRouteRecordRaw = {
  path: '/user-management',
  name: 'UserManagement',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: 'menu.userManagement',
    requiresAuth: true,
    icon: 'icon-user',
    order: 1,
  },
  children: [
    {
      path: 'list',
      name: 'UserList',
      component: () => import('@/views/user-management/list/index.vue'),
      meta: {
        locale: 'menu.userManagement.list',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
  ],
};

export default USER_MANAGEMENT;
