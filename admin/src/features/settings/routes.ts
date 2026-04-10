import { DEFAULT_LAYOUT } from '@/router/routes/base';
import type { AppRouteRecordRaw } from '@/app/router/route-types';

const settingsRoutes: AppRouteRecordRaw[] = [
  {
    path: '/settings',
    name: 'Settings',
    component: DEFAULT_LAYOUT,
    meta: {
      locale: 'menu.settings',
      requiresAuth: true,
      icon: 'icon-settings',
      order: 4,
    },
    children: [
      {
        path: 'captcha',
        name: 'CaptchaSettings',
        component: () => import('@/views/settings/captcha/index.vue'),
        meta: {
          locale: 'menu.settings.captcha',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'privacy-policy',
        name: 'PrivacyPolicySettings',
        component: () => import('@/views/settings/privacy-policy/index.vue'),
        meta: {
          locale: 'menu.settings.privacyPolicy',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'user-agreement',
        name: 'UserAgreementSettings',
        component: () => import('@/views/settings/user-agreement/index.vue'),
        meta: {
          locale: 'menu.settings.userAgreement',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'general',
        name: 'GeneralSettings',
        component: () => import('@/views/settings/general/index.vue'),
        meta: {
          locale: 'menu.settings.general',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'push',
        name: 'PushSettings',
        component: () => import('@/views/settings/push/index.vue'),
        meta: {
          locale: 'menu.settings.push',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'emoji-pack',
        name: 'EmojiPackSettings',
        component: () => import('@/views/settings/emoji-pack/index.vue'),
        meta: {
          locale: 'menu.settings.emojiPack',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'user-profile',
        name: 'UserProfileSettings',
        component: () => import('@/views/settings/user-profile/index.vue'),
        meta: {
          locale: 'menu.settings.userProfile',
          requiresAuth: true,
        },
      },
    ],
  },
];

export default settingsRoutes;
