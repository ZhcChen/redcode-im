import { expect, type Page, type Response } from '@playwright/test';

import { adminPassword, adminUsername } from './test-context';
import { ensureLiveAdminReady } from './live-backend-fixtures';

type AuthMode = 'login' | 'bootstrap';

type LoginRouteOptions = {
  redirectRouteName: string;
  expectedUrl: RegExp;
  displayName?: string;
};

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

async function waitForAuthMode(page: Page): Promise<AuthMode> {
  const loginButton = page.getByRole('button', { name: '登录' });
  const bootstrapButton = page.getByRole('button', {
    name: '初始化并进入后台',
  });

  await expect(loginButton.or(bootstrapButton)).toBeVisible({
    timeout: 15_000,
  });
  return (await bootstrapButton.isVisible()) ? 'bootstrap' : 'login';
}

export async function loginLiveAdmin(
  page: Page,
  {
    redirectRouteName,
    expectedUrl,
    displayName = '系统管理员',
  }: LoginRouteOptions
) {
  await ensureLiveAdminReady();
  await page.goto(`/login?redirect=${redirectRouteName}`);

  const mode = await waitForAuthMode(page);
  const usernameInput = page.getByPlaceholder('用户名：admin');
  const passwordInput = page.getByPlaceholder(/^密码：/);

  await usernameInput.fill(adminUsername);

  if (mode === 'bootstrap') {
    await page
      .getByPlaceholder('请输入首个超级管理员显示名称')
      .fill(displayName);
  }

  await passwordInput.fill(adminPassword);

  const submitButtonName = mode === 'bootstrap' ? '初始化并进入后台' : '登录';
  const responsePromise = page.waitForResponse((response) =>
    mode === 'bootstrap'
      ? matchesResponse(response, '/api/admin/bootstrap/init', 'POST')
      : matchesResponse(response, '/auth/admin/login', 'POST')
  );

  await page.getByRole('button', { name: submitButtonName }).click();

  await expectOkResponse(
    responsePromise,
    mode === 'bootstrap' ? '首个超级管理员初始化' : '管理员登录'
  );
  await expect(page).toHaveURL(expectedUrl);

  return { mode };
}
