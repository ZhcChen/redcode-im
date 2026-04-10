import { expect, test } from '@playwright/test';

import {
  adminE2EEnabled,
  adminPassword,
  adminUsername,
} from '../support/test-context';

const bootstrapAdminUser = {
  id: 'bootstrap-admin-1',
  username: 'admin',
  email: 'admin@bootstrap.redcode-im.local',
  nickname: '系统管理员',
  avatarUrl: null,
  status: 'active',
  createdAt: '2026-04-10T00:00:00Z',
  updatedAt: '2026-04-10T00:00:00Z',
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

test.describe('admin bootstrap auth flow', () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled) {
      test.skip();
    }
  });

  test('bootstrap required should initialize first admin instead of normal login', async ({
    page,
  }) => {
    let bootstrapInitCalls = 0;
    let normalLoginCalls = 0;
    let meCalls = 0;

    await page.route(
      /\/api\/admin\/bootstrap\/status(?:\?.*)?$/,
      async (route) => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            bootstrap_required: true,
          }),
        });
      }
    );

    await page.route(
      /\/api\/admin\/bootstrap\/init(?:\?.*)?$/,
      async (route) => {
        bootstrapInitCalls += 1;
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            token: 'bootstrap-token',
            refresh_token: 'bootstrap-refresh-token',
            user: bootstrapAdminUser,
          }),
        });
      }
    );

    await page.route(/\/auth\/admin\/login(?:\?.*)?$/, async (route) => {
      normalLoginCalls += 1;
      await route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({
          message: 'bootstrap mode should not call normal login',
        }),
      });
    });

    await page.route(/\/auth\/admin\/me(?:\?.*)?$/, async (route) => {
      meCalls += 1;
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(bootstrapAdminUser),
      });
    });

    await page.route(/\/api\/admin\/users(?:\?.*)?$/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          users: [],
          total: 0,
          page: 1,
          pageSize: 20,
        }),
      });
    });

    await page.goto('/login?redirect=UserList');

    await expect(
      page.getByPlaceholder('请输入首个超级管理员显示名称')
    ).toBeVisible();

    await page.getByPlaceholder('用户名：admin').fill(adminUsername);
    await page
      .getByPlaceholder('请输入首个超级管理员显示名称')
      .fill('系统管理员');
    await page.getByPlaceholder('密码：至少 8 位').fill(adminPassword);
    await page.getByRole('button', { name: '初始化并进入后台' }).click();

    await expect(page).toHaveURL(/\/user-management\/list/);
    await expect.poll(() => bootstrapInitCalls).toBe(1);
    await expect.poll(() => normalLoginCalls).toBe(0);
    await expect.poll(() => meCalls).toBe(0);
  });
});
