import { createRouter, createWebHistory } from 'vue-router';

import LoginView from '@/views/LoginView.vue';
import HomeView from '@/views/HomeView.vue';
import ChatDetailView from '@/views/ChatDetailView.vue';
import GroupSettingsView from '@/views/GroupSettingsView.vue';
import { useAuthStore } from '@/stores/auth';

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      redirect: '/home',
    },
    {
      path: '/login',
      name: 'login',
      component: LoginView,
      meta: { guestOnly: true },
    },
    {
      path: '/home',
      name: 'home',
      component: HomeView,
      meta: { requiresAuth: true },
    },
    {
      path: '/chats/:roomId',
      name: 'chat-detail',
      component: ChatDetailView,
      meta: { requiresAuth: true },
    },
    {
      path: '/groups/:roomId/settings',
      name: 'group-settings',
      component: GroupSettingsView,
      meta: { requiresAuth: true },
    },
  ],
});

router.beforeEach((to) => {
  const authStore = useAuthStore();
  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    return { name: 'login' };
  }
  if (to.meta.guestOnly && authStore.isAuthenticated) {
    return { name: 'home' };
  }
  return true;
});
