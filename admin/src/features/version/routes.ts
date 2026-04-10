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
        component: () =>
          import('@/features/version/pages/app-versions-page.vue'),
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
        component: () =>
          import('@/features/version/pages/app-versions-page.vue'),
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
        component: () =>
          import('@/features/version/pages/hot-updates-page.vue'),
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
          import('@/features/version/pages/hot-update-events-page.vue'),
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
