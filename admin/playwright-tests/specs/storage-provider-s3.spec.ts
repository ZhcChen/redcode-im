import { test, expect } from '@playwright/test';

import { adminE2EEnabled } from '../support/test-context';
import { installAdminMockServer } from '../support/mock-server';

test.describe('admin S3-compatible storage config page', () => {
  test.beforeEach(async () => {
    if (!adminE2EEnabled) {
      test.skip();
    }
  });

  test('renders S3 runtime config workflow and keeps secret inputs empty', async ({
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
      page.getByPlaceholder('http://rustfs:9000', {
        exact: true,
      })
    ).toHaveValue('http://rustfs:9000');
    await expect(
      page.getByPlaceholder('us-east-1', { exact: true })
    ).toHaveValue('us-east-1');
    await expect(page.getByPlaceholder('请输入私有 Bucket 名称')).toHaveValue(
      'demo-private-bucket'
    );

    await expect(
      page.getByPlaceholder('留空表示沿用当前 Access Key')
    ).toHaveValue('');
    await expect(
      page.getByPlaceholder('留空表示沿用当前 Secret Key')
    ).toHaveValue('');
    await expect(page.getByText('当前已配置 Access Key')).toBeVisible();
    await expect(page.getByText('当前已配置 Secret Key')).toBeVisible();

    await page.getByRole('button', { name: '探测配置' }).click();

    await expect(page.getByText('探测结果')).toBeVisible();
    await expect(
      page.getByText('运行时所需能力', { exact: true })
    ).toBeVisible();
    await expect(page.getByText('s3:GetObject').first()).toBeVisible();
    await expect(page.getByText('s3:PutObject').first()).toBeVisible();
    await expect(page.getByText('s3:DeleteObject').first()).toBeVisible();

    await expect(page.getByText('v3').first()).toBeVisible();
    await expect(page.getByText('切换到新的 S3 Key')).toBeVisible();
    await expect(page.getByRole('button', { name: '回滚到 v2' })).toBeVisible();
  });
});
