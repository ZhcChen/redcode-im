import { test, expect, type Page } from '@playwright/test';
import {
  adminE2EEnabled,
  adminPassword,
  adminUsername,
} from '../support/test-context';

const adminUser = {
  id: 'admin-1',
  username: 'admin',
  email: 'admin@example.com',
  nickname: '系统管理员',
  avatarUrl: null,
  status: 'active',
  createdAt: '2026-03-01T00:00:00Z',
  updatedAt: '2026-03-01T00:00:00Z',
  roleCodes: ['super_admin'],
  permissionKeys: [
    'user:manage',
    'role:manage',
    'message:manage',
    'file:manage',
    'system:settings',
    'data:analysis',
    'log:audit',
  ],
  isSuperAdmin: true,
};

async function setSession(
  page: Page,
  token = 'expired-token',
  refreshToken = 'expired-refresh-token'
) {
  await page.addInitScript(
    ({ tokenValue, refreshValue }) => {
      window.localStorage.setItem('token', tokenValue);
      window.localStorage.setItem('refresh_token', refreshValue);
    },
    { tokenValue: token, refreshValue: refreshToken }
  );
}

async function mockUserList(page: Page) {
  await page.route(/\/api\/admin\/users(?:\?.*)?$/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        users: [
          {
            id: 'u-1',
            username: 'alice',
            nickname: 'Alice',
            email: 'alice@example.com',
            status: 'active',
            avatar_url: null,
            created_at: '2026-03-01T00:00:00Z',
            updated_at: '2026-03-01T00:00:00Z',
            deleted_at: null,
          },
        ],
        total: 1,
        page: 1,
        pageSize: 20,
      }),
    });
  });
}

test.describe('admin auth resilience', () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled) {
      test.skip();
    }
  });

  test('login failure keeps user on login and does not persist token', async ({
    page,
  }) => {
    await page.route(/\/auth\/admin\/login(?:\?.*)?$/, async (route) => {
      await route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({ message: '用户名或密码错误' }),
      });
    });

    await page.goto('/login');
    await page.getByPlaceholder('用户名：admin').fill(adminUsername);
    await page.getByPlaceholder('密码：admin').fill(adminPassword);
    await page.getByRole('button', { name: '登录' }).click();

    await expect(page).toHaveURL(/\/login/);
    await expect
      .poll(async () => {
        const text = await page.locator('.login-form-error-msg').innerText();
        return text.trim().length;
      })
      .toBeGreaterThan(0);
    await expect
      .poll(() => page.evaluate(() => window.localStorage.getItem('token')))
      .toBeNull();
  });

  test('expired token is refreshed and route remains accessible', async ({
    page,
  }) => {
    await setSession(page);

    let meCount = 0;
    await page.route(/\/auth\/admin\/me(?:\?.*)?$/, async (route) => {
      meCount += 1;
      if (meCount === 1) {
        await route.fulfill({
          status: 401,
          contentType: 'application/json',
          body: JSON.stringify({ message: 'token expired' }),
        });
        return;
      }

      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(adminUser),
      });
    });

    await page.route(/\/auth\/admin\/refresh(?:\?.*)?$/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          token: 'fresh-token',
          refresh_token: 'fresh-refresh-token',
        }),
      });
    });

    await mockUserList(page);

    await page.goto('/user-management/list');

    await expect(page).toHaveURL(/\/user-management\/list/);
    await expect(
      page.locator('.arco-card-header-title', { hasText: '用户管理' })
    ).toBeVisible();
    await expect
      .poll(() => page.evaluate(() => window.localStorage.getItem('token')))
      .toBe('fresh-token');
    await expect
      .poll(() =>
        page.evaluate(() => window.localStorage.getItem('refresh_token'))
      )
      .toBe('fresh-refresh-token');
  });

  test('expired token with refresh failure redirects to login and clears session', async ({
    page,
  }) => {
    await setSession(page, 'expired-token', '');

    await page.route(/\/auth\/admin\/me(?:\?.*)?$/, async (route) => {
      await route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({ message: 'token expired' }),
      });
    });

    await page.goto('/settings/general');

    await expect(page).toHaveURL(/\/login/);
    await expect
      .poll(() => page.evaluate(() => window.localStorage.getItem('token')))
      .toBeNull();
    await expect
      .poll(() =>
        page.evaluate(() => window.localStorage.getItem('refresh_token'))
      )
      .toBeNull();
  });
});
