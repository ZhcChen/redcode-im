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
  const suffix = `${Date.now()}${Math.random().toString(16).slice(2, 8)}`;
  const username = `${prefix}${suffix}`.slice(0, 20);
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
  it('exchanges ciphertext bidirectionally in a private room and across Flutter/H5', async () => {
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
    const flutterAlice = await register('e2eef');
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
    useSession(flutterAlice);
    const crossFriendRequest = await friendService.sendFriendRequest(h5CrossBob.user.id, '');
    useSession(h5CrossBob);
    await friendService.respondFriendRequest(crossFriendRequest.id, 'accept');
    useSession(flutterAlice);
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

    const flutterMarker = `u5-flutter-${crypto.randomUUID()}`;
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
    const flutterWebSocketMessage = waitForEvent(
      crossBobSocket,
      (event) => event.type === 'message' && event.room_id === crossChat.roomId,
      30_000,
    );
    const coordination = await createCoordinationServer({
      token: flutterAlice.token,
      account_id: flutterAlice.user.id,
      username: flutterAlice.user.username,
      peer_user_id: h5CrossBob.user.id,
      room_id: crossChat.roomId,
      flutter_marker: flutterMarker,
      h5_marker: h5Marker,
    });
    onTestFinished(() => coordination.close());
    const flutter = spawnFlutterClient(coordination.url, coordination.secret);
    onTestFinished(() => {
      flutter.kill();
    });

    const flutterSent = await coordination.waitFor('flutter-sent');
    const flutterMessageId = requiredString(flutterSent, 'message_id');
    const flutterWebSocketEvent = await flutterWebSocketMessage;
    expect(requiredString(flutterWebSocketEvent, 'id')).toBe(flutterMessageId);
    useSession(h5CrossBob);
    const flutterVisibleFromWebSocket = await messageService.resolveEncryptedMessage(
      mapWebSocketMessage(flutterWebSocketEvent),
      h5CrossBob.user.id,
    );
    expect(flutterVisibleFromWebSocket.content).toBe(flutterMarker);
    const flutterHistory = await messageService.loadMessages(crossChat.roomId, { limit: 20 }, h5CrossBob.user.id);
    expect(flutterHistory.some((message) => (
      message.id === flutterMessageId && message.content === flutterMarker
    ))).toBe(true);

    const h5Response = await e2eeDirectMessageCoordinator.sendText({
      accountId: h5CrossBob.user.id,
      deviceLabel: 'H5 cross Bob',
      roomId: crossChat.roomId,
      peerUserId: flutterAlice.user.id,
      text: h5Marker,
    });
    const h5MessageId = responseMessageId(h5Response);
    coordination.publish('h5-sent', { message_id: h5MessageId });
    const flutterReceived = await coordination.waitFor('flutter-received');
    expect(requiredString(flutterReceived, 'message_id')).toBe(h5MessageId);

    const exitCode = await flutter.exitCode;
    expect(exitCode, 'Flutter 跨端联调进程失败').toBe(0);
    const crossRawHistory = await request<Array<Record<string, unknown>>>(
      `/rooms/${crossChat.roomId}/messages?limit=20`,
      {},
      flutterAlice.token,
    );
    const crossSerialized = JSON.stringify(crossRawHistory);
    expect(crossSerialized).not.toContain(flutterMarker);
    expect(crossSerialized).not.toContain(h5Marker);
    expect(crossRawHistory).toEqual(expect.arrayContaining([
      expect.objectContaining({ id: flutterMessageId, encrypted_content: expect.any(String) }),
      expect.objectContaining({ id: h5MessageId, encrypted_content: expect.any(String) }),
    ]));
  }, 60_000);
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

const spawnFlutterClient = (coordinationUrl: string, secret: string) => {
  const child = spawn('flutter', [
    'test',
    'test/e2ee_cross_client_live_test.dart',
    '--dart-define=ENABLE_E2EE_CROSS_CLIENT_LIVE=true',
    `--dart-define=API_BASE_URL=${apiBaseUrl}`,
  ], {
    cwd: resolve(process.cwd(), '../app'),
    env: {
      ...process.env,
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
          .replace(/u5-(?:flutter|h5)-[0-9a-f-]+/gi, '[REDACTED_MARKER]');
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
