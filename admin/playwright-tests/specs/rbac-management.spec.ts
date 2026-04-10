import { test, expect, type Page, type Locator } from '@playwright/test';

import { adminE2EEnabled } from '../support/test-context';
import { installAdminMockServer } from '../support/mock-server';

function visibleModal(page: Page): Locator {
  return page.locator('.arco-modal:visible').last();
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

test.describe('admin rbac management flows', () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled) {
      test.skip();
    }
  });

  test('role page supports create, edit, assign permission and delete', async ({
    page,
  }) => {
    await installAdminMockServer(page);

    await page.goto('/system/roles');

    await page.getByRole('button', { name: '新建角色' }).click();
    const createModal = visibleModal(page);
    await expect(createModal).toBeVisible();
    await createModal.getByPlaceholder('请输入角色名称').fill('内容审核员');
    await createModal
      .getByPlaceholder('请输入角色代码')
      .fill('content_reviewer');
    await createModal.getByPlaceholder('请输入描述').fill('负责内容审核');
    await createModal.getByRole('button', { name: '确定' }).click();
    await expect(createModal).toBeHidden();
    await page.getByRole('button', { name: '刷新' }).click();

    const createdRow = page
      .locator('.arco-table-tr')
      .filter({ hasText: 'content_reviewer' })
      .first();
    await expect(createdRow).toBeVisible();
    await expect(createdRow).toContainText('负责内容审核');

    await createdRow.getByRole('button', { name: '编辑' }).click();
    const editModal = visibleModal(page);
    await expect(editModal).toBeVisible();
    await editModal.getByPlaceholder('请输入角色名称').fill('内容审核员升级版');
    await editModal.getByPlaceholder('请输入描述').fill('负责高级内容审核');
    await editModal.getByRole('button', { name: '确定' }).click();
    await expect(editModal).toBeHidden();
    await page.getByRole('button', { name: '刷新' }).click();

    const updatedRow = page
      .locator('.arco-table-tr')
      .filter({ hasText: '内容审核员升级版' })
      .first();
    await expect(updatedRow).toBeVisible();
    await expect(updatedRow).toContainText('负责高级内容审核');

    await updatedRow.getByRole('button', { name: '配置权限' }).click();
    const permissionModal = visibleModal(page);
    await expect(permissionModal).toBeVisible();
    await selectArcoOption(
      page,
      permissionModal.locator('.arco-select-view').first(),
      'role:manage - 角色管理'
    );
    await permissionModal.getByRole('button', { name: '确定' }).click();
    await expect(permissionModal).toBeHidden();
    await page.getByRole('button', { name: '刷新' }).click();

    await expect(updatedRow).toContainText('role:manage');

    await updatedRow.getByRole('button', { name: '删除' }).click();
    const deleteModal = visibleModal(page);
    await expect(deleteModal).toBeVisible();
    await deleteModal.getByRole('button', { name: '确定' }).click();

    await expect(
      page.locator('.arco-table-tr').filter({ hasText: 'content_reviewer' })
    ).toHaveCount(0);
  });

  test('admin user page supports create, assign role and toggle status', async ({
    page,
  }) => {
    await installAdminMockServer(page);

    await page.goto('/system/admin-users');

    await page.getByRole('button', { name: '新建管理员' }).click();
    const createModal = visibleModal(page);
    await expect(createModal).toBeVisible();
    await createModal.getByPlaceholder('请输入管理员用户名').fill('reviewer');
    await createModal
      .getByPlaceholder('请输入管理员邮箱')
      .fill('reviewer@example.com');
    await createModal.getByPlaceholder('请输入管理员密码').fill('password123');
    await createModal.getByPlaceholder('请输入管理员昵称').fill('审核员');
    await createModal.getByRole('button', { name: '确定' }).click();
    await expect(createModal).toBeHidden();

    const createdRow = page
      .locator('.arco-table-tr')
      .filter({ hasText: 'reviewer@example.com' })
      .first();
    await expect(createdRow).toBeVisible();

    await createdRow.getByRole('button', { name: '分配角色' }).click();
    const roleModal = visibleModal(page);
    await expect(roleModal).toBeVisible();
    await selectArcoOption(
      page,
      roleModal.locator('.arco-select-view').first(),
      'operator - 运营管理员'
    );
    await roleModal.getByRole('button', { name: '确定' }).click();

    await expect(createdRow).toContainText('operator');

    await createdRow.getByRole('button', { name: '停用' }).click();
    await expect(createdRow).toContainText('停用');
    await expect(createdRow).toContainText('启用');
  });
});
