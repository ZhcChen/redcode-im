import { test, expect, type Page } from '@playwright/test';
import { installAdminMockServer } from '../support/mock-server';
import { adminE2EEnabled } from '../support/test-context';

const ENGLISH_ROUTE_CASES = [
  {
    id: 'operations-storage-provider',
    path: '/operations/storage-provider',
    assertion: async (page: Page) => {
      await expect(
        page.getByText('File Upload Provider Settings', { exact: true })
      ).toBeVisible();
    },
  },
  {
    id: 'operations-cos-test',
    path: '/operations/cos-test',
    assertion: async (page: Page) => {
      await expect(
        page.getByText('Tencent COS Test', { exact: true })
      ).toBeVisible();
    },
  },
  {
    id: 'operations-file-upload-audit',
    path: '/operations/file-upload-audit',
    assertion: async (page: Page) => {
      await expect(
        page.getByRole('button', { name: 'Search', exact: true })
      ).toBeVisible();
    },
  },
  {
    id: 'operations-system-log',
    path: '/operations/system-log',
    assertion: async (page: Page) => {
      await expect(
        page.getByRole('button', { name: 'Clear Logs', exact: true })
      ).toBeVisible();
    },
  },
  {
    id: 'operations-push-log',
    path: '/operations/push-log',
    assertion: async (page: Page) => {
      await expect(
        page.getByRole('button', { name: 'Clear Logs', exact: true })
      ).toBeVisible();
    },
  },
  {
    id: 'operations-api-metrics',
    path: '/operations/api-metrics',
    assertion: async (page: Page) => {
      await expect(
        page.getByText('Auto Refresh (5s)', { exact: true })
      ).toBeVisible();
    },
  },
  {
    id: 'operations-data-cleanup',
    path: '/operations/data-cleanup',
    assertion: async (page: Page) => {
      await expect(
        page.getByText('Dangerous Operation - Development Environment Only', {
          exact: true,
        })
      ).toBeVisible();
    },
  },
  {
    id: 'shell-brand',
    path: '/operations/system-log',
    assertion: async (page: Page) => {
      await expect(
        page.getByText('IM Admin Console', { exact: true }).first()
      ).toBeVisible();
    },
  },
];

test.describe('admin route i18n surfaces', () => {
  test.beforeEach(async ({ page }) => {
    if (!adminE2EEnabled) {
      test.skip();
    }

    await installAdminMockServer(page);
    await page.addInitScript(() => {
      window.localStorage.setItem('arco-locale', 'en-US');
    });
  });

  for (const routeCase of ENGLISH_ROUTE_CASES) {
    test(`${routeCase.id}: renders English surface`, async ({ page }) => {
      await page.goto(routeCase.path);
      await routeCase.assertion(page);
    });
  }
});
