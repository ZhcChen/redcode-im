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
    {
      path: 'feedback',
      name: 'UserFeedback',
      component: () => import('@/views/feedback/list/index.vue'),
      meta: {
        locale: 'menu.userManagement.feedback',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'reports',
      name: 'UserReports',
      component: () => import('@/views/report/list/index.vue'),
      meta: {
        locale: 'menu.userManagement.reports',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'chat-history',
      name: 'UserChatHistoryList',
      component: () => import('@/views/chat-history/list/index.vue'),
      meta: {
        locale: 'menu.userManagement.chatHistory',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'chat-history/room/:roomId',
      name: 'RoomChatHistory',
      component: () => import('@/views/chat-history/room/index.vue'),
      meta: {
        locale: 'menu.chatHistory.room',
        requiresAuth: true,
        roles: ['admin'],
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
        roles: ['admin'],
        hideInMenu: true,
      },
    },
  ],
};

export default USER_MANAGEMENT;
