import { test, expect } from '@playwright/test';
import path from 'node:path';

const API_BASE_URL = process.env.DESKTOP_API_URL ?? 'http://localhost:8010';
const CAPTCHA_CODE = process.env.DESKTOP_UNIVERSAL_CAPTCHA ?? '666666';

interface LoginResult {
  token: string;
  userId: string;
  username: string;
}

const apiFetch = async (url: string, init: RequestInit = {}) => {
  const response = await fetch(url, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Request failed ${response.status} ${response.statusText}: ${body}`);
  }

  return response.json();
};

const loginWithSms = async (phone: string): Promise<LoginResult> => {
  const data = await apiFetch(`${API_BASE_URL}/auth/login/sms`, {
    method: 'POST',
    body: JSON.stringify({ phone, code: CAPTCHA_CODE }),
  });

  if (!data?.token || !data?.user?.id) {
    throw new Error('Unexpected login response');
  }

  return {
    token: data.token as string,
    userId: data.user.id as string,
    username: data.user.username as string,
  };
};

const createGroupRoom = async (token: string, name: string, memberIds: string[]) => {
  const payload = {
    name,
    description: `e2e generated at ${new Date().toISOString()}`,
    room_type: 'group',
    member_ids: memberIds,
  };

  return apiFetch(`${API_BASE_URL}/rooms`, {
    method: 'POST',
    body: JSON.stringify(payload),
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
};

test.describe('图片上传回归路径', () => {
  test('验证码登录后上传图片消息', async ({ page }) => {
    const timestamp = Date.now();
    const mainAccount = `upload-main-${timestamp}`;
    const buddyAccount = `upload-buddy-${timestamp}`;
    const roomName = `E2E图片测试-${timestamp}`;

    // 准备账号与群组
    const [mainLogin, buddyLogin] = await Promise.all([
      loginWithSms(mainAccount),
      loginWithSms(buddyAccount),
    ]);

    await createGroupRoom(mainLogin.token, roomName, [buddyLogin.userId]);

    // UI 登录
    await page.goto('/login');
    await page.getByText('验证码登录').click();
    await page.getByPlaceholder('请输入账号').fill(mainAccount);
    const captchaInput = page.getByPlaceholder('请输入验证码');
    await captchaInput.fill(CAPTCHA_CODE);
    await page.getByRole('button', { name: '登录账号' }).click();

    await page.waitForURL(/\/home\/chat/, { timeout: 20_000 });

    const chatLocator = page.locator('.chat-item').filter({ hasText: roomName }).first();
    await expect(chatLocator).toBeVisible({ timeout: 20_000 });
    await chatLocator.click();

    // 等待消息区域加载完成
    await page.waitForSelector('.chat-window', { timeout: 20_000 });

    // 触发文件选择并上传
    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('img.upload-icon');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles(path.join(__dirname, 'assets', 'sample-image.png'));

    const imageBubble = page.locator('.chat-window img.message-image').last();
    await expect(imageBubble).toBeVisible({ timeout: 20_000 });
    await expect(imageBubble).toHaveAttribute('src', /blob:|http/, { timeout: 30_000 });

    const failureBadge = page.locator('.message-status.failed');
    await expect(failureBadge).toHaveCount(0);
  });
});
