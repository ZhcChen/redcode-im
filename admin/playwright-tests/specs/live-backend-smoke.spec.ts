import { test, expect, type Page, type Response } from '@playwright/test';
import {
  adminE2EEnabled,
  adminLiveBackendEnabled,
} from '../support/test-context';
import {
  ensureLiveChatFixtureSeeded,
  liveChatFixture,
} from '../support/live-backend-fixtures';
import { loginLiveAdmin } from '../support/live-admin-auth';

const trackedWarningPatterns = [
  /Feature flag __VUE_PROD_HYDRATION_MISMATCH_DETAILS__/,
  /menu\.settings\.storageProvider/,
  /menu\.settings\.ipinfoToken/,
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

function matchesResponse(
  response: Response,
  pathname: string,
  method: string = 'GET'
) {
  const url = new URL(response.url());
  return url.pathname === pathname && response.request().method() === method;
}

async function expectOkResponse(
  responsePromise: Promise<Response>,
  label: string
) {
  const response = await responsePromise;
  expect(
    response.ok(),
    `${label} 返回非 2xx: ${response.status()}`
  ).toBeTruthy();
}

async function loginAsAdmin(page: Page, tracker: ConsoleErrorTracker) {
  const checkpoint = tracker.checkpoint();
  await loginLiveAdmin(page, {
    redirectRouteName: 'GeneralSettings',
    expectedUrl: /\/settings\/general/,
  });
  tracker.expectCleanSince(checkpoint, '登录流程');
}

test.describe.configure({ mode: 'serial' });

test.describe('admin live backend smoke', () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled || !adminLiveBackendEnabled) {
      test.skip();
    }
  });

  test('real backend pages load successfully', async ({ page }) => {
    ensureLiveChatFixtureSeeded();
    const tracker = new ConsoleErrorTracker(page);

    await loginAsAdmin(page, tracker);

    await test.step('仪表盘工作台', async () => {
      const checkpoint = tracker.checkpoint();
      const distributionResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/users/geolocation/distribution')
      );

      await page.goto('/dashboard/workplace');

      await expectOkResponse(distributionResponsePromise, '用户地理位置分布');
      await expect(page.getByText('全球用户分布')).toBeVisible();
      tracker.expectCleanSince(checkpoint, '仪表盘工作台');
    });

    await test.step('角色管理', async () => {
      const checkpoint = tracker.checkpoint();
      const roleResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/roles')
      );
      const permissionResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/permissions')
      );

      await page.goto('/system/roles');

      await expectOkResponse(roleResponsePromise, '角色列表');
      await expectOkResponse(permissionResponsePromise, '权限列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '角色管理' })
      ).toBeVisible();
      await expect(page.getByText('super_admin')).toBeVisible();
      tracker.expectCleanSince(checkpoint, '角色管理');
    });

    await test.step('管理员账号', async () => {
      const checkpoint = tracker.checkpoint();
      const adminUsersResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/admin-users')
      );
      const roleResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/roles')
      );

      await page.goto('/system/admin-users');

      await expectOkResponse(adminUsersResponsePromise, '管理员列表');
      await expectOkResponse(roleResponsePromise, '管理员角色列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '管理员账号管理' })
      ).toBeVisible();
      await expect(
        page.getByText('admin@bootstrap.redcode-im.local')
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '管理员账号');
    });

    await test.step('权限点管理', async () => {
      const checkpoint = tracker.checkpoint();
      const permissionResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/permissions')
      );

      await page.goto('/system/permissions');

      await expectOkResponse(permissionResponsePromise, '权限点列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '权限点管理' })
      ).toBeVisible();
      await expect(page.getByText('system:settings')).toBeVisible();
      tracker.expectCleanSince(checkpoint, '权限点管理');
    });

    await test.step('通用设置', async () => {
      const checkpoint = tracker.checkpoint();
      const appNameResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/settings/app-name')
      );
      const uploadPolicyResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/settings/upload-policy')
      );

      await page.goto('/settings/general');

      await expectOkResponse(appNameResponsePromise, '应用名称设置');
      await expectOkResponse(uploadPolicyResponsePromise, '上传策略');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '通用设置' })
      ).toBeVisible();
      await expect(page.getByPlaceholder('请输入应用名称')).not.toHaveValue('');
      tracker.expectCleanSince(checkpoint, '通用设置');
    });

    await test.step('对象存储提供商', async () => {
      const checkpoint = tracker.checkpoint();
      const providerResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/storage-providers')
      );

      await page.goto('/operations/storage-provider');

      await expectOkResponse(providerResponsePromise, '对象存储提供商列表');
      await expect(
        page.locator('.arco-card-header-title', {
          hasText: '对象存储配置',
        })
      ).toBeVisible();
      await expect(
        page.locator('.arco-breadcrumb-item').filter({ hasText: '运维管理' })
      ).toBeVisible();
      await expect(
        page
          .locator('.arco-breadcrumb-item')
          .filter({ hasText: '对象存储提供商' })
      ).toBeVisible();
      await expect(page.getByText('Backblaze B2 配置说明')).toBeVisible();
      await expect(
        page.getByRole('button', { name: '新增配置' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '对象存储提供商');
    });

    await test.step('集群监控', async () => {
      const checkpoint = tracker.checkpoint();
      const monitorResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/nodes/monitor')
      );

      await page.goto('/dashboard/monitor');

      await expectOkResponse(monitorResponsePromise, '集群节点监控');
      await expect(page.getByText('集群节点实时监控')).toBeVisible();
      tracker.expectCleanSince(checkpoint, '集群监控');
    });

    await test.step('Push 设置', async () => {
      const checkpoint = tracker.checkpoint();
      const pushSettingsResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/settings/push')
      );
      const queueStatsResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/push/job-queue/stats')
      );

      await page.goto('/settings/push');

      await expectOkResponse(pushSettingsResponsePromise, 'Push 设置');
      await expectOkResponse(queueStatsResponsePromise, 'Push 队列状态');
      await expect(
        page.locator('.arco-card-header-title', { hasText: 'Push 通知' })
      ).toBeVisible();
      await expect(
        page.getByRole('heading', { name: '全局设置' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, 'Push 设置');
    });

    await test.step('API 性能监控', async () => {
      const checkpoint = tracker.checkpoint();
      const metricsResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/metrics/performance')
      );

      await page.goto('/operations/api-metrics');

      await expectOkResponse(metricsResponsePromise, 'API 性能指标');
      await expect(
        page.locator('.arco-card').filter({ hasText: 'API 性能监控' }).first()
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, 'API 性能监控');
    });

    await test.step('用户管理', async () => {
      const checkpoint = tracker.checkpoint();
      const userListResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/users')
      );

      await page.goto('/user-management/list');

      await expectOkResponse(userListResponsePromise, '用户列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '用户管理' })
      ).toBeVisible();
      await expect(page.getByPlaceholder('搜索用户名')).toBeVisible();
      tracker.expectCleanSince(checkpoint, '用户管理');
    });

    await test.step('文件内容审核', async () => {
      const checkpoint = tracker.checkpoint();
      const auditTasksResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/file-upload-audit/tasks')
      );

      await page.goto('/operations/file-upload-audit');

      await expectOkResponse(auditTasksResponsePromise, '文件内容审核任务列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '文件内容审核' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '文件内容审核');
    });

    await test.step('IP 地理位置 Token 管理', async () => {
      const checkpoint = tracker.checkpoint();
      const tokenListResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/ipinfo-tokens')
      );

      await page.goto('/operations/ipinfo-token');

      await expectOkResponse(tokenListResponsePromise, 'IP Token 列表');
      await expect(
        page.locator('.arco-card-header-title', {
          hasText: 'ipinfo.io Token 管理',
        })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, 'IP 地理位置 Token 管理');
    });

    await test.step('验证码设置', async () => {
      const checkpoint = tracker.checkpoint();
      const captchaResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/settings/captcha')
      );

      await page.goto('/settings/captcha');

      await expectOkResponse(captchaResponsePromise, '验证码设置');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '验证码设置' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '验证码设置');
    });

    await test.step('隐私协议', async () => {
      const checkpoint = tracker.checkpoint();
      const privacyPolicyResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/settings/privacy-policy')
      );

      await page.goto('/settings/privacy-policy');

      await expectOkResponse(privacyPolicyResponsePromise, '隐私协议设置');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '隐私协议' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '隐私协议');
    });

    await test.step('用户协议', async () => {
      const checkpoint = tracker.checkpoint();
      const userAgreementResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/settings/user-agreement')
      );

      await page.goto('/settings/user-agreement');

      await expectOkResponse(userAgreementResponsePromise, '用户协议设置');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '用户协议' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '用户协议');
    });

    await test.step('贴纸设置', async () => {
      const checkpoint = tracker.checkpoint();
      const emojiPacksResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/emoji-packs')
      );

      await page.goto('/settings/emoji-pack');

      await expectOkResponse(emojiPacksResponsePromise, '贴纸列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '贴纸设置' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '贴纸设置');
    });

    await test.step('COS 测试', async () => {
      const checkpoint = tracker.checkpoint();
      const providerResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/storage-providers')
      );

      await page.goto('/operations/cos-test');

      await expectOkResponse(providerResponsePromise, 'COS 提供商列表');
      await expect(
        page.locator('.arco-card-header-title', {
          hasText: '腾讯云 COS 测试',
        })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, 'COS 测试');
    });

    await test.step('系统日志', async () => {
      const checkpoint = tracker.checkpoint();
      const logResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/logs')
      );

      await page.goto('/operations/system-log');

      await expectOkResponse(logResponsePromise, '系统日志列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '系统日志' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '系统日志');
    });

    await test.step('Push 日志', async () => {
      const checkpoint = tracker.checkpoint();
      const pushLogResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/push/logs')
      );

      await page.goto('/operations/push-log');

      await expectOkResponse(pushLogResponsePromise, 'Push 日志列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: 'Push 日志' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, 'Push 日志');
    });

    await test.step('用户反馈', async () => {
      const checkpoint = tracker.checkpoint();
      const feedbackResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/feedbacks')
      );

      await page.goto('/user-management/feedback');

      await expectOkResponse(feedbackResponsePromise, '用户反馈列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '用户反馈' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '用户反馈');
    });

    await test.step('举报记录', async () => {
      const checkpoint = tracker.checkpoint();
      const reportResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/reports')
      );

      await page.goto('/user-management/reports');

      await expectOkResponse(reportResponsePromise, '举报记录列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '举报记录' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '举报记录');
    });

    await test.step('用户聊天记录', async () => {
      const checkpoint = tracker.checkpoint();
      const chatHistoryResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/chat-history')
      );

      await page.goto('/user-management/chat-history');

      await expectOkResponse(chatHistoryResponsePromise, '用户聊天记录列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '用户聊天记录' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '用户聊天记录');
    });

    await test.step('房间聊天记录详情', async () => {
      const checkpoint = tracker.checkpoint();
      const roomHistoryResponsePromise = page.waitForResponse((response) =>
        matchesResponse(
          response,
          `/api/admin/rooms/${liveChatFixture.roomId}/chat-history`
        )
      );

      await page.goto(
        `/user-management/chat-history/room/${liveChatFixture.roomId}`
      );

      await expectOkResponse(roomHistoryResponsePromise, '房间聊天记录详情');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '房间聊天记录' })
      ).toBeVisible();
      await expect(page.getByText(liveChatFixture.messageA)).toBeVisible();
      tracker.expectCleanSince(checkpoint, '房间聊天记录详情');
    });

    await test.step('用户聊天记录详情', async () => {
      const checkpoint = tracker.checkpoint();
      const userRoomsResponsePromise = page.waitForResponse((response) =>
        matchesResponse(
          response,
          `/api/admin/users/${liveChatFixture.userAId}/rooms`
        )
      );

      await page.goto(
        `/user-management/chat-history/user/${liveChatFixture.userAId}`
      );

      await expectOkResponse(userRoomsResponsePromise, '用户房间列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '用户聊天记录' })
      ).toBeVisible();
      await expect(page.getByText(liveChatFixture.roomName)).toBeVisible();

      const userMessagesResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/chat-history')
      );
      await page.getByText('用户消息', { exact: true }).click();
      await expectOkResponse(userMessagesResponsePromise, '用户消息列表');
      await expect(page.getByText(liveChatFixture.messageA)).toBeVisible();
      tracker.expectCleanSince(checkpoint, '用户聊天记录详情');
    });

    await test.step('个人设置', async () => {
      const checkpoint = tracker.checkpoint();
      const profileResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/auth/admin/me')
      );

      await page.goto('/settings/user-profile');

      await expectOkResponse(profileResponsePromise, '当前管理员信息');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '个人设置' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '个人设置');
    });

    await test.step('App 客户端版本管理', async () => {
      const checkpoint = tracker.checkpoint();
      const versionResponsePromise = page.waitForResponse((response) => {
        if (!matchesResponse(response, '/api/admin/app-versions')) {
          return false;
        }

        const url = new URL(response.url());
        return url.searchParams.get('platform') === 'android';
      });

      await page.goto('/versions/frontend');

      await expectOkResponse(versionResponsePromise, 'App 版本列表');
      await expect(
        page.locator('.arco-card-header-title', {
          hasText: 'App客户端版本管理',
        })
      ).toBeVisible();
      await expect(page.getByText('Android').first()).toBeVisible();
      tracker.expectCleanSince(checkpoint, 'App 客户端版本管理');
    });

    await test.step('桌面版本管理', async () => {
      const checkpoint = tracker.checkpoint();
      const versionResponsePromise = page.waitForResponse((response) => {
        if (!matchesResponse(response, '/api/admin/app-versions')) {
          return false;
        }

        const url = new URL(response.url());
        return url.searchParams.get('platform') === 'windows';
      });

      await page.goto('/versions/desktop');

      await expectOkResponse(versionResponsePromise, '桌面版本列表');
      await expect(
        page.locator('.arco-card-header-title', {
          hasText: '桌面客户端版本管理',
        })
      ).toBeVisible();
      await expect(page.getByText('Windows').first()).toBeVisible();
      await expect(
        page.getByRole('button', { name: '新增版本' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '桌面版本管理');
    });

    await test.step('热更新管理', async () => {
      const checkpoint = tracker.checkpoint();
      const hotUpdateResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/hot-updates')
      );

      await page.goto('/versions/hot-updates');

      await expectOkResponse(hotUpdateResponsePromise, '热更新列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '热更新管理' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '热更新管理');
    });

    await test.step('热更新上报', async () => {
      const checkpoint = tracker.checkpoint();
      const hotUpdateEventsResponsePromise = page.waitForResponse((response) =>
        matchesResponse(response, '/api/admin/hot-updates/events')
      );

      await page.goto('/versions/hot-update-events');

      await expectOkResponse(hotUpdateEventsResponsePromise, '热更新上报列表');
      await expect(
        page.locator('.arco-card-header-title', { hasText: '热更新上报' })
      ).toBeVisible();
      tracker.expectCleanSince(checkpoint, '热更新上报');
    });
  });
});
