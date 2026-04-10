import type { RouteRecordRaw } from 'vue-router';

const LOGIN_ROUTE: RouteRecordRaw = {
  path: '/login',
  name: 'login',
  component: () => import('@/features/auth/pages/login-page.vue'),
  meta: {
    requiresAuth: false,
  },
};

export default LOGIN_ROUTE;
