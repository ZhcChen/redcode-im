import { webcrypto } from 'node:crypto';
import { readFile } from 'node:fs/promises';
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
  it('exchanges ciphertext bidirectionally in a private room', async () => {
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

    useSession(alice);
    await e2eeDeviceLifecycle.ensureReady(alice.user.id, 'H5 live Alice');
    useSession(bob);
    await e2eeDeviceLifecycle.ensureReady(bob.user.id, 'H5 live Bob');
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
  }, 20_000);
});

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
) => new Promise<T>((resolve, reject) => {
  const timer = setTimeout(() => {
    unsubscribe();
    reject(new Error('WebSocket event timeout'));
  }, 5_000);
  const unsubscribe = socket.onEvent((event) => {
    if (!predicate(event)) return;
    clearTimeout(timer);
    unsubscribe();
    resolve(event);
  });
});
