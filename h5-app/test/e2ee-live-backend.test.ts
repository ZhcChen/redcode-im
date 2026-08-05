import { webcrypto } from 'node:crypto';
import { spawn } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { resolve } from 'node:path';

import { IDBFactory } from 'fake-indexeddb';
import { describe, expect, it, onTestFinished, vi } from 'vitest';
import WebSocket from 'ws';
import initCore from '@/e2ee/core-wasm/redcode_e2ee_core.js';

const enabled = process.env.H5_APP_E2EE_LIVE_ENABLED === 'true';
const apiBaseUrl = process.env.H5_APP_API_BASE_URL || 'http://127.0.0.1:8010';
const sessionStorageKey = 'redcode-h5-session';
// 共享环境清理依据：账号名前缀带 run ID，供
// tests/scripts/cleanup-e2ee-live-fixtures.sh 定向清理。
const runId = (process.env.E2EE_LIVE_RUN_ID || 'manual').replace(/[^a-zA-Z0-9_-]/g, '');

interface LiveSession {
  token: string;
  user: { id: string; username: string };
}

const request = async <T>(path: string, init: RequestInit = {}, token?: string): Promise<T> => {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    ...init,
    headers: {
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
  });
  const payload = await response.json().catch(() => null) as T;
  if (!response.ok) {
    throw new Error(`live API ${init.method ?? 'GET'} ${path} failed (${response.status})`);
  }
  return payload;
};

const register = async (prefix: string): Promise<LiveSession> => {
  const suffix = `${Date.now().toString(36).slice(-6)}${Math.random().toString(16).slice(2, 6)}`;
  const runFragment = runId.slice(0, Math.max(0, 20 - prefix.length - suffix.length));
  const username = `${prefix}${runFragment}${suffix}`;
  const password = `E2ee-${suffix}`;
  await request('/auth/register', {
    method: 'POST',
    body: JSON.stringify({ username, password, nickname: username }),
  });
  return request<LiveSession>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  });
};

const useSession = (session: LiveSession) => {
  window.localStorage.setItem(sessionStorageKey, JSON.stringify(session));
};

describe.skipIf(!enabled)('H5 E2EE live backend', () => {
  it('exchanges ciphertext bidirectionally in a private room and across Android/H5', async () => {
    vi.stubGlobal('indexedDB', new IDBFactory());
    vi.stubGlobal('crypto', webcrypto as unknown as Crypto);

    const general = await request<{
      message_runtime?: { server_storage_mode?: string; content_audit_mode?: string };
    }>('/settings/general');
    expect(general.message_runtime).toMatchObject({
      server_storage_mode: 'persist',
      content_audit_mode: 'e2ee',
    });

    const alice = await register('e2eea');
    const bob = await register('e2eeb');
    const androidAlice = await register('e2eeand');
    const h5CrossBob = await register('e2eeh');
    const { friendService } = await import('@/services/friend-service');
    const wasm = await readFile(resolve(process.cwd(), 'src/e2ee/core-wasm/redcode_e2ee_core_bg.wasm'));
    await initCore({ module_or_path: wasm });
    const { e2eeDeviceLifecycle } = await import('@/e2ee/device-lifecycle');
    const { e2eeDirectMessageCoordinator } = await import('@/e2ee/direct-message-coordinator');
    const { mapWebSocketMessage, messageService } = await import('@/services/message-service');
    const { H5WebSocketService } = await import('@/services/websocket-service');

    useSession(alice);
    const friendMarker = `u5-friend-${crypto.randomUUID()}`;
    const friendRequest = await friendService.sendFriendRequest(bob.user.id, friendMarker);
    useSession(bob);
    await friendService.respondFriendRequest(friendRequest.id, 'accept');
    useSession(alice);
    const chat = await friendService.ensurePrivateChat(bob.user.id);
    expect(chat.roomType).toBe('private');
    useSession(androidAlice);
    const crossFriendRequest = await friendService.sendFriendRequest(h5CrossBob.user.id, '');
    useSession(h5CrossBob);
    await friendService.respondFriendRequest(crossFriendRequest.id, 'accept');
    useSession(androidAlice);
    const crossChat = await friendService.ensurePrivateChat(h5CrossBob.user.id);
    expect(crossChat.roomType).toBe('private');

    useSession(alice);
    await e2eeDeviceLifecycle.ensureReady(alice.user.id, 'H5 live Alice');
    useSession(bob);
    await e2eeDeviceLifecycle.ensureReady(bob.user.id, 'H5 live Bob');
    useSession(h5CrossBob);
    await e2eeDeviceLifecycle.ensureReady(h5CrossBob.user.id, 'H5 cross Bob');
    const aliceSocket = createSocket(H5WebSocketService);
    const bobSocket = new H5WebSocketService({
      autoReconnect: false,
      factory: (url) => new WebSocket(url) as unknown as globalThis.WebSocket,
    });
    onTestFinished(() => aliceSocket.disconnect());
    onTestFinished(() => bobSocket.disconnect());
    const aliceAuthenticated = waitForStatus(aliceSocket, 'authenticated');
    const authenticated = waitForStatus(bobSocket, 'authenticated');
    await aliceSocket.connect(alice.token);
    await bobSocket.connect(bob.token);
    await aliceAuthenticated;
    await authenticated;
    const aliceJoined = waitForEvent(aliceSocket, (event) => event.type === 'joined' && event.room_id === chat.roomId);
    const joined = waitForEvent(bobSocket, (event) => event.type === 'joined' && event.room_id === chat.roomId);
    aliceSocket.ensureRoomsSubscribed([chat.roomId]);
    bobSocket.ensureRoomsSubscribed([chat.roomId]);
    await aliceJoined;
    await joined;

    const aliceMarker = `u5-alice-${crypto.randomUUID()}`;
    useSession(alice);
    const aliceWebSocketMessage = waitForEvent(
      bobSocket,
      (event) => event.type === 'message' && event.room_id === chat.roomId,
    );
    const aliceResponse = await e2eeDirectMessageCoordinator.sendText({
      accountId: alice.user.id,
      deviceLabel: 'H5 live Alice',
      roomId: chat.roomId,
      peerUserId: bob.user.id,
      text: aliceMarker,
    });
    expect(JSON.stringify(aliceResponse)).not.toContain(aliceMarker);
    const aliceWebSocketEvent = await aliceWebSocketMessage;
    expect(JSON.stringify(aliceWebSocketEvent)).not.toContain(aliceMarker);
    expect(aliceWebSocketEvent).toMatchObject({
      content: '[加密消息]',
      encrypted_content: expect.any(String),
      encryption_metadata: expect.objectContaining({
        protocol: 'mls', version: 1, content_type: 'application',
      }),
    });

    useSession(bob);
    const aliceVisibleFromWebSocket = await messageService.resolveEncryptedMessage(
      mapWebSocketMessage(aliceWebSocketEvent),
      bob.user.id,
    );
    expect(aliceVisibleFromWebSocket.content).toBe(aliceMarker);
    const bobHistory = await messageService.loadMessages(chat.roomId, { limit: 20 }, bob.user.id);
    expect(bobHistory.some((message) => message.id === aliceVisibleFromWebSocket.id && message.content === aliceMarker)).toBe(true);

    const bobMarker = `u5-bob-${crypto.randomUUID()}`;
    const bobWebSocketMessage = waitForEvent(
      aliceSocket,
      (event) => event.type === 'message' && event.room_id === chat.roomId && event.sender_id === bob.user.id,
    );
    const bobResponse = await e2eeDirectMessageCoordinator.sendText({
      accountId: bob.user.id,
      deviceLabel: 'H5 live Bob',
      roomId: chat.roomId,
      peerUserId: alice.user.id,
      text: bobMarker,
    });
    expect(JSON.stringify(bobResponse)).not.toContain(bobMarker);
    const bobWebSocketEvent = await bobWebSocketMessage;
    expect(JSON.stringify(bobWebSocketEvent)).not.toContain(bobMarker);

    useSession(alice);
    const bobVisibleFromWebSocket = await messageService.resolveEncryptedMessage(
      mapWebSocketMessage(bobWebSocketEvent),
      alice.user.id,
    );
    expect(bobVisibleFromWebSocket.content).toBe(bobMarker);
    const aliceHistory = await messageService.loadMessages(chat.roomId, { limit: 20 }, alice.user.id);
    expect(aliceHistory.some((message) => message.id === bobVisibleFromWebSocket.id && message.content === bobMarker)).toBe(true);
    const rawHistory = await request<Array<Record<string, unknown>>>(
      `/rooms/${chat.roomId}/messages?limit=20`,
      {},
      alice.token,
    );
    const serialized = JSON.stringify(rawHistory);
    expect(serialized).not.toContain(friendMarker);
    expect(serialized).not.toContain(aliceMarker);
    expect(serialized).not.toContain(bobMarker);
    expect(rawHistory).toEqual(expect.arrayContaining([
      expect.objectContaining({ encrypted_content: expect.any(String) }),
      expect.objectContaining({ encrypted_content: expect.any(String) }),
    ]));

    const androidMarker = `u5-android-${crypto.randomUUID()}`;
    const h5Marker = `u5-h5-${crypto.randomUUID()}`;
    const crossBobSocket = new H5WebSocketService({
      autoReconnect: false,
      factory: (url) => new WebSocket(url) as unknown as globalThis.WebSocket,
    });
    onTestFinished(() => crossBobSocket.disconnect());
    const crossAuthenticated = waitForStatus(crossBobSocket, 'authenticated');
    await crossBobSocket.connect(h5CrossBob.token);
    await crossAuthenticated;
    useSession(h5CrossBob);
    const crossJoined = waitForEvent(
      crossBobSocket,
      (event) => event.type === 'joined' && event.room_id === crossChat.roomId,
    );
    crossBobSocket.ensureRoomsSubscribed([crossChat.roomId]);
    await crossJoined;
    const androidWebSocketMessage = waitForEvent(
      crossBobSocket,
      (event) => event.type === 'message' && event.room_id === crossChat.roomId,
      30_000,
    );
    const coordination = await createCoordinationServer({
      token: androidAlice.token,
      account_id: androidAlice.user.id,
      peer_user_id: h5CrossBob.user.id,
      room_id: crossChat.roomId,
      android_marker: androidMarker,
      h5_marker: h5Marker,
      api_base_url: apiBaseUrl,
    });
    onTestFinished(() => coordination.close());
    const android = spawnAndroidClient(coordination.url, coordination.secret);
    onTestFinished(() => {
      android.kill();
    });

    const androidSent = await coordination.waitFor('android-sent');
    const androidMessageId = requiredString(androidSent, 'message_id');
    const androidWebSocketEvent = await androidWebSocketMessage;
    expect(requiredString(androidWebSocketEvent, 'id')).toBe(androidMessageId);
    useSession(h5CrossBob);
    const androidVisibleFromWebSocket = await messageService.resolveEncryptedMessage(
      mapWebSocketMessage(androidWebSocketEvent),
      h5CrossBob.user.id,
    );
    expect(androidVisibleFromWebSocket.content).toBe(androidMarker);
    const androidHistory = await messageService.loadMessages(crossChat.roomId, { limit: 20 }, h5CrossBob.user.id);
    expect(androidHistory.some((message) => (
      message.id === androidMessageId && message.content === androidMarker
    ))).toBe(true);

    const h5Response = await e2eeDirectMessageCoordinator.sendText({
      accountId: h5CrossBob.user.id,
      deviceLabel: 'H5 cross Bob',
      roomId: crossChat.roomId,
      peerUserId: androidAlice.user.id,
      text: h5Marker,
    });
    const h5MessageId = responseMessageId(h5Response);
    coordination.publish('h5-sent', { message_id: h5MessageId });
    const androidReceived = await coordination.waitFor('android-received');
    expect(requiredString(androidReceived, 'message_id')).toBe(h5MessageId);

    const exitCode = await android.exitCode;
    expect(exitCode, 'Android 跨端联调进程失败').toBe(0);
    const crossRawHistory = await request<Array<Record<string, unknown>>>(
      `/rooms/${crossChat.roomId}/messages?limit=20`,
      {},
      androidAlice.token,
    );
    const crossSerialized = JSON.stringify(crossRawHistory);
    expect(crossSerialized).not.toContain(androidMarker);
    expect(crossSerialized).not.toContain(h5Marker);
    expect(crossRawHistory).toEqual(expect.arrayContaining([
      expect.objectContaining({ id: androidMessageId, encrypted_content: expect.any(String) }),
      expect.objectContaining({ id: h5MessageId, encrypted_content: expect.any(String) }),
    ]));
  }, 60_000);

  it('establishes consecutive new private rooms and recovers after key package top-up', async () => {
    vi.stubGlobal('indexedDB', new IDBFactory());
    vi.stubGlobal('crypto', webcrypto as unknown as Crypto);

    const general = await request<{
      message_runtime?: { server_storage_mode?: string; content_audit_mode?: string };
    }>('/settings/general');
    expect(general.message_runtime).toMatchObject({
      server_storage_mode: 'persist',
      content_audit_mode: 'e2ee',
    });

    const alice = await register('e2eea');
    const carol = await register('e2eec');
    const dave = await register('e2eed');
    const wasm = await readFile(resolve(process.cwd(), 'src/e2ee/core-wasm/redcode_e2ee_core_bg.wasm'));
    await initCore({ module_or_path: wasm });
    const { e2eeDeviceLifecycle } = await import('@/e2ee/device-lifecycle');
    const { e2eeDirectMessageCoordinator } = await import('@/e2ee/direct-message-coordinator');
    const { messageService } = await import('@/services/message-service');
    const { friendService } = await import('@/services/friend-service');

    const link = async (left: LiveSession, right: LiveSession, marker: string) => {
      useSession(left);
      const requestId = await friendService.sendFriendRequest(right.user.id, marker);
      useSession(right);
      await friendService.respondFriendRequest(requestId.id, 'accept');
      useSession(left);
      return friendService.ensurePrivateChat(right.user.id);
    };
    const roomAliceCarol = await link(alice, carol, `u2-ac-${crypto.randomUUID()}`);
    const roomAliceDave = await link(alice, dave, `u2-ad-${crypto.randomUUID()}`);
    const roomCarolDave = await link(carol, dave, `u2-cd-${crypto.randomUUID()}`);

    useSession(alice);
    await e2eeDeviceLifecycle.ensureReady(alice.user.id, 'H5 live Alice');
    useSession(carol);
    await e2eeDeviceLifecycle.ensureReady(carol.user.id, 'H5 live Carol');
    useSession(dave);
    await e2eeDeviceLifecycle.ensureReady(dave.user.id, 'H5 live Dave');

    // 同一 Alice 设备连续创建两个新私聊：分别消费 Carol、Dave 各自唯一的 KeyPackage。
    const firstMarker = `u2-first-${crypto.randomUUID()}`;
    useSession(alice);
    const firstResponse = await e2eeDirectMessageCoordinator.sendText({
      accountId: alice.user.id,
      deviceLabel: 'H5 live Alice',
      roomId: roomAliceCarol.roomId,
      peerUserId: carol.user.id,
      text: firstMarker,
    });
    expect(JSON.stringify(firstResponse)).not.toContain(firstMarker);
    const secondMarker = `u2-second-${crypto.randomUUID()}`;
    const secondResponse = await e2eeDirectMessageCoordinator.sendText({
      accountId: alice.user.id,
      deviceLabel: 'H5 live Alice',
      roomId: roomAliceDave.roomId,
      peerUserId: dave.user.id,
      text: secondMarker,
    });
    expect(JSON.stringify(secondResponse)).not.toContain(secondMarker);

    // Dave 唯一 KeyPackage 已被第二个会话消费，Carol 再发起第三个会话必须明确失败，
    // 且服务端不能进入半提交状态（房间 epoch 仍为 0）。
    const thirdMarker = `u2-third-${crypto.randomUUID()}`;
    useSession(carol);
    await expect(e2eeDirectMessageCoordinator.sendText({
      accountId: carol.user.id,
      deviceLabel: 'H5 live Carol',
      roomId: roomCarolDave.roomId,
      peerUserId: dave.user.id,
      text: thirdMarker,
    })).rejects.toThrow();
    const failedEpoch = await request<{ active_epoch?: number }>(
      `/rooms/${roomCarolDave.roomId}/e2ee/epoch`,
      {},
      carol.token,
    );
    expect(failedEpoch.active_epoch).toBe(0);

    // Dave 低水位补充后，同一 Dave 设备可加入第三个新会话并解密 Carol 的消息。
    useSession(dave);
    const replenished = await e2eeDeviceLifecycle.topUpKeyPackages(dave.user.id);
    expect(replenished.replenished).toBeGreaterThan(0);
    useSession(carol);
    const thirdResponse = await e2eeDirectMessageCoordinator.sendText({
      accountId: carol.user.id,
      deviceLabel: 'H5 live Carol',
      roomId: roomCarolDave.roomId,
      peerUserId: dave.user.id,
      text: thirdMarker,
    });
    expect(JSON.stringify(thirdResponse)).not.toContain(thirdMarker);

    useSession(dave);
    const daveHistory = await messageService.loadMessages(
      roomCarolDave.roomId,
      { limit: 20 },
      dave.user.id,
    );
    expect(daveHistory.some((message) => message.content === thirdMarker)).toBe(true);

    const rawHistory = await request<Array<Record<string, unknown>>>(
      `/rooms/${roomCarolDave.roomId}/messages?limit=20`,
      {},
      carol.token,
    );
    const serialized = JSON.stringify(rawHistory);
    expect(serialized).not.toContain(firstMarker);
    expect(serialized).not.toContain(secondMarker);
    expect(serialized).not.toContain(thirdMarker);
  }, 90_000);
});

interface CoordinationServer {
  url: string;
  secret: string;
  close(): Promise<void>;
  publish(step: string, payload: Record<string, string>): void;
  waitFor(step: string): Promise<Record<string, string>>;
}

const createCoordinationServer = async (
  fixture: Record<string, string>,
): Promise<CoordinationServer> => {
  const secret = crypto.randomUUID();
  const steps = new Map<string, Record<string, string>>();
  const waiters = new Map<string, Array<(payload: Record<string, string>) => void>>();
  const publish = (step: string, payload: Record<string, string>) => {
    steps.set(step, payload);
    waiters.get(step)?.splice(0).forEach((resolve) => resolve(payload));
  };
  const waitFor = (step: string) => {
    const existing = steps.get(step);
    if (existing) return Promise.resolve(existing);
    return new Promise<Record<string, string>>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`Coordination timeout: ${step}`)), 30_000);
      const wrapped = (payload: Record<string, string>) => {
        clearTimeout(timer);
        resolve(payload);
      };
      waiters.set(step, [...(waiters.get(step) ?? []), wrapped]);
    });
  };
  const server = createServer(async (request, response) => {
    if (request.headers.authorization !== `Bearer ${secret}`) {
      response.writeHead(401).end();
      return;
    }
    const path = new URL(request.url ?? '/', 'http://127.0.0.1').pathname.slice(1);
    if (request.method === 'GET' && path === 'fixture') {
      sendJson(response, fixture);
      return;
    }
    if (request.method === 'GET') {
      const payload = steps.get(path);
      if (!payload) {
        response.writeHead(204).end();
        return;
      }
      sendJson(response, payload);
      return;
    }
    if (request.method === 'POST') {
      const payload = await readJsonBody(request);
      publish(path, payload);
      sendJson(response, { ok: 'true' });
      return;
    }
    response.writeHead(404).end();
  });
  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = server.address();
  if (!address || typeof address === 'string') throw new Error('Coordination server address unavailable');
  return {
    url: `http://127.0.0.1:${address.port}`,
    secret,
    publish,
    waitFor,
    close: () => new Promise<void>((resolve, reject) => (
      server.close((error) => error ? reject(error) : resolve())
    )),
  };
};

const spawnAndroidClient = (coordinationUrl: string, secret: string) => {
  const child = spawn('./gradlew', [
    'testDebugUnitTest',
    '--rerun-tasks',
    '--tests',
    'com.redcode.im.androidapp.live.AndroidE2eeCrossClientLiveTest',
  ], {
    cwd: resolve(process.cwd(), '../android-app'),
    env: {
      ...process.env,
      RED_CODE_ANDROID_E2EE_LIVE: '1',
      E2EE_COORDINATION_URL: coordinationUrl,
      E2EE_COORDINATION_SECRET: secret,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let output = '';
  child.stdout.on('data', (chunk) => { output = `${output}${chunk}`.slice(-8_000); });
  child.stderr.on('data', (chunk) => { output = `${output}${chunk}`.slice(-8_000); });
  const exitCode = new Promise<number>((resolve, reject) => {
    child.once('error', reject);
    child.once('exit', (code) => {
      if (code !== 0) {
        const sanitized = output
          .replaceAll(secret, '[REDACTED]')
          .replace(/u5-(?:android|h5)-[0-9a-f-]+/gi, '[REDACTED_MARKER]');
        process.stderr.write(sanitized);
      }
      resolve(code ?? 1);
    });
  });
  return { exitCode, kill: () => child.kill('SIGTERM') };
};

const sendJson = (response: import('node:http').ServerResponse, payload: Record<string, string>) => {
  response.writeHead(200, { 'Content-Type': 'application/json' });
  response.end(JSON.stringify(payload));
};

const readJsonBody = async (request: import('node:http').IncomingMessage) => {
  const chunks: Buffer[] = [];
  for await (const chunk of request) chunks.push(Buffer.from(chunk));
  const payload = JSON.parse(Buffer.concat(chunks).toString('utf8')) as Record<string, unknown>;
  return Object.fromEntries(Object.entries(payload).map(([key, value]) => [key, String(value)]));
};

const requiredString = (payload: Record<string, unknown>, key: string) => {
  const value = payload[key];
  if (typeof value !== 'string' || !value) throw new Error(`Missing coordination field: ${key}`);
  return value;
};

const responseMessageId = (response: Record<string, unknown>) => {
  const message = response.message;
  if (!message || typeof message !== 'object') throw new Error('Missing encrypted response message');
  return requiredString(message as Record<string, unknown>, 'id');
};

const createSocket = (SocketService: typeof import('@/services/websocket-service').H5WebSocketService) => (
  new SocketService({
    autoReconnect: false,
    factory: (url) => new WebSocket(url) as unknown as globalThis.WebSocket,
  })
);

const waitForStatus = async (
  socket: { status: string; onStatus(listener: (status: string) => void): () => void },
  expected: string,
) => {
  if (socket.status === expected) return;
  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => {
      unsubscribe();
      reject(new Error(`WebSocket status timeout: ${expected}`));
    }, 5_000);
    const unsubscribe = socket.onStatus((status) => {
      if (status !== expected) return;
      clearTimeout(timer);
      unsubscribe();
      resolve();
    });
  });
};

const waitForEvent = async <T extends Record<string, unknown>>(
  socket: { onEvent(listener: (event: T) => void): () => void },
  predicate: (event: T) => boolean,
  timeoutMs = 5_000,
) => new Promise<T>((resolve, reject) => {
  const timer = setTimeout(() => {
    unsubscribe();
    reject(new Error('WebSocket event timeout'));
  }, timeoutMs);
  const unsubscribe = socket.onEvent((event) => {
    if (!predicate(event)) return;
    clearTimeout(timer);
    unsubscribe();
    resolve(event);
  });
});
