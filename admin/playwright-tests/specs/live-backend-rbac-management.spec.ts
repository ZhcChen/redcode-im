import {
  test,
  expect,
  type Locator,
  type Page,
  type Response,
} from '@playwright/test';
import {
  adminE2EEnabled,
  adminLiveBackendEnabled,
} from '../support/test-context';
import {
  cleanupLiveRbacFixtures,
  liveRbacFixturePrefix,
} from '../support/live-backend-fixtures';
import { loginLiveAdmin } from '../support/live-admin-auth';

class ConsoleErrorTracker {
  private readonly entries: string[] = [];

  constructor(page: Page) {
    page.on('console', (message) => {
      if (message.type() === 'error') {
        this.entries.push(`[console] ${message.text()}`);
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

function visibleModal(page: Page): Locator {
  return page.locator('.arco-modal:visible').last();
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
  return response;
}

async function selectArcoOption(
  page: Page,
  trigger: Locator,
  optionText: string
) {
  await trigger.click();
  await page
    .locator('.arco-select-option')
    .filter({ hasText: optionText })
    .first()
    .click();
  await page.keyboard.press('Escape');
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

test.describe('admin live backend rbac management', () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled || !adminLiveBackendEnabled) {
      test.skip();
    }
  });

  test('real backend supports RBAC create/update/assignment flows', async ({
    page,
  }) => {
    cleanupLiveRbacFixtures();

    const tracker = new ConsoleErrorTracker(page);
    const runId = `${Date.now()}`;
    const roleName = `Live RBAC Role ${runId}`;
    const updatedRoleName = `Live RBAC Role Updated ${runId}`;
    const roleDescription = `Created by live backend e2e ${runId}`;
    const updatedRoleDescription = `Updated by live backend e2e ${runId}`;
    const roleCode = `${liveRbacFixturePrefix}role${runId}`;
    const createdAdminUsername = `${liveRbacFixturePrefix}admin${runId}`;
    const createdAdminEmail = `${createdAdminUsername}@redcode-im.local`;
    const createdAdminNickname = `Live Admin ${runId}`;
    const createdAdminPassword = 'password123';

    try {
      await loginAsAdmin(page, tracker);

      await test.step('角色创建、编辑、配置权限、删除', async () => {
        const checkpoint = tracker.checkpoint();
        const roleListResponsePromise = page.waitForResponse((response) =>
          matchesResponse(response, '/api/admin/roles')
        );
        const permissionListResponsePromise = page.waitForResponse((response) =>
          matchesResponse(response, '/api/admin/permissions')
        );

        await page.goto('/system/roles');

        await expectOkResponse(roleListResponsePromise, '角色列表');
        await expectOkResponse(permissionListResponsePromise, '权限列表');
        await expect(
          page.locator('.arco-card-header-title', { hasText: '角色管理' })
        ).toBeVisible();

        await page.getByRole('button', { name: '新建角色' }).click();
        const createModal = visibleModal(page);
        await expect(createModal).toBeVisible();
        await createModal.getByPlaceholder('请输入角色名称').fill(roleName);
        await createModal.getByPlaceholder('请输入角色代码').fill(roleCode);
        await createModal.getByPlaceholder('请输入描述').fill(roleDescription);

        const createRoleResponsePromise = page.waitForResponse((response) =>
          matchesResponse(response, '/api/admin/roles', 'POST')
        );
        await createModal.getByRole('button', { name: '确定' }).click();
        const createRoleResponse = await expectOkResponse(
          createRoleResponsePromise,
          '创建角色'
        );
        const createdRole = (await createRoleResponse.json()) as { id: string };

        await expect(createModal).toBeHidden();

        const createdRoleRow = page
          .getByRole('row')
          .filter({ hasText: roleCode })
          .first();
        await expect(createdRoleRow).toBeVisible();
        await expect(createdRoleRow).toContainText(roleName);
        await expect(createdRoleRow).toContainText(roleDescription);

        await createdRoleRow.getByRole('button', { name: '编辑' }).click();
        const editModal = visibleModal(page);
        await expect(editModal).toBeVisible();
        await editModal
          .getByPlaceholder('请输入角色名称')
          .fill(updatedRoleName);
        await editModal
          .getByPlaceholder('请输入描述')
          .fill(updatedRoleDescription);

        const updateRoleResponsePromise = page.waitForResponse((response) =>
          matchesResponse(
            response,
            `/api/admin/roles/${createdRole.id}`,
            'PATCH'
          )
        );
        await editModal.getByRole('button', { name: '确定' }).click();
        await expectOkResponse(updateRoleResponsePromise, '更新角色');
        await expect(editModal).toBeHidden();
        await expect(createdRoleRow).toContainText(updatedRoleName);
        await expect(createdRoleRow).toContainText(updatedRoleDescription);

        const getRolePermissionsResponsePromise = page.waitForResponse(
          (response) =>
            matchesResponse(
              response,
              `/api/admin/roles/${createdRole.id}/permissions`
            )
        );
        await createdRoleRow.getByRole('button', { name: '配置权限' }).click();
        const permissionModal = visibleModal(page);
        await expect(permissionModal).toBeVisible();
        await expectOkResponse(
          getRolePermissionsResponsePromise,
          '获取角色权限'
        );

        await selectArcoOption(
          page,
          permissionModal.locator('.arco-select-view').first(),
          'role:manage - 角色管理'
        );

        const updatePermissionResponsePromise = page.waitForResponse(
          (response) =>
            matchesResponse(
              response,
              `/api/admin/roles/${createdRole.id}/permissions`,
              'PUT'
            )
        );
        await permissionModal.getByRole('button', { name: '确定' }).click();
        await expectOkResponse(updatePermissionResponsePromise, '更新角色权限');
        await expect(permissionModal).toBeHidden();
        await expect(createdRoleRow).toContainText('role:manage');

        await createdRoleRow.getByRole('button', { name: '删除' }).click();
        const deleteModal = visibleModal(page);
        await expect(deleteModal).toBeVisible();

        const deleteRoleResponsePromise = page.waitForResponse((response) =>
          matchesResponse(
            response,
            `/api/admin/roles/${createdRole.id}`,
            'DELETE'
          )
        );
        await deleteModal.getByRole('button', { name: '确定' }).click();
        await expectOkResponse(deleteRoleResponsePromise, '删除角色');
        await expect(createdRoleRow).toHaveCount(0);
        tracker.expectCleanSince(checkpoint, '角色管理联调');
      });

      await test.step('管理员创建、分配角色、状态切换', async () => {
        const checkpoint = tracker.checkpoint();
        const adminUsersResponsePromise = page.waitForResponse((response) =>
          matchesResponse(response, '/api/admin/admin-users')
        );
        const rolesResponsePromise = page.waitForResponse((response) =>
          matchesResponse(response, '/api/admin/roles')
        );

        await page.goto('/system/admin-users');

        await expectOkResponse(adminUsersResponsePromise, '管理员列表');
        await expectOkResponse(rolesResponsePromise, '角色列表');
        await expect(
          page.locator('.arco-card-header-title', { hasText: '管理员账号管理' })
        ).toBeVisible();

        await page.getByRole('button', { name: '新建管理员' }).click();
        const createAdminModal = visibleModal(page);
        await expect(createAdminModal).toBeVisible();
        await createAdminModal
          .getByPlaceholder('请输入管理员用户名')
          .fill(createdAdminUsername);
        await createAdminModal
          .getByPlaceholder('请输入管理员邮箱')
          .fill(createdAdminEmail);
        await createAdminModal
          .getByPlaceholder('请输入管理员密码')
          .fill(createdAdminPassword);
        await createAdminModal
          .getByPlaceholder('请输入管理员昵称')
          .fill(createdAdminNickname);

        const createAdminResponsePromise = page.waitForResponse((response) =>
          matchesResponse(response, '/api/admin/admin-users', 'POST')
        );
        await createAdminModal.getByRole('button', { name: '确定' }).click();
        const createAdminResponse = await expectOkResponse(
          createAdminResponsePromise,
          '创建管理员'
        );
        const createdAdmin = (await createAdminResponse.json()) as {
          id: string;
        };
        await expect(createAdminModal).toBeHidden();

        const createdAdminRow = page
          .getByRole('row')
          .filter({ hasText: createdAdminEmail })
          .first();
        await expect(createdAdminRow).toBeVisible();
        await expect(createdAdminRow).toContainText(createdAdminUsername);

        const getAdminRolesResponsePromise = page.waitForResponse((response) =>
          matchesResponse(
            response,
            `/api/admin/admin-users/${createdAdmin.id}/roles`
          )
        );
        await createdAdminRow.getByRole('button', { name: '分配角色' }).click();
        const roleModal = visibleModal(page);
        await expect(roleModal).toBeVisible();
        await expectOkResponse(getAdminRolesResponsePromise, '获取管理员角色');

        await selectArcoOption(
          page,
          roleModal.locator('.arco-select-view').first(),
          'operator - 运营人员'
        );

        const assignRoleResponsePromise = page.waitForResponse((response) =>
          matchesResponse(
            response,
            `/api/admin/admin-users/${createdAdmin.id}/roles`,
            'PUT'
          )
        );
        await roleModal.getByRole('button', { name: '确定' }).click();
        await expectOkResponse(assignRoleResponsePromise, '分配管理员角色');
        await expect(roleModal).toBeHidden();
        await expect(createdAdminRow).toContainText('operator');

        const deactivateResponsePromise = page.waitForResponse((response) =>
          matchesResponse(
            response,
            `/api/admin/admin-users/${createdAdmin.id}/status`,
            'PATCH'
          )
        );
        await createdAdminRow.getByRole('button', { name: '停用' }).click();
        await expectOkResponse(deactivateResponsePromise, '停用管理员');
        await expect(createdAdminRow).toContainText('停用');
        await expect(
          createdAdminRow.getByRole('button', { name: '启用' })
        ).toBeVisible();

        const activateResponsePromise = page.waitForResponse((response) =>
          matchesResponse(
            response,
            `/api/admin/admin-users/${createdAdmin.id}/status`,
            'PATCH'
          )
        );
        await createdAdminRow.getByRole('button', { name: '启用' }).click();
        await expectOkResponse(activateResponsePromise, '启用管理员');
        await expect(createdAdminRow).toContainText('正常');
        await expect(
          createdAdminRow.getByRole('button', { name: '停用' })
        ).toBeVisible();
        tracker.expectCleanSince(checkpoint, '管理员账号联调');
      });
    } finally {
      cleanupLiveRbacFixtures();
    }
  });
});
