import { DEFAULT_LAYOUT } from '@/router/routes/base';
import type { AppRouteRecordRaw } from '@/app/router/route-types';

const userManagementRoutes: AppRouteRecordRaw[] = [
  {
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
          perm: 'user:manage',
        },
      },
      {
        path: 'feedback',
        name: 'UserFeedback',
        component: () => import('@/views/feedback/list/index.vue'),
        meta: {
          locale: 'menu.userManagement.feedback',
          requiresAuth: true,
          perm: 'user:manage',
        },
      },
      {
        path: 'reports',
        name: 'UserReports',
        component: () => import('@/views/report/list/index.vue'),
        meta: {
          locale: 'menu.userManagement.reports',
          requiresAuth: true,
          perm: 'user:manage',
        },
      },
      {
        path: 'chat-history',
        name: 'UserChatHistoryList',
        component: () => import('@/views/chat-history/list/index.vue'),
        meta: {
          locale: 'menu.userManagement.chatHistory',
          requiresAuth: true,
          perm: 'message:manage',
        },
      },
      {
        path: 'chat-history/room/:roomId',
        name: 'RoomChatHistory',
        component: () => import('@/views/chat-history/room/index.vue'),
        meta: {
          locale: 'menu.chatHistory.room',
          requiresAuth: true,
          perm: 'message:manage',
          hideInMenu: true,
        },
      },
      {
        path: 'chat-history/user/:userId',
        name: 'UserChatHistoryDetail',
        component: () => import('@/views/chat-history/user/index.vue'),
        meta: {
          locale: 'menu.chatHistory.user',
          requiresAuth: true,
          perm: 'message:manage',
          hideInMenu: true,
        },
      },
    ],
  },
];

export default userManagementRoutes;
