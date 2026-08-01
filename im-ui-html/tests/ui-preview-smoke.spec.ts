import { expect, test } from '@playwright/test';
import path from 'node:path';

import { openPreview } from './preview';
import { previewRoutes } from './routes';
import { visualRoutes } from './visual-routes';

for (const route of previewRoutes) {
  test(`${route.id} renders without console errors`, async ({ page }, testInfo) => {
    const errors: string[] = [];
    page.on('console', (message) => {
      if (message.type() === 'error') errors.push(message.text());
    });
    page.on('pageerror', (error) => errors.push(error.message));

    await openPreview(page, testInfo, route.path);
    const screen = page.locator('.phone-screen .screen');
    await expect(page.locator('.phone-screen')).toHaveCount(1);

    const horizontalOverflow = await screen.evaluate((element) => element.scrollWidth - element.clientWidth);
    expect(horizontalOverflow, `${route.path} horizontally overflows`).toBeLessThanOrEqual(1);
    expect(errors).toEqual([]);
  });
}

for (const route of visualRoutes) {
  test(`@visual ${route.id}`, async ({ page }, testInfo) => {
    await openPreview(page, testInfo, route.path);
    await page.locator('.phone-frame').screenshot({
      path: path.resolve('test-results/visual-review', `${testInfo.project.name}-${route.id}.png`),
      animations: 'disabled',
    });
  });
}
