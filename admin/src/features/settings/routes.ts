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
        component: () => import('@/features/settings/pages/captcha-page.vue'),
        meta: {
          locale: 'menu.settings.captcha',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'privacy-policy',
        name: 'PrivacyPolicySettings',
        component: () =>
          import('@/features/settings/pages/privacy-policy-page.vue'),
        meta: {
          locale: 'menu.settings.privacyPolicy',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'user-agreement',
        name: 'UserAgreementSettings',
        component: () =>
          import('@/features/settings/pages/user-agreement-page.vue'),
        meta: {
          locale: 'menu.settings.userAgreement',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'general',
        name: 'GeneralSettings',
        component: () =>
          import('@/features/settings/pages/general-settings-page.vue'),
        meta: {
          locale: 'menu.settings.general',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'push',
        name: 'PushSettings',
        component: () =>
          import('@/features/settings/pages/push-settings-page.vue'),
        meta: {
          locale: 'menu.settings.push',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'emoji-pack',
        name: 'EmojiPackSettings',
        component: () =>
          import('@/features/settings/pages/emoji-pack-page.vue'),
        meta: {
          locale: 'menu.settings.emojiPack',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'user-profile',
        name: 'UserProfileSettings',
        component: () =>
          import('@/features/settings/pages/user-profile-page.vue'),
        meta: {
          locale: 'menu.settings.userProfile',
          requiresAuth: true,
        },
      },
    ],
  },
];

export default settingsRoutes;
