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

const becomeFriendsViaApi = async (
  request: APIRequestContext,
  requester: TestAccount,
  target: TestAccount,
) => {
  const createResponse = await request.post(`${apiBaseURL}/friends/requests`, {
    headers: authHeaders(requester.session.token),
    data: { target_user_id: target.session.user.id, message: 'H5 E2E 群成员管理' },
  });
  expect(createResponse.ok()).toBeTruthy();
  const friendRequest = await createResponse.json() as { id?: string };
  expect(friendRequest.id).toBeTruthy();

  const acceptResponse = await request.post(`${apiBaseURL}/friends/requests/${friendRequest.id}/respond`, {
    headers: authHeaders(target.session.token),
    data: { action: 'accept' },
  });
  expect(acceptResponse.ok()).toBeTruthy();
};

const loadMembersViaApi = async (request: APIRequestContext, token: string, roomId: string) => {
  const response = await request.get(`${apiBaseURL}/rooms/${roomId}/members`, {
    headers: authHeaders(token),
  });
  expect(response.ok()).toBeTruthy();
  const payload = await response.json() as Array<Record<string, unknown>> | { members?: Array<Record<string, unknown>> };
  return Array.isArray(payload) ? payload : payload.members ?? [];
};

const loadAdminsViaApi = async (request: APIRequestContext, token: string, roomId: string) => {
  const response = await request.get(`${apiBaseURL}/rooms/${roomId}/admins`, {
    headers: authHeaders(token),
  });
  expect(response.ok()).toBeTruthy();
  const payload = await response.json() as { admins?: Array<Record<string, unknown>> };
  return payload.admins ?? [];
};

const loadRulesViaApi = async (request: APIRequestContext, token: string, roomId: string) => {
  const response = await request.get(`${apiBaseURL}/rooms/${roomId}/rules`, {
    headers: authHeaders(token),
  });
  expect(response.ok()).toBeTruthy();
  const payload = await response.json() as { rules?: Array<Record<string, unknown>> };
  return payload.rules ?? [];
};

const loadMutesViaApi = async (request: APIRequestContext, token: string, roomId: string) => {
  const response = await request.get(`${apiBaseURL}/rooms/${roomId}/mutes`, {
    headers: authHeaders(token),
  });
  expect(response.ok()).toBeTruthy();
  const payload = await response.json() as { mutes?: Array<Record<string, unknown>> };
  return payload.mutes ?? [];
};

const loadGroupSettingsViaApi = async (request: APIRequestContext, token: string, roomId: string) => {
  const response = await request.get(`${apiBaseURL}/rooms/${roomId}/settings`, {
    headers: authHeaders(token),
  });
  expect(response.ok()).toBeTruthy();
  const payload = await response.json() as { settings?: Record<string, unknown> };
  return payload.settings ?? {};
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
    const roomRow = page.locator('.chat-row').filter({ hasText: roomName }).first();
    await roomRow.click({ button: 'right' });
    await page.getByRole('menuitem', { name: '置顶会话' }).click();
    await expect(roomRow).toHaveClass(/chat-row--pinned/);
    await roomRow.click({ button: 'right' });
    await page.getByRole('menuitem', { name: '取消置顶' }).click();
    await expect(roomRow).not.toHaveClass(/chat-row--pinned/);
    await page.getByText(roomName).click();
    await expect(page).toHaveURL(new RegExp(`/chats/${roomId}$`));

    const message = `hello from browser e2e ${Date.now()}`;
    await page.getByPlaceholder('输入消息').fill(message);
    await page.getByRole('button', { name: '发送', exact: true }).click();
    await expect(page.getByText(message)).toBeVisible();

    const attachmentName = `browser-${Date.now()}.txt`;
    await page.getByLabel('选择文件').setInputFiles({
      name: attachmentName,
      mimeType: 'text/plain',
      buffer: Buffer.from('browser attachment e2e'),
    });
    await expect(page.getByText(attachmentName)).toBeVisible();
    await expect.poll(async () => {
      const rows = await loadMessagesViaApi(request, member.session.token, roomId);
      return rows.some((row) => JSON.stringify(row).includes(attachmentName));
    }, { timeout: 10_000 }).toBe(true);

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
    await expect(messageRow.locator('.message-row__status')).toHaveText('已读');
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
    await expect(page).toHaveURL((url) => (
      url.pathname === `/chats/${roomId}` && url.searchParams.get('messageId') === sentMessageId
    ));
    await expect(page.getByText(message)).toBeVisible();
    await expect(page.locator(`[data-message-id="${sentMessageId}"]`)).toHaveClass(/message-row--highlighted/);
    await page.reload();
    await expect(page.locator(`[data-message-id="${sentMessageId}"]`)).toHaveClass(/message-row--highlighted/);

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
    await page.locator('.contact-shortcuts').getByRole('button', { name: /好友申请/ }).click();
    await expect(page).toHaveURL(/\/contacts\/requests$/);
    await page.getByRole('button', { name: '返回' }).click();
    await page.locator('.contact-shortcuts').getByRole('button', { name: /添加好友/ }).click();
    await expect(page).toHaveURL(/\/contacts\/add$/);
    await page.getByPlaceholder('搜索账号 / 昵称').fill(target.username);
    await page.getByPlaceholder('介绍一下自己').fill('来自 H5 E2E 的好友申请');
    await page.getByRole('button', { name: '搜索' }).click();

    const searchResult = page.locator('.contact-page__row').filter({ hasText: target.username }).first();
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

    await page.goto('/home');
    await page.getByRole('button', { name: /联系人/ }).click();
    const contactRow = page.locator('.contact-row').filter({ hasText: target.username }).filter({ hasText: '私聊' });
    await expect(contactRow).toBeVisible();
    await contactRow.getByRole('button', { name: '资料' }).click();
    await expect(page).toHaveURL(new RegExp(`/contacts/${target.session.user.id}$`));
    await page.getByPlaceholder('留空可清除备注').fill('E2E 联系人');
    await page.getByRole('button', { name: '保存备注' }).click();
    await expect(page.getByText('备注已更新')).toBeVisible();

    await page.getByRole('button', { name: '举报该用户' }).click();
    await page.getByPlaceholder('请描述具体问题').fill('自动化举报流程验证');
    await page.getByLabel('选择举报截图').setInputFiles({
      name: 'report-evidence.png', mimeType: 'image/png', buffer: pngFixture,
    });
    await page.getByRole('button', { name: '提交举报' }).click();
    await expect(page.getByText('举报已提交，我们会尽快审核。')).toBeVisible();
    await page.getByRole('button', { name: '完成' }).click();

    const createdGroupName = `H5 UI Group ${Date.now()}`;
    await page.goto('/home');
    await page.getByRole('button', { name: /联系人/ }).click();
    await page.locator('.contact-shortcuts').getByRole('button', { name: /群聊/ }).click();
    await expect(page).toHaveURL(/\/groups$/);
    await page.getByRole('button', { name: '新建' }).click();
    await page.getByPlaceholder('输入群聊名称').fill(createdGroupName);
    await page.getByPlaceholder('介绍群聊用途').fill('H5 独立建群流程');
    await page.locator('.contact-page__row').filter({ hasText: target.username }).click();
    await page.getByRole('button', { name: '创建' }).click();
    await expect(page).toHaveURL(/\/chats\//);
    await expect(page.getByRole('heading', { name: createdGroupName })).toBeVisible();

    await page.goto('/groups');
    const createdGroupRow = page.locator('.contact-page__row').filter({ hasText: createdGroupName });
    await expect(createdGroupRow).toBeVisible();
    await createdGroupRow.getByRole('button', { name: '收藏群聊' }).click();
    await expect(createdGroupRow.getByRole('button', { name: '取消收藏群聊' })).toBeVisible();

    await page.goto(`/contacts/${target.session.user.id}`);

    await page.getByRole('button', { name: '删除好友' }).click();
    await page.getByRole('button', { name: '确认删除好友' }).click();
    await expect(page).toHaveURL(/\/home$/);
    await expect(page.getByText(target.username)).toHaveCount(0);
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

  test('invites and removes a group member as the owner', async ({ page, request }) => {
    const existingMember = await registerViaApi(request, 'h5e2egm');
    const candidate = await registerViaApi(request, 'h5e2egi');
    const approvedApplicant = await registerViaApi(request, 'h5e2eja');
    const rejectedApplicant = await registerViaApi(request, 'h5e2ejr');
    const ownerUsername = uniqueAccount('h5e2ego');
    const ownerPassword = `H5pass-${ownerUsername}`;
    const ownerSession = await registerThroughUi(page, ownerUsername, ownerPassword);
    const owner: TestAccount = { username: ownerUsername, password: ownerPassword, session: ownerSession };
    await becomeFriendsViaApi(request, owner, candidate);

    const roomId = await createGroupViaApi(
      request,
      ownerSession.token,
      `H5 Members ${Date.now()}`,
      [existingMember.session.user.id],
    );
    await page.goto(`/groups/${roomId}/members`);
    await expect(page.getByRole('heading', { name: '群成员' })).toBeVisible();
    await expect(page.locator('.contact-page__row').filter({ hasText: existingMember.username })).toBeVisible();

    await page.getByRole('button', { name: '邀请' }).click();
    await expect(page).toHaveURL(new RegExp(`/groups/${roomId}/invite$`));
    await page.locator('.contact-page__row').filter({ hasText: candidate.username }).click();
    await page.getByRole('button', { name: '添加', exact: true }).click();
    await expect(page.getByText('已添加 1 人')).toBeVisible();
    await expect.poll(async () => {
      const members = await loadMembersViaApi(request, ownerSession.token, roomId);
      return members.some((member) => String(member.user_id ?? member.userId ?? '') === candidate.session.user.id);
    }).toBe(true);

    await page.getByRole('button', { name: '返回' }).click();
    await page.getByRole('button', { name: '返回' }).click();
    await expect(page).toHaveURL(new RegExp(`/groups/${roomId}/settings$`));
    await page.getByRole('button', { name: /管理员设置/ }).click();
    const adminCandidateRow = page.locator('.contact-page__row').filter({ hasText: candidate.username });
    await adminCandidateRow.getByRole('button', { name: '设为管理员' }).click();
    await adminCandidateRow.getByRole('button', { name: '确认' }).click();
    await expect(page.getByText('管理员已任命')).toBeVisible();
    await expect.poll(async () => {
      const admins = await loadAdminsViaApi(request, ownerSession.token, roomId);
      return admins.some((admin) => String(admin.admin_id ?? admin.adminId ?? '') === candidate.session.user.id);
    }).toBe(true);

    const adminRow = page.locator('.contact-page__row').filter({ hasText: candidate.username });
    await adminRow.getByRole('button', { name: '撤销' }).click();
    await adminRow.getByRole('button', { name: '确认' }).click();
    await expect(page.getByText('管理员身份已撤销')).toBeVisible();
    await expect.poll(async () => {
      const admins = await loadAdminsViaApi(request, ownerSession.token, roomId);
      return admins.some((admin) => String(admin.admin_id ?? admin.adminId ?? '') === candidate.session.user.id);
    }).toBe(false);

    await page.getByRole('button', { name: '返回' }).click();
    await page.getByRole('button', { name: /群规/ }).click();
    const ruleTitle = `H5 群规 ${Date.now()}`;
    await page.getByPlaceholder('请输入群规标题').fill(ruleTitle);
    await page.getByPlaceholder('请输入群规内容').fill('请保持友善交流，不发布无关信息。');
    await page.getByRole('button', { name: '保存', exact: true }).click();
    await expect(page.getByText('群规已添加')).toBeVisible();
    let ruleId = '';
    await expect.poll(async () => {
      const rules = await loadRulesViaApi(request, ownerSession.token, roomId);
      ruleId = String(rules.find((rule) => rule.title === ruleTitle)?.id ?? '');
      return ruleId;
    }).not.toBe('');

    const ruleCard = page.locator('.rule-card').filter({ hasText: ruleTitle });
    await ruleCard.getByRole('button', { name: '编辑' }).click();
    await page.getByPlaceholder('请输入群规内容').fill('请保持友善交流，并尊重每一位群成员。');
    await page.getByRole('button', { name: '保存', exact: true }).click();
    await expect(page.getByText('群规已更新')).toBeVisible();
    await expect.poll(async () => {
      const rules = await loadRulesViaApi(request, ownerSession.token, roomId);
      return rules.find((rule) => String(rule.id ?? '') === ruleId)?.content;
    }).toBe('请保持友善交流，并尊重每一位群成员。');

    await ruleCard.getByRole('button', { name: '删除' }).click();
    await ruleCard.getByRole('button', { name: '确认删除' }).click();
    await expect(page.getByText('群规已删除')).toBeVisible();
    await expect.poll(async () => {
      const rules = await loadRulesViaApi(request, ownerSession.token, roomId);
      return rules.some((rule) => String(rule.id ?? '') === ruleId);
    }).toBe(false);

    await page.getByRole('button', { name: '返回' }).click();
    await page.getByRole('button', { name: /禁言管理/ }).click();
    await page.getByLabel('开启全体禁言').check();
    await page.getByLabel('持续时间').selectOption('60');
    await page.getByPlaceholder('填写全体禁言原因').fill('H5 E2E 全体禁言');
    await page.getByRole('button', { name: '保存全体禁言' }).click();
    await expect(page.getByText('全体禁言已开启')).toBeVisible();
    await expect.poll(async () => {
      const settings = await loadGroupSettingsViaApi(request, ownerSession.token, roomId);
      return settings.global_mute_enabled;
    }).toBe(true);

    await page.getByLabel('选择普通成员').selectOption(candidate.session.user.id);
    await page.getByLabel('禁言时长').selectOption('24');
    await page.getByPlaceholder('填写成员禁言原因').fill('H5 E2E 成员禁言');
    await page.getByRole('button', { name: '确认禁言' }).click();
    await expect(page.getByText('成员已禁言')).toBeVisible();
    await expect.poll(async () => {
      const mutes = await loadMutesViaApi(request, ownerSession.token, roomId);
      return mutes.some((mute) => String(mute.user_id ?? mute.userId ?? '') === candidate.session.user.id);
    }).toBe(true);

    const mutedRow = page.locator('.contact-page__row').filter({ hasText: candidate.username });
    await mutedRow.getByRole('button', { name: '解除禁言' }).click();
    await mutedRow.getByRole('button', { name: '确认解除' }).click();
    await expect(page.getByText('成员已解除禁言')).toBeVisible();
    await expect.poll(async () => {
      const mutes = await loadMutesViaApi(request, ownerSession.token, roomId);
      return mutes.some((mute) => String(mute.user_id ?? mute.userId ?? '') === candidate.session.user.id);
    }).toBe(false);

    await page.getByLabel('开启全体禁言').uncheck();
    await page.getByRole('button', { name: '保存全体禁言' }).click();
    await expect(page.getByText('全体禁言已关闭')).toBeVisible();
    await expect.poll(async () => {
      const settings = await loadGroupSettingsViaApi(request, ownerSession.token, roomId);
      return settings.global_mute_enabled;
    }).toBe(false);

    await page.getByRole('button', { name: '返回' }).click();
    await page.getByRole('button', { name: /入群审核/ }).click();
    await page.getByLabel('开启入群审核').check();
    await page.getByRole('button', { name: '保存审核设置' }).click();
    await expect(page.getByText('入群审核已开启')).toBeVisible();
    await expect.poll(async () => {
      const settings = await loadGroupSettingsViaApi(request, ownerSession.token, roomId);
      return settings.join_approval_required;
    }).toBe(true);
    for (const [applicant, message] of [
      [approvedApplicant, '希望加入并参与讨论'],
      [rejectedApplicant, '申请加入审核测试'],
    ] as const) {
      const joinRequestResponse = await request.post(`${apiBaseURL}/rooms/${roomId}/join-requests`, {
        headers: authHeaders(applicant.session.token),
        data: { message },
      });
      expect(joinRequestResponse.ok()).toBeTruthy();
    }

    await page.reload();
    const approvedRequestCard = page.locator(`[data-applicant-id="${approvedApplicant.session.user.id}"]`);
    await approvedRequestCard.getByPlaceholder('填写审核备注（可选）').fill('欢迎加入');
    await approvedRequestCard.getByRole('button', { name: '通过' }).click();
    await approvedRequestCard.getByRole('button', { name: '确认通过' }).click();
    await expect(page.getByText('已通过入群申请')).toBeVisible();

    const rejectedRequestCard = page.locator(`[data-applicant-id="${rejectedApplicant.session.user.id}"]`);
    await rejectedRequestCard.getByPlaceholder('填写审核备注（可选）').fill('暂不符合入群条件');
    await rejectedRequestCard.getByRole('button', { name: '拒绝' }).click();
    await rejectedRequestCard.getByRole('button', { name: '确认拒绝' }).click();
    await expect(page.getByText('已拒绝入群申请')).toBeVisible();

    const approvedJoinResponse = await request.post(`${apiBaseURL}/rooms/${roomId}/join`, {
      headers: authHeaders(approvedApplicant.session.token),
    });
    expect(approvedJoinResponse.ok()).toBeTruthy();
    const rejectedJoinResponse = await request.post(`${apiBaseURL}/rooms/${roomId}/join`, {
      headers: authHeaders(rejectedApplicant.session.token),
    });
    expect(rejectedJoinResponse.status()).toBe(403);
    await expect.poll(async () => {
      const members = await loadMembersViaApi(request, ownerSession.token, roomId);
      return {
        approved: members.some((member) => String(member.user_id ?? member.userId ?? '') === approvedApplicant.session.user.id),
        rejected: members.some((member) => String(member.user_id ?? member.userId ?? '') === rejectedApplicant.session.user.id),
      };
    }).toEqual({ approved: true, rejected: false });

    await page.getByRole('button', { name: '返回' }).click();
    await page.getByRole('button', { name: '查看全部成员' }).click();
    const candidateRow = page.locator('.contact-page__row').filter({ hasText: candidate.username });
    await expect(candidateRow).toBeVisible();
    await candidateRow.getByRole('button', { name: '移除' }).click();
    await candidateRow.getByRole('button', { name: '确认' }).click();
    await expect(candidateRow).toHaveCount(0);
    await expect.poll(async () => {
      const members = await loadMembersViaApi(request, ownerSession.token, roomId);
      return members.some((member) => String(member.user_id ?? member.userId ?? '') === candidate.session.user.id);
    }).toBe(false);
  });
});
