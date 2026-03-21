import { test, expect, type Page } from '@playwright/test';
import {
  getAllRouteCases,
  getRouteCases,
  type AdminRouteCase,
} from '../support/route-cases';
import {
  adminE2EEnabled,
  getAdminRouteProfile,
  type AdminRouteProfile,
} from '../support/test-context';
import {
  installAdminMockServer,
  triggerBasicRefresh,
  waitForRecoverableSurface,
} from '../support/mock-server';

const profile = getAdminRouteProfile();
const routeCases = getRouteCases(profile);

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function createRouteMatcher(path: string) {
  return new RegExp(`${escapeRegExp(path)}(?:\\?.*)?$`);
}

async function assertRouteSurface(page: Page, routeCase: AdminRouteCase) {
  await expect(page).toHaveURL(createRouteMatcher(routeCase.path));

  await expect
    .poll(async () => {
      const anchors = page.getByText(routeCase.anchorText);
      const count = await anchors.count();
      for (let i = 0; i < count; i += 1) {
        if (await anchors.nth(i).isVisible()) {
          return true;
        }
      }
      return false;
    })
    .toBe(true);

  await expect(page.locator('#app')).toBeVisible();
}

async function performInteraction(page: Page, routeCase: AdminRouteCase) {
  switch (routeCase.interaction) {
    case 'search': {
      const searchInput = page.locator('input[placeholder*="搜索"]').first();
      if ((await searchInput.count()) > 0) {
        await searchInput.fill('e2e');
        await searchInput.press('Enter');
        return;
      }

      await triggerBasicRefresh(page);
      return;
    }

    case 'refresh': {
      await triggerBasicRefresh(page);
      return;
    }

    case 'save': {
      if (routeCase.id === 'settings-user-profile') {
        const nickname = page.getByPlaceholder('请输入昵称').first();
        if ((await nickname.count()) > 0) {
          await nickname.fill('E2E 管理员');
        }
      }

      const saveButtonLabels = ['保存', '保存修改', '保存全局设置'];
      for (const label of saveButtonLabels) {
        const saveButton = page.getByRole('button', { name: label }).first();
        if ((await saveButton.count()) > 0) {
          await saveButton.click();
          return;
        }
      }

      await triggerBasicRefresh(page);
      return;
    }

    case 'bucket-list': {
      const button = page
        .getByRole('button', { name: '加载 Bucket 列表' })
        .first();
      if ((await button.count()) > 0) {
        await button.click();
        return;
      }

      await triggerBasicRefresh(page);
      return;
    }

    case 'reset': {
      const button = page.getByRole('button', { name: '重置' }).first();
      if ((await button.count()) > 0) {
        await button.click();
        return;
      }

      await triggerBasicRefresh(page);
      return;
    }

    case 'switch-tab': {
      const tab = page.getByRole('tab', { name: '用户消息' }).first();
      if ((await tab.count()) > 0) {
        await tab.click();
        return;
      }

      const tabText = page.getByText('用户消息').first();
      if ((await tabText.count()) > 0) {
        await tabText.click({ force: true });
        return;
      }

      await page.reload();
      return;
    }

    case 'noop':
    default:
      await page.waitForTimeout(200);
  }
}

function routeWithMarker(path: string, marker: string) {
  const suffix = path.includes('?') ? '&' : '?';
  return `${path}${suffix}e2e_marker=${marker}`;
}

test.describe('admin route smoke catalog', () => {
  test('route catalog covers default and data-cleanup profiles', async () => {
    const allCases = getAllRouteCases();
    const defaultCases = getRouteCases('default');
    const dataCleanupCases = getRouteCases('data-cleanup');

    expect(allCases.length).toBeGreaterThanOrEqual(27);
    expect(defaultCases.length).toBe(26);
    expect(dataCleanupCases.length).toBe(27);

    const dataCleanupRoute = allCases.find(
      (item) => item.id === 'operations-data-cleanup'
    );

    expect(dataCleanupRoute).toBeTruthy();
    expect(dataCleanupRoute?.profiles).toEqual(['data-cleanup']);
  });
});

test.describe(`admin route smoke (${profile})`, () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled) {
      test.skip();
    }
  });

  for (const routeCase of routeCases) {
    test(`${routeCase.id}: reachable and interactive`, async ({ page }) => {
      await installAdminMockServer(page);

      await page.goto(routeCase.path);
      await assertRouteSurface(page, routeCase);

      await performInteraction(page, routeCase);
      await assertRouteSurface(page, routeCase);
    });

    test(`${routeCase.id}: error branch 4xx/5xx remains recoverable`, async ({
      page,
    }) => {
      const mock = await installAdminMockServer(page);

      const errorStatuses = [403, 500];
      for (const status of errorStatuses) {
        await page.goto(routeWithMarker(routeCase.path, `${status}`));
        await assertRouteSurface(page, routeCase);

        // 用户个人设置依赖 /auth/admin/me 鉴权信息，首屏注入会触发守卫跳转登录。
        // 对该页面改为“首屏成功 + 交互阶段注入”以验证异常恢复能力。
        mock.failNext(routeCase.primaryEndpoint, status);

        await performInteraction(page, routeCase);
        await waitForRecoverableSurface(page);

        // 二次交互用于验证故障注入后可恢复到可操作状态。
        await performInteraction(page, routeCase);
        await assertRouteSurface(page, routeCase);
      }
    });
  }
});

test.describe('admin route smoke profile guard', () => {
  test('profile env value is valid', async () => {
    const validProfiles: AdminRouteProfile[] = ['default', 'data-cleanup'];
    expect(validProfiles).toContain(profile);
  });
});
