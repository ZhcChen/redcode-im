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
  ],
};

export default SETTINGS;
