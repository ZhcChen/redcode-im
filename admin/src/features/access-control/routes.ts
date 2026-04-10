import { DEFAULT_LAYOUT } from '@/router/routes/base';
import type { AppRouteRecordRaw } from '@/app/router/route-types';

const accessControlRoutes: AppRouteRecordRaw[] = [
  {
    path: '/system',
    name: 'AccessControl',
    component: DEFAULT_LAYOUT,
    meta: {
      locale: 'menu.accessControl',
      requiresAuth: true,
      icon: 'icon-safe',
      order: 2,
      perm: 'role:manage',
    },
    children: [
      {
        path: 'admin-users',
        name: 'AdminUsers',
        component: () => import('@/views/system/admin-users/index.vue'),
        meta: {
          locale: 'menu.accessControl.adminUsers',
          requiresAuth: true,
          perm: 'role:manage',
        },
      },
      {
        path: 'roles',
        name: 'RoleManagement',
        component: () => import('@/views/system/roles/index.vue'),
        meta: {
          locale: 'menu.accessControl.roles',
          requiresAuth: true,
          perm: 'role:manage',
        },
      },
      {
        path: 'permissions',
        name: 'PermissionManagement',
        component: () => import('@/views/system/permissions/index.vue'),
        meta: {
          locale: 'menu.accessControl.permissions',
          requiresAuth: true,
          perm: 'role:manage',
        },
      },
    ],
  },
];

export default accessControlRoutes;
