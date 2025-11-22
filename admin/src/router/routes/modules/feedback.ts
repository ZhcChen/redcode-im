import { DEFAULT_LAYOUT } from '../base';
import type { AppRouteRecordRaw } from '../types';

const FEEDBACK: AppRouteRecordRaw = {
  path: '/feedback',
  name: 'Feedback',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: 'menu.feedback',
    requiresAuth: true,
    icon: 'icon-edit',
    order: 2,
  },
  children: [
    {
      path: 'list',
      name: 'FeedbackList',
      component: () => import('@/views/feedback/list/index.vue'),
      meta: {
        locale: 'menu.feedback.list',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
  ],
};

export default FEEDBACK;
