import { DEFAULT_LAYOUT } from '@/app/router/base-routes';
import type { AppRouteRecordRaw } from '@/app/router/route-types';

const dashboardRoutes: AppRouteRecordRaw[] = [
  {
    path: '/dashboard',
    name: 'dashboard',
    component: DEFAULT_LAYOUT,
    meta: {
      locale: 'menu.dashboard',
      requiresAuth: true,
      icon: 'icon-dashboard',
      order: 0,
      perm: 'data:analysis',
    },
    children: [
      {
        path: 'workplace',
        name: 'Workplace',
        component: () => import('@/features/dashboard/workplace/index.vue'),
        meta: {
          locale: 'menu.dashboard.workplace',
          requiresAuth: true,
          perm: 'data:analysis',
        },
      },
      {
        path: 'monitor',
        name: 'Monitor',
        component: () => import('@/features/dashboard/monitor/index.vue'),
        meta: {
          locale: 'menu.dashboard.monitor',
          requiresAuth: true,
          perm: 'data:analysis',
        },
      },
    ],
  },
];

export default dashboardRoutes;
