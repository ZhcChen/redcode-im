import { test, expect } from '@playwright/test';

import { adminE2EEnabled } from '../support/test-context';
import { installAdminMockServer } from '../support/mock-server';

test.describe('admin rbac pages', () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled) {
      test.skip();
    }
  });

  test('admin account, role and permission pages are reachable', async ({
    page,
  }) => {
    await installAdminMockServer(page);

    await page.goto('/system/admin-users');
    await expect(page).toHaveURL(/\/system\/admin-users/);
    await expect(
      page.locator('.arco-card-header-title', { hasText: '管理员账号管理' })
    ).toBeVisible();

    await page.goto('/system/roles');
    await expect(page).toHaveURL(/\/system\/roles/);
    await expect(
      page.locator('.arco-card-header-title', { hasText: '角色管理' })
    ).toBeVisible();

    await page.goto('/system/permissions');
    await expect(page).toHaveURL(/\/system\/permissions/);
    await expect(
      page.locator('.arco-card-header-title', { hasText: '权限点管理' })
    ).toBeVisible();
  });
});
