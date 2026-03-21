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
  status: 'active',
  createdAt: '2026-03-01T00:00:00Z',
  updatedAt: '2026-03-01T00:00:00Z',
};

async function mockAuth(page: Page) {
  await page.route(/\/auth\/admin\/login(?:\?.*)?$/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        token: 'e2e-token',
        refresh_token: 'e2e-refresh-token',
        user: adminUser,
      }),
    });
  });

  await page.route(/\/auth\/admin\/me(?:\?.*)?$/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(adminUser),
    });
  });
}

async function setToken(page: Page) {
  await page.addInitScript(() => {
    window.localStorage.setItem('token', 'e2e-token');
    window.localStorage.setItem('refresh_token', 'e2e-refresh-token');
  });
}

test.describe('admin core flows', () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled) {
      test.skip();
    }
  });

  test('unauthenticated access is redirected to login', async ({ page }) => {
    await page.goto('/user-management/list');
    await expect(page).toHaveURL(/\/login/);
  });

  test('login success then navigates to user list', async ({ page }) => {
    await mockAuth(page);

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

    await page.goto('/login?redirect=UserList');
    await page.getByPlaceholder('用户名：admin').fill(adminUsername);
    await page.getByPlaceholder('密码：admin').fill(adminPassword);
    await page.getByRole('button', { name: '登录' }).click();

    await expect(page).toHaveURL(/\/user-management\/list/);
    await expect(
      page.locator('.arco-card-header-title', { hasText: '用户管理' })
    ).toBeVisible();
    await expect(
      page.locator('.arco-table-td-content').filter({ hasText: /^alice$/ })
    ).toBeVisible();
  });

  test('settings page renders app name and policy panels', async ({ page }) => {
    await setToken(page);
    await mockAuth(page);

    await page.route(/\/settings\/app-name(?:\?.*)?$/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ app_name: 'Chatly' }),
      });
    });

    await page.route(
      /\/api\/admin\/ip-geolocation\/enabled(?:\?.*)?$/,
      async (route) => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ enabled: true, description: 'enabled' }),
        });
      }
    );

    await page.route(
      /\/api\/admin\/settings\/user-account-limit(?:\?.*)?$/,
      async (route) => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            enable_phone_validation: true,
            enable_email_validation: false,
            enable_length_validation: true,
            min_length: 6,
            max_length: 30,
            enable_alphanumeric_validation: true,
          }),
        });
      }
    );

    await page.route(
      /\/api\/admin\/settings\/upload-policy(?:\?.*)?$/,
      async (route) => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            policy: {
              version: '2026-03-01',
              max_total_size_mb: 200,
              max_attachments_per_message: 20,
              max_size_mb_by_part_type: {
                image: 10,
                video: 200,
                audio: 50,
                file: 100,
              },
              mime_by_part_type: {
                image: ['image/png'],
                video: ['video/mp4'],
                audio: ['audio/mp4'],
                file: ['application/pdf'],
              },
              mime_whitelist: [
                'image/png',
                'video/mp4',
                'audio/mp4',
                'application/pdf',
              ],
              audio_only: {
                enabled: true,
                force_single_attachment: true,
                allow_text: false,
              },
            },
            updated_at: '2026-03-01T00:00:00Z',
            updated_by: 'admin',
          }),
        });
      }
    );

    await page.goto('/settings/general');

    await expect(page).toHaveURL(/\/settings\/general/);
    await expect(
      page.locator('.arco-card-header-title', { hasText: '通用设置' })
    ).toBeVisible();
    await expect(page.locator('input[value="Chatly"]')).toBeVisible();
    await expect(page.getByText('上传策略')).toBeVisible();
  });

  test('version page renders desktop version table', async ({ page }) => {
    await setToken(page);
    await mockAuth(page);

    await page.route(/\/api\/admin\/app-versions(?:\?.*)?$/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          total: 1,
          items: [
            {
              id: 'v-1',
              platform: 'windows',
              version: '1.0.0',
              build_number: 1,
              channel: 'stable',
              download_key: 'desktop/windows/1.0.0.exe',
              download_url: null,
              app_store_url: null,
              file_size: 1024,
              checksum: 'sha256-demo',
              signature: null,
              release_notes: '首个稳定版本',
              mandatory: false,
              is_active: true,
              created_at: '2026-03-01T00:00:00Z',
              updated_at: '2026-03-01T00:00:00Z',
              released_at: '2026-03-01T00:00:00Z',
            },
          ],
        }),
      });
    });

    await page.goto('/versions/desktop');

    await expect(page).toHaveURL(/\/versions\/desktop/);
    await expect(page.getByRole('button', { name: '新增版本' })).toBeVisible();
  });
});
