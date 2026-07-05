import { createRouter, createWebHistory } from 'vue-router';

import LoginView from '@/views/LoginView.vue';
import HomeView from '@/views/HomeView.vue';
import ChatDetailView from '@/views/ChatDetailView.vue';
import GroupSettingsView from '@/views/GroupSettingsView.vue';
import MessageSearchView from '@/views/MessageSearchView.vue';
import ProfileSettingsView from '@/views/settings/ProfileSettingsView.vue';
import AccountSecurityView from '@/views/settings/AccountSecurityView.vue';
import DocumentView from '@/views/settings/DocumentView.vue';
import AboutView from '@/views/settings/AboutView.vue';
import FeedbackView from '@/views/settings/FeedbackView.vue';
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
      path: '/messages/search',
      name: 'message-search',
      component: MessageSearchView,
      meta: { requiresAuth: true },
    },
    {
      path: '/groups/:roomId/settings',
      name: 'group-settings',
      component: GroupSettingsView,
      meta: { requiresAuth: true },
    },
    {
      path: '/settings/profile',
      name: 'profile-settings',
      component: ProfileSettingsView,
      meta: { requiresAuth: true },
    },
    {
      path: '/settings/security',
      name: 'account-security',
      component: AccountSecurityView,
      meta: { requiresAuth: true },
    },
    {
      path: '/settings/privacy',
      name: 'privacy-policy',
      component: DocumentView,
      meta: { requiresAuth: true },
    },
    {
      path: '/settings/agreement',
      name: 'user-agreement',
      component: DocumentView,
      meta: { requiresAuth: true },
    },
    {
      path: '/settings/about',
      name: 'about',
      component: AboutView,
      meta: { requiresAuth: true },
    },
    {
      path: '/settings/feedback',
      name: 'feedback',
      component: FeedbackView,
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
