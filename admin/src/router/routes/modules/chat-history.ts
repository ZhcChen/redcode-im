import { DEFAULT_LAYOUT } from '../base';
import type { AppRouteRecordRaw } from '../types';

const CHAT_HISTORY: AppRouteRecordRaw = {
  path: '/chat-history',
  name: 'ChatHistory',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: 'menu.chatHistory',
    requiresAuth: true,
    icon: 'icon-message',
    order: 2,
  },
  children: [
    {
      path: 'list',
      name: 'ChatHistoryList',
      component: () => import('@/views/chat-history/list/index.vue'),
      meta: {
        locale: 'menu.chatHistory.list',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'room/:roomId',
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
      path: 'user/:userId',
      name: 'UserChatHistory',
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

export default CHAT_HISTORY;
