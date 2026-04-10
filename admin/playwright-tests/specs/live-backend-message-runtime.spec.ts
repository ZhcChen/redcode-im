import { test, expect, type Page, type Response } from '@playwright/test';

import {
  adminE2EEnabled,
  adminLiveBackendEnabled,
} from '../support/test-context';
import { loginLiveAdmin } from '../support/live-admin-auth';

type ServerStorageMode = 'persist' | 'relay_only';
type ContentAuditMode = 'plaintext' | 'e2ee';

type MessageRuntimeSettings = {
  server_storage_mode: ServerStorageMode;
  content_audit_mode: ContentAuditMode;
};

const radioText = {
  persist: 'persist（服务端落库）',
  relay_only: 'relay_only（仅实时转发）',
  plaintext: 'plaintext（明文可审计）',
  e2ee: 'e2ee（端侧加密）',
} as const;

function matchesResponse(
  response: Response,
  pathname: string,
  method: string = 'GET'
) {
  const url = new URL(response.url());
  return url.pathname === pathname && response.request().method() === method;
}

async function expectOkResponse(
  responsePromise: Promise<Response>,
  label: string
) {
  const response = await responsePromise;
  expect(
    response.ok(),
    `${label} 返回非 2xx: ${response.status()}`
  ).toBeTruthy();
  return response;
}

async function loginAsAdmin(page: Page) {
  await loginLiveAdmin(page, {
    redirectRouteName: 'GeneralSettings',
    expectedUrl: /\/settings\/general/,
  });
}

async function openMessageRuntimeTab(page: Page) {
  await page
    .locator('.arco-tabs-nav .arco-tabs-tab')
    .filter({ hasText: '消息运行模式' })
    .click();
  await expect(messageRuntimeForm(page)).toBeVisible();
}

function messageRuntimeForm(page: Page) {
  return page.locator('form').filter({ hasText: '服务器存储模式' }).first();
}

async function loadMessageRuntimeSettings(page: Page) {
  const responsePromise = page.waitForResponse((response) =>
    matchesResponse(response, '/api/admin/settings/message-runtime')
  );

  await page.goto('/settings/general');
  const response = await expectOkResponse(responsePromise, '消息运行模式读取');
  await openMessageRuntimeTab(page);

  return (await response.json()) as MessageRuntimeSettings;
}

async function saveMessageRuntimeSettings(
  page: Page,
  settings: MessageRuntimeSettings
) {
  const form = messageRuntimeForm(page);
  const updateResponsePromise = page.waitForResponse((response) =>
    matchesResponse(response, '/api/admin/settings/message-runtime', 'PUT')
  );

  await form
    .getByText(radioText[settings.server_storage_mode], { exact: true })
    .click();
  await form
    .getByText(radioText[settings.content_audit_mode], { exact: true })
    .click();
  await form.getByRole('button', { name: '保存设置' }).click();

  await expectOkResponse(updateResponsePromise, '消息运行模式保存');
  await expect(page.getByText('消息运行模式保存成功')).toBeVisible();
}

async function expectMessageRuntimeSelected(
  page: Page,
  settings: MessageRuntimeSettings
) {
  const form = messageRuntimeForm(page);
  await expect(
    form.locator(`input[type="radio"][value="${settings.server_storage_mode}"]`)
  ).toBeChecked();
  await expect(
    form.locator(`input[type="radio"][value="${settings.content_audit_mode}"]`)
  ).toBeChecked();
}

function invertSettings(
  settings: MessageRuntimeSettings
): MessageRuntimeSettings {
  return {
    server_storage_mode:
      settings.server_storage_mode === 'persist' ? 'relay_only' : 'persist',
    content_audit_mode:
      settings.content_audit_mode === 'plaintext' ? 'e2ee' : 'plaintext',
  };
}

test.describe('admin live backend message runtime settings', () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled || !adminLiveBackendEnabled) {
      test.skip();
    }
  });

  test('message runtime settings can save, reload and restore', async ({
    page,
  }) => {
    await loginAsAdmin(page);

    const original = await loadMessageRuntimeSettings(page);
    const target = invertSettings(original);

    try {
      await saveMessageRuntimeSettings(page, target);
      await expectMessageRuntimeSelected(page, target);

      const reloadResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/settings/message-runtime')
      );
      await page.reload();
      await expectOkResponse(reloadResponsePromise, '消息运行模式重载');
      await openMessageRuntimeTab(page);
      await expectMessageRuntimeSelected(page, target);
    } finally {
      const restoreResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/settings/message-runtime')
      );
      await page.goto('/settings/general');
      await expectOkResponse(restoreResponsePromise, '消息运行模式恢复前读取');
      await openMessageRuntimeTab(page);
      await saveMessageRuntimeSettings(page, original);
      await expectMessageRuntimeSelected(page, original);
    }
  });
});
