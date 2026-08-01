import { expect, type Page, type TestInfo } from '@playwright/test';

import { previewHash } from './routes';

const deviceLabels: Record<string, string> = {
  'iphone-12-pro': 'iPhone 12 Pro',
  'iphone-16-pro-max': 'iPhone 16 Pro Max',
  'pixel-8-pro': 'Pixel 8 Pro',
};

export async function openPreview(page: Page, testInfo: TestInfo, path: string) {
  await page.goto(previewHash(path));
  const deviceLabel = deviceLabels[testInfo.project.name];
  if (!deviceLabel) throw new Error(`Unsupported preview project: ${testInfo.project.name}`);

  const deviceButton = page.getByRole('button', { name: deviceLabel });
  await deviceButton.click();
  await expect(deviceButton).toHaveAttribute('aria-pressed', 'true');
  await expect(page.locator('.phone-screen .screen')).toBeVisible();
}
