import { test, expect, type Page } from '@playwright/test';
import {
  adminE2EEnabled,
  adminLiveBackendEnabled,
} from '../support/test-context';
import { loginLiveAdmin } from '../support/live-admin-auth';

const trackedWarningPatterns = [
  /menu\.settings\.dataCleanup/,
  /Missing required prop: "model"/,
];

class ConsoleErrorTracker {
  private readonly entries: string[] = [];

  constructor(page: Page) {
    page.on('console', (message) => {
      if (message.type() === 'error') {
        this.entries.push(`[console] ${message.text()}`);
        return;
      }

      if (
        message.type() === 'warning' &&
        trackedWarningPatterns.some((pattern) => pattern.test(message.text()))
      ) {
        this.entries.push(`[warning] ${message.text()}`);
      }
    });

    page.on('pageerror', (error) => {
      this.entries.push(`[pageerror] ${error.message}`);
    });
  }

  checkpoint() {
    return this.entries.length;
  }

  expectCleanSince(checkpoint: number, label: string) {
    expect(
      this.entries.slice(checkpoint),
      `${label} 出现 console/page error`
    ).toEqual([]);
  }
}

async function loginAsAdmin(page: Page, tracker: ConsoleErrorTracker) {
  const checkpoint = tracker.checkpoint();
  await loginLiveAdmin(page, {
    redirectRouteName: 'DataCleanup',
    expectedUrl: /\/operations\/data-cleanup/,
  });
  tracker.expectCleanSince(checkpoint, '登录流程');
}

test.describe('admin live backend data cleanup', () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled || !adminLiveBackendEnabled) {
      test.skip();
    }
  });

  test('data-cleanup route loads and destructive guard works', async ({
    page,
  }) => {
    const tracker = new ConsoleErrorTracker(page);

    await loginAsAdmin(page, tracker);

    const checkpoint = tracker.checkpoint();

    await expect(
      page.locator('.arco-card-header-title', { hasText: '数据清理' })
    ).toBeVisible();
    await expect(
      page.locator('.arco-breadcrumb-item').filter({ hasText: '运维管理' })
    ).toBeVisible();
    await expect(
      page.locator('.arco-breadcrumb-item').filter({ hasText: '数据清理' })
    ).toBeVisible();

    const cleanupButton = page.getByRole('button', {
      name: '立即清理所有数据',
    });
    await expect(cleanupButton).toBeDisabled();

    await page.getByText('我已理解此操作的危险性，并确认要执行清理').click();
    await page.getByPlaceholder("请输入 '确认清理' 以继续").fill('确认清理');
    await expect(cleanupButton).toBeEnabled();

    await cleanupButton.click();
    await expect(page.getByText('确认清理操作')).toBeVisible();
    await page.getByRole('button', { name: '取消' }).click();

    tracker.expectCleanSince(checkpoint, 'data-cleanup 页面');
  });
});
