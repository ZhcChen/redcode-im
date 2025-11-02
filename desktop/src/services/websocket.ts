import { apiConfig } from '@/api/config';

export type ServerEvent =
  | { type: 'authed'; user_id: string; conn_id: string }
  | { type: 'joined'; room_id: string }
  | { type: 'left'; room_id: string }
  | {
      type: 'message';
      room_id: string;
      message_id: string;
      sender_id: string;
      sender_username?: string;
      sender_nickname?: string;
      sender_avatar_url?: string;
      content: string;
      message_type: string;
      timestamp: string;
      quoted_message?: any;
      forward_message?: any;
    }
  | { type: 'friend_request_update'; pending_count: number }
  | {
      type: 'room_created';
      room_id: string;
      room_name: string;
      room_type: string;
      initiator_id: string;
      owner_id: string;
      description?: string | null;
      avatar_url?: string | null;
      created_at?: string | null;
    }
  | { type: 'message_read'; room_id: string; message_id: string; reader_id: string; read_at: string }
  | { type: 'message_update'; room_id: string; message_id: string; is_deleted: boolean; deleted_at?: string | null }
  | { type: 'pin_update'; room_id: string; message_id: string; is_pinned: boolean; pinned_at?: string | null; pinned_by?: string | null }
  | { type: 'error'; message?: string }
  | { type: 'pong' }
  | { type: string; [key: string]: any };

type EventHandler = (event: ServerEvent) => void | Promise<void>;

const DEFAULT_RECONNECT_DELAY = 5000;
const PING_INTERVAL = 30000;

class DesktopWebSocketClient {
  private socket: WebSocket | null = null;
  private token: string | null = null;
  private shouldReconnect = false;
  private reconnectTimer: number | null = null;
  private pingTimer: number | null = null;
  private isAuthed = false;
  private desiredRooms = new Set<string>();
  private joinedRooms = new Set<string>();
  private handlers = new Set<EventHandler>();

  connect(token: string) {
    this.token = token;
    this.shouldReconnect = true;
    this.openSocket();
  }

  disconnect() {
    this.shouldReconnect = false;
    this.clearTimers();
    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }
    this.isAuthed = false;
    this.joinedRooms.clear();
  }

  updateDesiredRooms(roomIds: string[]) {
    const next = new Set(roomIds);
    this.desiredRooms = next;
    if (this.isAuthed) {
      this.syncRooms();
    }
  }

  joinRoom(roomId: string) {
    this.desiredRooms.add(roomId);
    if (this.isAuthed && !this.joinedRooms.has(roomId)) {
      this.send({ type: 'join', room_id: roomId });
    }
  }

  leaveRoom(roomId: string) {
    this.desiredRooms.delete(roomId);
    if (this.isAuthed && this.joinedRooms.has(roomId)) {
      this.send({ type: 'leave', room_id: roomId });
      this.joinedRooms.delete(roomId);
    }
  }

  onEvent(handler: EventHandler) {
    this.handlers.add(handler);
  }

  offEvent(handler: EventHandler) {
    this.handlers.delete(handler);
  }

  private openSocket() {
    if (!this.token) {
      return;
    }
    this.clearTimers();
    if (this.socket) {
      this.socket.close();
    }

    const url = new URL(apiConfig.WS_URL);
    if (!url.searchParams.has('format')) {
      url.searchParams.set('format', 'json');
    }

    try {
      this.socket = new WebSocket(url.toString());
    } catch (error) {
      this.scheduleReconnect();
      return;
    }

    this.socket.onopen = () => {
      this.isAuthed = false;
      this.send({ type: 'auth', token: this.token });
      this.startPing();
    };

    this.socket.onmessage = (event) => {
      this.handleMessage(event.data);
    };

    this.socket.onerror = () => {
      if (this.shouldReconnect) {
        this.scheduleReconnect();
      }
    };

    this.socket.onclose = () => {
      this.isAuthed = false;
      this.joinedRooms.clear();
      if (this.shouldReconnect) {
        this.scheduleReconnect();
      }
    };
  }

  private handleMessage(data: string | ArrayBuffer) {
    let payload: ServerEvent;
    try {
      if (typeof data === 'string') {
        payload = JSON.parse(data);
      } else {
        const decoded = new TextDecoder().decode(data);
        payload = JSON.parse(decoded);
      }
    } catch (error) {
      console.warn('WebSocket payload parse error', error);
      return;
    }

    if (payload.type === 'authed') {
      this.isAuthed = true;
      this.syncRooms();
    }

    if (payload.type === 'joined' && payload.room_id) {
      this.joinedRooms.add(payload.room_id);
    }

    if (payload.type === 'left' && payload.room_id) {
      this.joinedRooms.delete(payload.room_id);
    }

    this.handlers.forEach((handler) => {
      try {
        handler(payload);
      } catch (error) {
        console.warn('WebSocket event handler error', error);
      }
    });
  }

  private send(message: Record<string, unknown>) {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      return;
    }
    try {
      this.socket.send(JSON.stringify(message));
    } catch (error) {
      console.warn('WebSocket send error', error);
    }
  }

  private syncRooms() {
    this.desiredRooms.forEach((roomId) => {
      if (!this.joinedRooms.has(roomId)) {
        this.send({ type: 'join', room_id: roomId });
      }
    });

    this.joinedRooms.forEach((roomId) => {
      if (!this.desiredRooms.has(roomId)) {
        this.send({ type: 'leave', room_id: roomId });
        this.joinedRooms.delete(roomId);
      }
    });
  }

  private startPing() {
    this.clearPingTimer();
    this.pingTimer = window.setInterval(() => {
      this.send({ type: 'ping' });
    }, PING_INTERVAL);
  }

  private scheduleReconnect() {
    this.clearTimers();
    if (!this.shouldReconnect || !this.token) return;
    this.reconnectTimer = window.setTimeout(() => {
      this.openSocket();
    }, DEFAULT_RECONNECT_DELAY);
  }

  private clearTimers() {
    this.clearPingTimer();
    if (this.reconnectTimer !== null) {
      window.clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }

  private clearPingTimer() {
    if (this.pingTimer !== null) {
      window.clearInterval(this.pingTimer);
      this.pingTimer = null;
    }
  }
}

export const websocketClient = new DesktopWebSocketClient();
