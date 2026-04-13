import { test, expect } from '@playwright/test';

import { adminE2EEnabled } from '../support/test-context';
import { installAdminMockServer } from '../support/mock-server';

test.describe('admin storage config b2 page', () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled) {
      test.skip();
    }
  });

  test('renders B2 runtime config workflow and keeps secret inputs empty', async ({
    page,
  }) => {
    await installAdminMockServer(page);

    await page.goto('/operations/storage-provider');

    await expect(
      page.locator('.arco-card-header-title', { hasText: '对象存储配置' })
    ).toBeVisible();
    await expect(page.getByText('当前生效配置')).toBeVisible();
    await expect(page.getByText('配置历史')).toBeVisible();
    await expect(page.getByRole('button', { name: '探测配置' })).toBeVisible();
    await expect(page.getByRole('button', { name: '应用配置' })).toBeVisible();
    await expect(
      page.getByRole('button', { name: '初始化 Bucket' })
    ).toBeVisible();

    await expect(
      page.getByPlaceholder('https://s3.us-east-005.backblazeb2.com', {
        exact: true,
      })
    ).toHaveValue('https://s3.us-east-005.backblazeb2.com');
    await expect(
      page.getByPlaceholder('us-east-005', { exact: true })
    ).toHaveValue('us-east-005');
    await expect(page.getByPlaceholder('请输入私有 Bucket 名称')).toHaveValue(
      'demo-private-bucket'
    );

    await expect(page.getByPlaceholder('留空表示沿用当前 Key ID')).toHaveValue(
      ''
    );
    await expect(
      page.getByPlaceholder('留空表示沿用当前 Application Key')
    ).toHaveValue('');
    await expect(page.getByText('当前已配置 Key ID')).toBeVisible();
    await expect(page.getByText('当前已配置 Application Key')).toBeVisible();

    await page.getByRole('button', { name: '探测配置' }).click();

    await expect(page.getByText('探测结果')).toBeVisible();
    await expect(
      page.getByText('运行时所需能力', { exact: true })
    ).toBeVisible();
    await expect(page.getByText('readFiles').first()).toBeVisible();
    await expect(page.getByText('writeFiles').first()).toBeVisible();
    await expect(page.getByText('writeBuckets').first()).toBeVisible();

    await expect(page.getByText('v3').first()).toBeVisible();
    await expect(page.getByText('切换到新的 B2 Key')).toBeVisible();
    await expect(page.getByRole('button', { name: '回滚到 v2' })).toBeVisible();
  });
});
