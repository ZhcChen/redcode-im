import { DEFAULT_LAYOUT } from '../base';
import type { AppRouteRecordRaw } from '../types';

// 直接使用 import.meta.env 读取环境变量
const isDataCleanupEnabled =
  import.meta.env.VITE_ENABLE_DATA_CLEANUP === 'true';

const SETTINGS: AppRouteRecordRaw = {
  path: '/settings',
  name: 'Settings',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: 'menu.settings',
    requiresAuth: true,
    icon: 'icon-settings',
    order: 3,
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
      path: 'push',
      name: 'PushSettings',
      component: () => import('@/views/settings/push/index.vue'),
      meta: {
        locale: 'menu.settings.push',
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
