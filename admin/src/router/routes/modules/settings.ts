import { DEFAULT_LAYOUT } from '../base';
import type { AppRouteRecordRaw } from '../types';

const SETTINGS: AppRouteRecordRaw = {
  path: '/settings',
  name: 'Settings',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: 'menu.settings',
    requiresAuth: true,
    icon: 'icon-settings',
    order: 2,
  },
  children: [
    {
      path: 'captcha',
      name: 'CaptchaSettings',
      component: () => import('@/views/settings/captcha/index.vue'),
      meta: {
        locale: 'menu.settings.captcha',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'privacy-policy',
      name: 'PrivacyPolicySettings',
      component: () => import('@/views/settings/privacy-policy/index.vue'),
      meta: {
        locale: 'menu.settings.privacyPolicy',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'user-agreement',
      name: 'UserAgreementSettings',
      component: () => import('@/views/settings/user-agreement/index.vue'),
      meta: {
        locale: 'menu.settings.userAgreement',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'storage-provider',
      name: 'StorageProviderSettings',
      component: () => import('@/views/settings/storage-provider/index.vue'),
      meta: {
        locale: 'menu.settings.storageProvider',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'cos-test',
      name: 'CosTestSettings',
      component: () => import('@/views/settings/cos-test/index.vue'),
      meta: {
        locale: 'menu.settings.cosTest',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'general',
      name: 'GeneralSettings',
      component: () => import('@/views/settings/general/index.vue'),
      meta: {
        locale: 'menu.settings.general',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'emoji-pack',
      name: 'EmojiPackSettings',
      component: () => import('@/views/settings/emoji-pack/index.vue'),
      meta: {
        locale: 'menu.settings.emojiPack',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'ipinfo-token',
      name: 'IpInfoTokenSettings',
      component: () => import('@/views/settings/ipinfo-token/index.vue'),
      meta: {
        locale: 'menu.settings.ipinfoToken',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'user-profile',
      name: 'UserProfileSettings',
      component: () => import('@/views/settings/user-profile/index.vue'),
      meta: {
        locale: 'menu.settings.userProfile',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
  ],
};

export default SETTINGS;
