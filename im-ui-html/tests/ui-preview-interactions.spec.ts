import { expect, test } from '@playwright/test';

import { openPreview } from './preview';

test('short press enters chat and route transition animates', async ({ page }, testInfo) => {
  await openPreview(page, testInfo, '/chats');
  const firstChat = page.locator('.runtime-conversation__open').first();
  await firstChat.click();
  await expect(page).toHaveURL(/#\/mobile-design\/chat\//);
  await expect(page.locator('.prototype-shell')).toHaveClass(/is-route-entering/);
});

test('long press opens bounded conversation menu and keeps tab bar visible', async ({ page }, testInfo) => {
  await openPreview(page, testInfo, '/chats');
  const firstChat = page.locator('.runtime-conversation__open').first();
  const box = await firstChat.boundingBox();
  expect(box).not.toBeNull();
  await firstChat.dispatchEvent('pointerdown', {
    pointerId: 1,
    pointerType: 'touch',
    clientX: box!.x + 8,
    clientY: box!.y + 8,
  });
  await page.waitForTimeout(620);
  await firstChat.dispatchEvent('pointerup', { pointerId: 1, pointerType: 'touch' });

  const menu = page.locator('.runtime-conversation-menu');
  await expect(menu).toBeVisible();
  await expect(page.locator('.runtime-tab-bar')).toBeVisible();
  const [menuBox, screenBox] = await Promise.all([menu.boundingBox(), page.locator('.phone-screen').boundingBox()]);
  expect(menuBox).not.toBeNull();
  expect(screenBox).not.toBeNull();
  expect(menuBox!.x).toBeGreaterThanOrEqual(screenBox!.x);
  expect(menuBox!.y).toBeGreaterThanOrEqual(screenBox!.y);
  expect(menuBox!.x + menuBox!.width).toBeLessThanOrEqual(screenBox!.x + screenBox!.width);
  expect(menuBox!.y + menuBox!.height).toBeLessThanOrEqual(screenBox!.y + screenBox!.height);
});

test('same-page menu action does not replay screen entrance', async ({ page }, testInfo) => {
  await openPreview(page, testInfo, '/chats');
  const firstChat = page.locator('.runtime-conversation__open').first();
  await firstChat.dispatchEvent('pointerdown', { pointerId: 1, pointerType: 'touch' });
  await page.waitForTimeout(620);
  await firstChat.dispatchEvent('pointerup', { pointerId: 1, pointerType: 'touch' });
  await page.locator('.runtime-conversation-menu button').first().click();
  await expect(page.locator('.prototype-shell')).not.toHaveClass(/is-route-entering/);
});

test('composer panels transition between content-driven heights', async ({ page }, testInfo) => {
  await openPreview(page, testInfo, '/chat/c_room_launch');
  const emoji = page.getByRole('button', { name: '表情' });
  const more = page.getByRole('button', { name: '更多操作' });
  await emoji.click();
  const panel = page.locator('#runtime-composer-panel');
  await expect(panel).toHaveAttribute('aria-hidden', 'false');
  const emojiHeight = await panel.evaluate((element) => element.getBoundingClientRect().height);
  await more.click();
  await expect(more).toHaveAttribute('aria-expanded', 'true');
  await page.waitForTimeout(320);
  const moreHeight = await panel.evaluate((element) => element.getBoundingClientRect().height);
  expect(emojiHeight).toBeGreaterThan(0);
  expect(moreHeight).toBeGreaterThan(0);
  expect(moreHeight).not.toBe(emojiHeight);
});

test('escape closes conversation dialog and restores focus', async ({ page }, testInfo) => {
  await openPreview(page, testInfo, '/chats');
  const firstChat = page.locator('.runtime-conversation__open').first();
  await firstChat.focus();
  await firstChat.dispatchEvent('pointerdown', { pointerId: 1, pointerType: 'touch' });
  await page.waitForTimeout(620);
  await firstChat.dispatchEvent('pointerup', { pointerId: 1, pointerType: 'touch' });
  await expect(page.getByRole('dialog', { name: /会话操作/ })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog', { name: /会话操作/ })).toHaveCount(0);
  await expect(firstChat).toBeFocused();
});

test('conversation dialog exposes named actions and primary controls keep 44px targets', async ({ page }, testInfo) => {
  await openPreview(page, testInfo, '/chats');
  const firstChat = page.locator('.runtime-conversation__open').first();
  await firstChat.dispatchEvent('pointerdown', { pointerId: 1, pointerType: 'touch' });
  await page.waitForTimeout(620);
  await firstChat.dispatchEvent('pointerup', { pointerId: 1, pointerType: 'touch' });

  const dialog = page.getByRole('dialog', { name: /会话操作/ });
  await expect(dialog).toHaveAttribute('aria-modal', 'true');
  await expect(dialog.getByRole('button', { name: /置顶会话|取消置顶/ })).toBeVisible();
  await expect(dialog.getByRole('button', { name: '仅提及' })).toBeVisible();
  await expect(dialog.getByRole('button', { name: '静音' })).toBeVisible();
  await expect(dialog.getByRole('button', { name: '归档会话' })).toBeVisible();

  await page.keyboard.press('Escape');
  const controls = [
    page.getByRole('button', { name: '搜索消息' }),
    page.getByRole('button', { name: '创建群聊' }),
    page.getByRole('button', { name: '聊天' }),
  ];
  for (const control of controls) {
    const box = await control.boundingBox();
    expect(box).not.toBeNull();
    expect(box!.width).toBeGreaterThanOrEqual(44);
    expect(box!.height).toBeGreaterThanOrEqual(44);
  }
});

test('reduced motion disables composer panel animation and transition', async ({ page }, testInfo) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await openPreview(page, testInfo, '/chat/c_room_launch');
  await page.getByRole('button', { name: '表情' }).click();

  const motion = await page.locator('#runtime-composer-panel').evaluate((element) => {
    const style = getComputedStyle(element);
    return {
      animationName: style.animationName,
      animationDuration: style.animationDuration,
      transitionDuration: style.transitionDuration,
    };
  });
  expect(motion.animationName).toBe('none');
  expect(motion.animationDuration.split(',').every((duration) => duration.trim() === '0s')).toBe(true);
  expect(motion.transitionDuration.split(',').every((duration) => duration.trim() === '0s')).toBe(true);
});

test('moment fixtures cover every media count from zero to nine', async ({ page }, testInfo) => {
  await openPreview(page, testInfo, '/discover/moments');
  const counts = await page.locator('.moment-media-grid').evaluateAll((elements) =>
    elements.map((element) => Number(Array.from(element.classList).find((name) => name.startsWith('moment-media-grid--count-'))?.split('-').pop())),
  );
  expect(new Set(counts)).toEqual(new Set([1, 2, 3, 4, 5, 6, 7, 8, 9]));
});
