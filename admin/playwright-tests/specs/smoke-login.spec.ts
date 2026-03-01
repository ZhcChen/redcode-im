import { test, expect } from '@playwright/test';

const enabled = process.env.ADMIN_E2E_ENABLED === 'true';
const username = process.env.ADMIN_USERNAME || 'admin';
const password = process.env.ADMIN_PASSWORD || 'admin123';

test.describe('admin smoke', () => {
  test('login smoke', async ({ page }) => {
    if (!enabled) {
      test.skip();
    }

    await page.goto('/login');
    await page.getByPlaceholder('用户名：admin').fill(username);
    await page.getByPlaceholder('密码：admin').fill(password);
    await page.getByRole('button', { name: '登录' }).click();

    await expect(page).toHaveURL(/dashboard|workplace/);
  });
});
