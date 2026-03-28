import { createI18n } from 'vue-i18n';
import en from './en-US';
import cn from './zh-CN';

export const DEFAULT_LOCALE = 'zh-CN' as const;
export const FALLBACK_LOCALE = 'en-US' as const;
export type AdminLocale = typeof DEFAULT_LOCALE | typeof FALLBACK_LOCALE;

export const LOCALE_OPTIONS = [
  { label: '中文', value: 'zh-CN' },
  { label: 'English', value: 'en-US' },
];

export function isAdminLocale(value: unknown): value is AdminLocale {
  return value === DEFAULT_LOCALE || value === FALLBACK_LOCALE;
}

export function getStoredLocale(): AdminLocale {
  if (typeof localStorage === 'undefined') {
    return DEFAULT_LOCALE;
  }

  const storedLocale = localStorage.getItem('arco-locale');
  return isAdminLocale(storedLocale) ? storedLocale : DEFAULT_LOCALE;
}

const defaultLocale = getStoredLocale();

const i18n = createI18n({
  locale: defaultLocale,
  fallbackLocale: FALLBACK_LOCALE,
  legacy: false,
  allowComposition: true,
  messages: {
    'en-US': en,
    'zh-CN': cn,
  },
});

export default i18n;
