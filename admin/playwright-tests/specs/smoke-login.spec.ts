import { test, expect } from '@playwright/test';
import {
  adminE2EEnabled,
  adminPassword,
  adminUsername,
} from '../support/test-context';

test.describe('admin smoke', () => {
  test('login smoke', async ({ page }) => {
    if (!adminE2EEnabled) {
      test.skip();
    }

    await page.goto('/login');
    await page.getByPlaceholder('用户名：admin').fill(adminUsername);
    await page.getByPlaceholder('密码：admin').fill(adminPassword);
    await page.getByRole('button', { name: '登录' }).click();

    await expect(page).toHaveURL(/dashboard|workplace/);
  });
});
