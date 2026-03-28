import i18n from '@/locale';
import {
  FALLBACK_LOCALE,
  getStoredLocale,
  isAdminLocale,
  type AdminLocale,
} from '@/locale';

type TranslateFn = (
  key: string,
  params?: Record<string, unknown>,
  locale?: string
) => string;
type KeyExistsFn = (key: string, locale?: string) => boolean;

export interface ApiMessagePayload {
  message?: unknown;
  msg?: unknown;
  message_key?: unknown;
  message_params?: unknown;
}

export interface ResolveMessageOptions {
  fallbackKey?: string;
  fallbackMessage?: string;
  fallbackParams?: Record<string, unknown>;
  locale?: string;
  translate?: TranslateFn;
  keyExists?: KeyExistsFn;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function pickText(value: unknown): string | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function normalizeParams(value: unknown): Record<string, unknown> | undefined {
  return isRecord(value) ? value : undefined;
}

function defaultTranslate(
  key: string,
  params?: Record<string, unknown>
) {
  return i18n.global.t(key, params ?? {});
}

function defaultKeyExists(key: string, locale?: string) {
  const targetLocale = isAdminLocale(locale) ? locale : undefined;
  return (
    i18n.global.te(key, targetLocale) ||
    i18n.global.te(key, FALLBACK_LOCALE) ||
    false
  );
}

export function resolveMessageKey(
  messageKey: string | undefined,
  messageParams?: Record<string, unknown>,
  options: ResolveMessageOptions = {}
) {
  if (!messageKey) {
    return undefined;
  }

  const locale = options.locale ?? getStoredLocale();
  const keyExists = options.keyExists ?? defaultKeyExists;
  if (!keyExists(messageKey, locale)) {
    return undefined;
  }

  const translate = options.translate ?? defaultTranslate;
  return translate(messageKey, messageParams, locale);
}

export function resolveApiMessage(
  payload?: ApiMessagePayload | null,
  options: ResolveMessageOptions = {}
) {
  const explicitMessage =
    pickText(payload?.message) ?? pickText(payload?.msg);
  if (explicitMessage) {
    return explicitMessage;
  }

  const messageKey = pickText(payload?.message_key);
  const messageParams = normalizeParams(payload?.message_params);
  const localizedMessage = resolveMessageKey(messageKey, messageParams, options);
  if (localizedMessage) {
    return localizedMessage;
  }

  if (messageKey) {
    return messageKey;
  }

  if (options.fallbackKey) {
    const fallbackMessage = resolveMessageKey(
      options.fallbackKey,
      options.fallbackParams,
      options
    );
    if (fallbackMessage) {
      return fallbackMessage;
    }
  }

  return options.fallbackMessage ?? 'Request failed';
}

export function resolveStatusFallbackKey(status?: number) {
  switch (status) {
    case 400:
      return 'common.validation_error';
    case 401:
      return 'auth.unauthorized';
    case 403:
      return 'auth.insufficient_permission';
    case 404:
      return 'common.not_found';
    case 409:
      return 'common.already_exists';
    case 429:
      return 'common.too_many_requests';
    case 500:
      return 'common.internal_error';
    case 503:
      return 'common.service_unavailable';
    default:
      return 'common.request_failed';
  }
}

export function resolveHttpErrorMessage(
  error: {
    response?: { data?: ApiMessagePayload; status?: number };
    message?: unknown;
  },
  options: ResolveMessageOptions = {}
) {
  const fallbackKey = options.fallbackKey ?? resolveStatusFallbackKey(error.response?.status);
  return resolveApiMessage(error.response?.data, {
    ...options,
    fallbackKey,
    fallbackMessage:
      options.fallbackMessage ??
      resolveMessageKey('common.request_failed', undefined, options) ??
      'Request failed',
  });
}

export function resolveLocaleChangedMessage(
  locale: AdminLocale,
  options: ResolveMessageOptions = {}
) {
  const localeLabel =
    resolveMessageKey(`common.locale.${locale}`, undefined, options) ?? locale;
  const translate = options.translate ?? defaultTranslate;
  return translate(
    'common.locale.changed',
    { locale: localeLabel },
    options.locale ?? getStoredLocale()
  );
}
