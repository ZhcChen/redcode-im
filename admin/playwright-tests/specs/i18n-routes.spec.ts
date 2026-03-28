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
  {
    id: 'login-brand',
    path: '/login',
    assertion: async (page: Page) => {
      await expect(
        page.locator('.logo-text').getByText('IM Admin Console', {
          exact: true,
        })
      ).toBeVisible();
    },
  },
  {
    id: 'user-management-list',
    path: '/user-management/list',
    assertion: async (page: Page) => {
      await expect(page.getByPlaceholder('Search username')).toBeVisible();
    },
  },
  {
    id: 'user-management-feedback',
    path: '/user-management/feedback',
    assertion: async (page: Page) => {
      await expect(
        page.getByText('User Feedback', { exact: true }).first()
      ).toBeVisible();
    },
  },
  {
    id: 'user-management-reports',
    path: '/user-management/reports',
    assertion: async (page: Page) => {
      await expect(
        page.getByText('Reporter ID', { exact: true }).first()
      ).toBeVisible();
    },
  },
  {
    id: 'user-management-chat-history',
    path: '/user-management/chat-history',
    assertion: async (page: Page) => {
      await expect(page.getByText('Room ID', { exact: true })).toBeVisible();
    },
  },
  {
    id: 'user-management-room-history',
    path: '/user-management/chat-history/room/room-e2e',
    assertion: async (page: Page) => {
      await expect(page.getByText('Room Chat History:', { exact: false }))
        .toBeVisible();
    },
  },
  {
    id: 'user-management-user-history',
    path: '/user-management/chat-history/user/user-e2e',
    assertion: async (page: Page) => {
      await expect(page.getByText('User Rooms', { exact: true }).first())
        .toBeVisible();
    },
  },
];

const ENGLISH_ERROR_CASES = [
  {
    id: 'user-management-feedback-fetch-error',
    path: '/user-management/feedback',
    routePattern: '**/api/admin/feedbacks**',
    expectedMessage: 'Failed to load feedback',
  },
  {
    id: 'user-management-reports-fetch-error',
    path: '/user-management/reports',
    routePattern: '**/api/admin/reports**',
    expectedMessage: 'Failed to load reports',
  },
  {
    id: 'user-management-list-fetch-error',
    path: '/user-management/list',
    routePattern: '**/api/admin/users**',
    expectedMessage: 'Failed to load users',
  },
];

async function prepareEnglishPage(page: Page) {
  await installAdminMockServer(page);
  await page.addInitScript(() => {
    window.localStorage.setItem('arco-locale', 'en-US');
  });
}

test.describe('admin route i18n surfaces', () => {
  test.beforeEach(async ({ page }) => {
    if (!adminE2EEnabled) {
      test.skip();
    }
  });

  for (const routeCase of ENGLISH_ROUTE_CASES) {
    test(`${routeCase.id}: renders English surface`, async ({ page }) => {
      await prepareEnglishPage(page);
      await page.goto(routeCase.path);
      await routeCase.assertion(page);
    });
  }

  for (const errorCase of ENGLISH_ERROR_CASES) {
    test(`${errorCase.id}: renders English fallback error`, async ({
      page,
    }) => {
      await prepareEnglishPage(page);
      await page.route(errorCase.routePattern, async (route) => {
        await route.fulfill({
          status: 500,
          contentType: 'application/json; charset=utf-8',
          body: '{}',
        });
      });

      await page.goto(errorCase.path);

      await expect(
        page
          .locator('.arco-message-content')
          .filter({ hasText: errorCase.expectedMessage })
          .first()
      ).toBeVisible();
    });
  }
});
