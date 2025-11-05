import { DEFAULT_LAYOUT } from '../base';
import type { AppRouteRecordRaw } from '../types';

const VERSION_MANAGEMENT: AppRouteRecordRaw = {
  path: '/versions',
  name: 'VersionManagement',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: 'menu.version',
    requiresAuth: true,
    icon: 'icon-cloud',
    order: 3,
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
        roles: ['admin'],
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
        roles: ['admin'],
      },
    },
  ],
};

export default VERSION_MANAGEMENT;
