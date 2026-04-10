import { DEFAULT_LAYOUT } from '@/router/routes/base';
import type { AppRouteRecordRaw } from '@/app/router/route-types';

const versionRoutes: AppRouteRecordRaw[] = [
  {
    path: '/versions',
    name: 'VersionManagement',
    component: DEFAULT_LAYOUT,
    meta: {
      locale: 'menu.version',
      requiresAuth: true,
      icon: 'icon-cloud',
      order: 5,
    },
    children: [
      {
        path: 'frontend',
        name: 'VersionFrontend',
        component: () => import('@/views/version-management/index.vue'),
        props: { platform: 'frontend' },
        meta: {
          locale: 'menu.version.frontend',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'desktop',
        name: 'VersionDesktop',
        component: () => import('@/views/version-management/index.vue'),
        props: { platform: 'desktop' },
        meta: {
          locale: 'menu.version.desktop',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'hot-updates',
        name: 'VersionHotUpdates',
        component: () => import('@/views/version-management/hot-update.vue'),
        meta: {
          locale: 'menu.version.hotUpdate',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'hot-update-events',
        name: 'VersionHotUpdateEvents',
        component: () =>
          import('@/views/version-management/hot-update-events.vue'),
        meta: {
          locale: 'menu.version.hotUpdateEvents',
          requiresAuth: true,
          perm: 'log:audit',
        },
      },
    ],
  },
];

export default versionRoutes;
