import { expect, test, type APIRequestContext, type Page } from '@playwright/test';

const apiBaseURL = process.env.H5_APP_API_BASE_URL ?? process.env.VITE_API_BASE_URL ?? 'http://127.0.0.1:8010';
const pngFixture = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
  'base64',
);

interface TestSession {
  token: string;
  user: {
    id: string;
    username: string;
  };
}

interface TestAccount {
  username: string;
  password: string;
  session: TestSession;
}

const uniqueAccount = (prefix: string) => {
  const stamp = `${Date.now()}${Math.random().toString(16).slice(2, 8)}`;
  return `${prefix}_${stamp}`.replace(/[^a-zA-Z0-9._-]/g, '').slice(0, 20).toLowerCase();
};

const registerViaApi = async (request: APIRequestContext, prefix: string): Promise<TestAccount> => {
  const username = uniqueAccount(prefix);
  const password = `H5pass-${username}`;
  const registerResponse = await request.post(`${apiBaseURL}/auth/register`, {
    data: { username, password, nickname: username },
  });
  expect(registerResponse.ok()).toBeTruthy();

  const loginResponse = await request.post(`${apiBaseURL}/auth/login`, {
    data: { username, password },
  });
  expect(loginResponse.ok()).toBeTruthy();
  const session = await loginResponse.json() as TestSession;
  expect(session.token).toBeTruthy();
  expect(session.user.id).toBeTruthy();
  return { username, password, session };
};

const authHeaders = (token: string) => ({
  Authorization: `Bearer ${token}`,
});

const createGroupViaApi = async (
  request: APIRequestContext,
  token: string,
  name: string,
  memberIds: string[],
) => {
  const response = await request.post(`${apiBaseURL}/rooms`, {
    headers: authHeaders(token),
    data: {
      name,
      room_type: 'group',
      member_ids: memberIds,
    },
  });
  expect(response.ok()).toBeTruthy();
  const payload = await response.json() as { room?: { id?: string } } & { id?: string };
  const roomId = payload.room?.id ?? payload.id;
  expect(roomId).toBeTruthy();
  return String(roomId);
};

const sendTextViaApi = async (request: APIRequestContext, token: string, roomId: string, content: string) => {
  const response = await request.post(`${apiBaseURL}/rooms/${roomId}/messages`, {
    headers: authHeaders(token),
    data: { content },
  });
  expect(response.ok()).toBeTruthy();
};

const loadMessagesViaApi = async (request: APIRequestContext, token: string, roomId: string) => {
  const response = await request.get(`${apiBaseURL}/rooms/${roomId}/messages?limit=50`, {
    headers: authHeaders(token),
  });
  expect(response.ok()).toBeTruthy();
  return response.json() as Promise<Array<Record<string, unknown>>>;
};

const markReadViaApi = async (request: APIRequestContext, token: string, roomId: string, messageId: string) => {
  const response = await request.post(`${apiBaseURL}/rooms/${roomId}/messages/read`, {
    headers: authHeaders(token),
    data: { message_id: messageId },
  });
  expect(response.ok()).toBeTruthy();
};

const fetchIncomingFriendRequests = async (request: APIRequestContext, token: string) => {
  const response = await request.get(`${apiBaseURL}/friends/requests?direction=incoming&status=pending`, {
    headers: authHeaders(token),
  });
  expect(response.ok()).toBeTruthy();
  const payload = await response.json() as unknown;
  if (Array.isArray(payload)) return payload as Array<Record<string, unknown>>;
  if (payload && typeof payload === 'object') {
    const data = payload as Record<string, unknown>;
    if (Array.isArray(data.requests)) return data.requests as Array<Record<string, unknown>>;
    if (Array.isArray(data.friend_requests)) return data.friend_requests as Array<Record<string, unknown>>;
  }
  return [];
};

const registerThroughUi = async (page: Page, username: string, password: string): Promise<TestSession> => {
  await page.goto('/login');
  await page.getByRole('tab', { name: '注册' }).click();
  await page.getByLabel('账号').fill(username);
  await page.getByLabel('设置密码').fill(password);
  await page.locator('.login-card__agreement').click();
  await page.getByRole('button', { name: '注册账号' }).click();
  await expect(page).toHaveURL(/\/home$/);
  await expect(page.getByRole('heading', { name: '聊天' })).toBeVisible();

  const rawSession = await page.evaluate(() => window.localStorage.getItem('redcode-h5-session'));
  expect(rawSession).toBeTruthy();
  return JSON.parse(rawSession ?? '{}') as TestSession;
};

test.describe('h5-app browser smoke', () => {
  test('registers, enters a group chat, sends a message, and restores after refresh', async ({ page, request }) => {
    const member = await registerViaApi(request, 'h5e2em');
    const ownerUsername = uniqueAccount('h5e2eo');
    const ownerPassword = `H5pass-${ownerUsername}`;

    const ownerSession = await registerThroughUi(page, ownerUsername, ownerPassword);
    const roomName = `H5 E2E ${Date.now()}`;
    const roomId = await createGroupViaApi(request, ownerSession.token, roomName, [member.session.user.id]);
    const forwardRoomName = `H5 Forward ${Date.now()}`;
    const forwardRoomId = await createGroupViaApi(
      request,
      ownerSession.token,
      forwardRoomName,
      [member.session.user.id],
    );
    await sendTextViaApi(request, ownerSession.token, roomId, 'seed from e2e setup');

    await page.reload();
    await expect(page.getByRole('heading', { name: '聊天' })).toBeVisible();
    await expect(page.getByText(roomName)).toBeVisible();
    await page.getByText(roomName).click();
    await expect(page).toHaveURL(new RegExp(`/chats/${roomId}$`));

    const message = `hello from browser e2e ${Date.now()}`;
    await page.getByPlaceholder('输入消息').fill(message);
    await page.getByRole('button', { name: '发送' }).click();
    await expect(page.getByText(message)).toBeVisible();

    let sentMessageId = '';
    await expect.poll(async () => {
      const sentRows = await loadMessagesViaApi(request, member.session.token, roomId);
      sentMessageId = String(sentRows.find((row) => row.content === message)?.id ?? '');
      return sentMessageId;
    }, {
      message: 'wait for the sent message to become visible to the room member',
      timeout: 10_000,
    }).not.toBe('');
    await markReadViaApi(request, member.session.token, roomId, sentMessageId);

    const messageRow = page.locator('.message-row').filter({ hasText: message }).first();
    await messageRow.getByRole('button', { name: '已读详情' }).click();
    await expect(page).toHaveURL(new RegExp(`/chats/${roomId}/messages/${sentMessageId}/reads$`));
    await expect(page.locator('.reader-row').getByRole('heading', { name: member.username })).toBeVisible();
    await page.getByRole('button', { name: '返回' }).click();
    await expect(page).toHaveURL(new RegExp(`/chats/${roomId}$`));

    const restoredMessageRow = page.locator('.message-row').filter({ hasText: message }).first();
    await restoredMessageRow.getByRole('button', { name: '转发' }).click();
    await expect(page).toHaveURL(new RegExp(`/chats/${roomId}/messages/${sentMessageId}/forward$`));
    await page.getByRole('button', { name: new RegExp(forwardRoomName) }).click();
    await page.getByRole('button', { name: '转发给 1 个会话' }).click();
    await expect(page).toHaveURL(new RegExp(`/chats/${roomId}$`));
    await expect.poll(async () => {
      const forwardedRows = await loadMessagesViaApi(request, member.session.token, forwardRoomId);
      return forwardedRows.some((row) => row.content === message);
    }, { timeout: 10_000 }).toBe(true);

    await page.reload();
    await expect(page.getByText(message)).toBeVisible();

    await page.getByLabel('搜索消息').click();
    await expect(page).toHaveURL(/\/messages\/search/);
    await page.getByPlaceholder('输入关键词、联系人或群名').fill(message);
    await page.getByRole('button', { name: '搜索' }).click();
    const searchResult = page.locator('.message-search__result').filter({ hasText: message }).first();
    await expect(searchResult).toBeVisible();
    await searchResult.click();
    await expect(page).toHaveURL(new RegExp(`/chats/${roomId}`));
    await expect(page.getByText(message)).toBeVisible();

    await page.getByLabel('群设置').click();
    await expect(page).toHaveURL(new RegExp(`/groups/${roomId}/settings$`));
    await expect(page.getByRole('heading', { name: roomName })).toBeVisible();
    await page.locator('input[type="file"]').setInputFiles({
      name: 'room-avatar.png',
      mimeType: 'image/png',
      buffer: pngFixture,
    });
    await expect(page.getByText('群头像已更新')).toBeVisible();
    await page.getByText('置顶聊天').click();
    await expect(page.getByText('已开启')).toBeVisible();
  });

  test('searches a user, sends a friend request, and observes accepted contact state', async ({ page, request }) => {
    const target = await registerViaApi(request, 'h5e2ef');
    const requesterUsername = uniqueAccount('h5e2er');
    const requesterPassword = `H5pass-${requesterUsername}`;
    const requesterSession = await registerThroughUi(page, requesterUsername, requesterPassword);

    await page.getByRole('button', { name: /联系人/ }).click();
    await expect(page.locator('h1').filter({ hasText: '联系人' })).toBeVisible();
    await page.getByPlaceholder('搜索账号 / 昵称').fill(target.username);
    await page.getByRole('button', { name: '搜索' }).click();

    const searchResult = page.locator('.contact-row').filter({ hasText: target.username }).first();
    await expect(searchResult).toBeVisible();
    await searchResult.getByRole('button', { name: '添加' }).click();

    let acceptedRequestId = '';
    await expect.poll(async () => {
      const targetRequests = await fetchIncomingFriendRequests(request, target.session.token);
      acceptedRequestId = String(
        targetRequests.find((item) => String(item.requester_id ?? item.requesterId ?? '') === requesterSession.user.id)?.id
          ?? targetRequests[0]?.id
          ?? '',
      );
      return acceptedRequestId;
    }, {
      message: 'wait for incoming friend request',
      timeout: 10_000,
    }).not.toBe('');
    expect(acceptedRequestId).toBeTruthy();

    const acceptResponse = await request.post(`${apiBaseURL}/friends/requests/${acceptedRequestId}/respond`, {
      headers: authHeaders(target.session.token),
      data: { action: 'accept' },
    });
    expect(acceptResponse.ok()).toBeTruthy();

    await page.reload();
    await page.getByRole('button', { name: /联系人/ }).click();
    const contactRow = page.locator('.contact-row').filter({ hasText: target.username }).filter({ hasText: '私聊' });
    await expect(contactRow).toBeVisible();
  });

  test('uploads current user avatar from profile settings', async ({ page }) => {
    const username = uniqueAccount('h5e2ea');
    const password = `H5pass-${username}`;
    await registerThroughUi(page, username, password);

    await page.getByRole('button', { name: /设置/ }).click();
    await page.locator('.profile-card').click();
    await expect(page).toHaveURL(/\/settings\/profile$/);
    await page.locator('input[type="file"]').setInputFiles({
      name: 'user-avatar.png',
      mimeType: 'image/png',
      buffer: pngFixture,
    });

    await expect(page.getByText('头像已更新')).toBeVisible();
  });
});
