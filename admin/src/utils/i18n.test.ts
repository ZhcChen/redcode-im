import { describe, expect, test } from 'bun:test';
import {
  resolveApiMessage,
  resolveHttpErrorMessage,
  resolveLocaleChangedMessage,
} from './i18n';

const messages: Record<string, string> = {
  'common.request_failed': 'Request failed',
  'common.not_found': 'Resource not found',
  'common.locale.changed': 'Language switched to {locale}',
  'common.locale.en-US': 'English',
  'version.platform_unsupported': 'Platform {platform} is not supported',
};

function translate(key: string, params?: Record<string, unknown>) {
  const template = messages[key] ?? key;
  return template.replace(/\{(\w+)\}/g, (_, token: string) => {
    const value = params?.[token];
    return value === undefined || value === null ? '' : String(value);
  });
}

function keyExists(key: string) {
  return Object.prototype.hasOwnProperty.call(messages, key);
}

describe('resolveApiMessage', () => {
  test('prefers explicit message over message_key', () => {
    expect(
      resolveApiMessage(
        {
          message: 'server localized message',
          message_key: 'version.platform_unsupported',
          message_params: { platform: 'desktop' },
        },
        { translate, keyExists, fallbackKey: 'common.request_failed' }
      )
    ).toBe('server localized message');
  });

  test('localizes message_key with message_params when message missing', () => {
    expect(
      resolveApiMessage(
        {
          message_key: 'version.platform_unsupported',
          message_params: { platform: 'desktop' },
        },
        { translate, keyExists, fallbackKey: 'common.request_failed' }
      )
    ).toBe('Platform desktop is not supported');
  });

  test('falls back to raw message_key when locale entry is missing', () => {
    expect(
      resolveApiMessage(
        {
          message_key: 'unknown.message.key',
        },
        { translate, keyExists, fallbackKey: 'common.request_failed' }
      )
    ).toBe('unknown.message.key');
  });

  test('falls back to localized default message when payload is empty', () => {
    expect(
      resolveApiMessage({}, { translate, keyExists, fallbackKey: 'common.request_failed' })
    ).toBe('Request failed');
  });
});

describe('resolveHttpErrorMessage', () => {
  test('uses localized status fallback instead of raw Error text', () => {
    expect(
      resolveHttpErrorMessage(
        {
          response: {
            status: 404,
            data: {},
          },
          message: 'Error',
        },
        { translate, keyExists }
      )
    ).toBe('Resource not found');
  });
});

describe('resolveLocaleChangedMessage', () => {
  test('builds locale switch success copy from locale key', () => {
    expect(
      resolveLocaleChangedMessage('en-US', {
        translate,
        keyExists,
      })
    ).toBe('Language switched to English');
  });
});
