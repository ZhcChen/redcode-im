import { appEnv } from '@/config/env';

import { readToken } from './session';

export type WebSocketConnectionStatus =
  | 'connecting'
  | 'connected'
  | 'authenticated'
  | 'disconnected'
  | 'error';

export interface WebSocketServerEvent extends Record<string, unknown> {
  type: string;
}

type WebSocketLike = Pick<WebSocket, 'close' | 'send' | 'readyState'> & {
  onopen: ((event: Event) => void) | null;
  onclose: ((event: CloseEvent) => void) | null;
  onerror: ((event: Event) => void) | null;
  onmessage: ((event: MessageEvent) => void) | null;
};

type WebSocketFactory = (url: string) => WebSocketLike;
type EventListener = (event: WebSocketServerEvent) => void;
type StatusListener = (status: WebSocketConnectionStatus) => void;

interface WebSocketServiceOptions {
  autoReconnect?: boolean;
  factory?: WebSocketFactory;
  maxReconnectAttempts?: number;
}

export class H5WebSocketService {
  private socket: WebSocketLike | null = null;
  private readonly listeners = new Set<EventListener>();
  private readonly statusListeners = new Set<StatusListener>();
  private readonly desiredRooms = new Set<string>();
  private readonly subscribedRooms = new Set<string>();
  private readonly pendingRooms = new Set<string>();
  private readonly factory: WebSocketFactory;
  private readonly autoReconnect: boolean;
  private readonly maxReconnectAttempts: number;
  private reconnectAttempts = 0;
  private reconnectTimer: number | null = null;
  private pingTimer: number | null = null;
  private manualClose = false;
  private authToken: string | null = null;

  status: WebSocketConnectionStatus = 'disconnected';
  connectionId: string | null = null;
  lastError = '';

  constructor(options: WebSocketServiceOptions = {}) {
    this.factory = options.factory ?? ((url) => new WebSocket(url));
    this.autoReconnect = options.autoReconnect ?? true;
    this.maxReconnectAttempts = options.maxReconnectAttempts ?? 5;
  }

  get rooms() {
    return new Set(this.subscribedRooms);
  }

  async connect(token = readToken()): Promise<void> {
    if (this.status === 'connecting' || this.status === 'connected' || this.status === 'authenticated') {
      return;
    }
    if (!token) {
      this.setStatus('error');
      this.lastError = '用户未登录';
      throw new Error(this.lastError);
    }

    this.authToken = token;
    this.manualClose = false;
    this.clearReconnectTimer();
    this.setStatus('connecting');

    this.socket = this.factory(buildWebSocketUrl(appEnv.wsUrl));
    this.socket.onopen = () => {
      this.setStatus('connected');
      this.send({ type: 'auth', token });
      this.startPing();
    };
    this.socket.onmessage = (event) => {
      this.handleFrame(event.data).catch((error) => {
        this.lastError = error instanceof Error ? error.message : 'WebSocket 消息处理失败';
        this.setStatus('error');
      });
    };
    this.socket.onerror = () => {
      this.lastError = 'WebSocket 连接异常';
      this.setStatus('error');
    };
    this.socket.onclose = () => {
      this.stopPing();
      this.socket = null;
      this.subscribedRooms.clear();
      this.pendingRooms.clear();
      this.connectionId = null;
      if (this.manualClose) {
        this.setStatus('disconnected');
        return;
      }
      this.setStatus('disconnected');
      this.scheduleReconnect();
    };
  }

  disconnect(): void {
    this.manualClose = true;
    this.clearReconnectTimer();
    this.stopPing();
    this.desiredRooms.clear();
    this.subscribedRooms.clear();
    this.pendingRooms.clear();
    this.connectionId = null;
    this.socket?.close();
    this.socket = null;
    this.setStatus('disconnected');
  }

  ensureRoomsSubscribed(roomIds: Iterable<string>, options: { pruneMissing?: boolean } = {}): void {
    const targets = new Set(
      [...roomIds]
        .map((roomId) => roomId.trim())
        .filter(Boolean),
    );

    if (options.pruneMissing) {
      for (const roomId of this.desiredRooms) {
        if (!targets.has(roomId)) {
          this.desiredRooms.delete(roomId);
          this.subscribedRooms.delete(roomId);
          this.pendingRooms.delete(roomId);
          this.send({ type: 'leave', room_id: roomId });
        }
      }
    }

    for (const roomId of targets) {
      this.desiredRooms.add(roomId);
      if (this.status === 'authenticated' && !this.subscribedRooms.has(roomId) && !this.pendingRooms.has(roomId)) {
        this.pendingRooms.add(roomId);
        this.send({ type: 'join', room_id: roomId });
      }
    }
  }

  setTyping(roomId: string, isTyping: boolean): void {
    if (!roomId || this.status !== 'authenticated' || !this.subscribedRooms.has(roomId)) {
      return;
    }
    this.send({ type: 'typing', room_id: roomId, is_typing: isTyping });
  }

  onEvent(listener: EventListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  onStatus(listener: StatusListener): () => void {
    this.statusListeners.add(listener);
    return () => this.statusListeners.delete(listener);
  }

  emitForTests(event: WebSocketServerEvent): void {
    this.dispatch(event);
  }

  private async handleFrame(data: unknown): Promise<void> {
    if (typeof data !== 'string') {
      return;
    }
    const event = JSON.parse(data) as WebSocketServerEvent;
    if (!event.type) return;

    if (event.type === 'authed') {
      this.connectionId = stringOrNull(event.conn_id);
      this.reconnectAttempts = 0;
      this.setStatus('authenticated');
      this.ensureRoomsSubscribed(this.desiredRooms);
    }
    if (event.type === 'joined') {
      const roomId = stringOrNull(event.room_id);
      if (roomId) {
        this.pendingRooms.delete(roomId);
        this.subscribedRooms.add(roomId);
      }
    }
    if (event.type === 'left') {
      const roomId = stringOrNull(event.room_id);
      if (roomId) {
        this.pendingRooms.delete(roomId);
        this.subscribedRooms.delete(roomId);
      }
    }
    if (event.type === 'error') {
      this.lastError = String(event.message ?? 'WebSocket 服务端错误');
      this.setStatus('error');
    }

    this.dispatch(event);
  }

  private dispatch(event: WebSocketServerEvent): void {
    this.listeners.forEach((listener) => listener(event));
  }

  private send(payload: Record<string, unknown>): void {
    if (!this.socket || this.socket.readyState !== 1) {
      return;
    }
    this.socket.send(JSON.stringify(payload));
  }

  private setStatus(status: WebSocketConnectionStatus): void {
    if (this.status === status) return;
    this.status = status;
    this.statusListeners.forEach((listener) => listener(status));
  }

  private scheduleReconnect(): void {
    if (!this.autoReconnect || !this.authToken || this.reconnectAttempts >= this.maxReconnectAttempts) {
      return;
    }
    this.reconnectAttempts += 1;
    const delay = Math.min(1000 * this.reconnectAttempts, 5000);
    this.reconnectTimer = window.setTimeout(() => {
      void this.connect(this.authToken);
    }, delay);
  }

  private startPing(): void {
    this.stopPing();
    this.pingTimer = window.setInterval(() => {
      this.send({ type: 'ping' });
    }, 30_000);
  }

  private stopPing(): void {
    if (this.pingTimer !== null) {
      window.clearInterval(this.pingTimer);
      this.pingTimer = null;
    }
  }

  private clearReconnectTimer(): void {
    if (this.reconnectTimer !== null) {
      window.clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }
}

export const webSocketService = new H5WebSocketService();

const buildWebSocketUrl = (rawUrl: string) => {
  const url = new URL(rawUrl, window.location.href);
  if (url.protocol === 'http:') url.protocol = 'ws:';
  if (url.protocol === 'https:') url.protocol = 'wss:';
  url.searchParams.set('format', 'json');
  return url.toString();
};

const stringOrNull = (value: unknown) => {
  if (value === null || value === undefined || value === '') return null;
  return String(value);
};
