import { test, expect } from '@playwright/test';

import { adminE2EEnabled } from '../support/test-context';
import { installAdminMockServer } from '../support/mock-server';

test.describe('admin storage provider b2 page', () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled) {
      test.skip();
    }
  });

  test('storage provider page defaults to b2 semantics and does not backfill secrets on edit', async ({
    page,
  }) => {
    await installAdminMockServer(page);

    await page.goto('/operations/storage-provider');

    await expect(
      page.locator('.arco-card-header-title', { hasText: '对象存储配置' })
    ).toBeVisible();
    await expect(page.getByText('Backblaze B2 配置说明')).toBeVisible();
    await expect(page.getByText('测试 B2 配置')).toBeVisible();
    await expect(
      page.locator('.provider-table').getByText('Backblaze B2', { exact: true })
    ).toBeVisible();

    await page.getByRole('button', { name: '编辑' }).click();
    const editModal = page.locator('.arco-modal:visible').last();
    await expect(editModal).toBeVisible();
    await expect(editModal.getByText('编辑对象存储配置')).toBeVisible();
    await expect(editModal.getByText('Key ID', { exact: true })).toBeVisible();
    await expect(
      editModal.getByText('Application Key', { exact: true })
    ).toBeVisible();
    await expect(
      editModal.getByPlaceholder('留空表示沿用当前 Key ID')
    ).toHaveValue('');
    await expect(
      editModal.getByPlaceholder('留空表示沿用当前 Application Key')
    ).toHaveValue('');
    await expect(editModal.getByText('当前已配置 Key ID')).toBeVisible();
    await expect(
      editModal.getByText('当前已配置 Application Key')
    ).toBeVisible();

    await editModal.getByRole('button', { name: '取消' }).click();
    await expect(editModal).toBeHidden();

    await page.getByRole('button', { name: '新增配置' }).click();
    const createModal = page.locator('.arco-modal:visible').last();
    await expect(createModal).toBeVisible();
    await expect(createModal.getByText('新增对象存储配置')).toBeVisible();
    await expect(
      createModal.getByPlaceholder('请输入 Backblaze B2 Key ID')
    ).toBeVisible();
    await expect(
      createModal.getByPlaceholder('请输入 Backblaze B2 Application Key')
    ).toBeVisible();
    await expect(
      createModal.getByPlaceholder('https://s3.us-east-005.backblazeb2.com')
    ).toBeVisible();
    await expect(
      createModal.getByPlaceholder('请输入私有 Bucket 名称')
    ).toBeVisible();
  });
});
