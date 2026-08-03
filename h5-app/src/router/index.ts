import { createRouter, createWebHistory } from 'vue-router';

import LoginView from '@/views/LoginView.vue';
import HomeView from '@/views/HomeView.vue';
import ChatDetailView from '@/views/ChatDetailView.vue';
import GroupSettingsView from '@/views/GroupSettingsView.vue';
import MessageSearchView from '@/views/MessageSearchView.vue';
import MessageReadersView from '@/views/MessageReadersView.vue';
import MessageForwardView from '@/views/MessageForwardView.vue';
import ContactRequestsView from '@/views/contacts/ContactRequestsView.vue';
import ContactAddView from '@/views/contacts/ContactAddView.vue';
import ContactProfileView from '@/views/contacts/ContactProfileView.vue';
import ContactReportView from '@/views/contacts/ContactReportView.vue';
import GroupDirectoryView from '@/views/groups/GroupDirectoryView.vue';
import GroupCreateView from '@/views/groups/GroupCreateView.vue';
import GroupMembersView from '@/views/groups/GroupMembersView.vue';
import GroupInviteView from '@/views/groups/GroupInviteView.vue';
import GroupAdminsView from '@/views/groups/GroupAdminsView.vue';
import GroupRulesView from '@/views/groups/GroupRulesView.vue';
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
      path: '/contacts/requests',
      name: 'contact-requests',
      component: ContactRequestsView,
      meta: { requiresAuth: true },
    },
    {
      path: '/contacts/add',
      name: 'contact-add',
      component: ContactAddView,
      meta: { requiresAuth: true },
    },
    {
      path: '/contacts/:userId',
      name: 'contact-profile',
      component: ContactProfileView,
      meta: { requiresAuth: true },
    },
    {
      path: '/contacts/:userId/report',
      name: 'contact-report',
      component: ContactReportView,
      meta: { requiresAuth: true },
    },
    {
      path: '/chats/:roomId/messages/:messageId/reads',
      name: 'message-reads',
      component: MessageReadersView,
      meta: { requiresAuth: true },
    },
    {
      path: '/chats/:roomId/messages/:messageId/forward',
      name: 'message-forward',
      component: MessageForwardView,
      meta: { requiresAuth: true },
    },
    {
      path: '/groups/:roomId/settings',
      name: 'group-settings',
      component: GroupSettingsView,
      meta: { requiresAuth: true },
    },
    {
      path: '/groups',
      name: 'group-directory',
      component: GroupDirectoryView,
      meta: { requiresAuth: true },
    },
    {
      path: '/groups/create',
      name: 'group-create',
      component: GroupCreateView,
      meta: { requiresAuth: true },
    },
    {
      path: '/groups/:roomId/members',
      name: 'group-members',
      component: GroupMembersView,
      meta: { requiresAuth: true },
    },
    {
      path: '/groups/:roomId/invite',
      name: 'group-invite',
      component: GroupInviteView,
      meta: { requiresAuth: true },
    },
    {
      path: '/groups/:roomId/admins',
      name: 'group-admins',
      component: GroupAdminsView,
      meta: { requiresAuth: true },
    },
    {
      path: '/groups/:roomId/rules',
      name: 'group-rules',
      component: GroupRulesView,
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
