import { apiConfig } from '@/api/config';
import { store } from '@/store';
import { toast } from '@/utils/toast';
import {
  encodeClientAuth,
  encodeClientJoin,
  encodeClientLeave,
  encodeClientPing,
  decodeServerEvent,
} from '@/proto';
import type { WebSocketParams } from '@/types/websocket';
import { BUSINESS_CODE } from '@/types/websocket';
import { MessageApi } from '@/api/message';

type ConnectionStatus = 'disconnected' | 'connecting' | 'authenticated';

interface InternalState {
  socket: WebSocket | null;
  status: ConnectionStatus;
  reconnectAttempts: number;
  pingTimer: number | null;
  reconnectTimer: number | null;
  lastAuthToken: string | null;
  lastUserId: string | null;
}

const MAX_RECONNECT_ATTEMPTS = 5;
const RECONNECT_DELAY = 3000;
const PING_INTERVAL = 30000;

const MESSAGE_TYPE_CODE: Record<string, number> = {
  text: 1,
  image: 2,
  audio: 3,
  video: 4,
  file: 5,
  system: 9,
};

const arrayBufferFromData = async (data: Blob | ArrayBuffer | string): Promise<ArrayBuffer> => {
  if (data instanceof ArrayBuffer) {
    return data;
  }
  if (data instanceof Blob) {
    return data.arrayBuffer();
  }

  // 兼容后端偶尔返回的 JSON 文本，尝试解析 base64 或直接抛错
  try {
    const binaryString = atob(data);
    const len = binaryString.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i += 1) {
      bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes.buffer;
  } catch (error) {
    console.error('无法解析 WebSocket 文本帧:', data);
    throw error;
  }
};

const normalizeServerMessage = (message: any, currentUserId: string | null) => {
  const senderId = message.sender_id || message.senderId || '';
  const inferredMessageType = MESSAGE_TYPE_CODE[message.message_type as string] ?? 1;

  return {
    id: message.message_id || message.id,
    messageId: message.message_id || message.id,
    chatGroupId: message.room_id,
    groupId: message.room_id,
    userId: senderId,
    userName: message.sender_username || message.sender_nickname || '未知用户',
    senderId,
    senderName: message.sender_nickname || message.sender_username || '未知用户',
    senderAvatar: message.sender_avatar_url || '',
    messageType: inferredMessageType,
    contentType: inferredMessageType,
    content: {
      text: message.content,
      raw: message.content,
    },
    createTime: message.timestamp || new Date().toISOString(),
    timestamp: message.timestamp ? Date.parse(message.timestamp) : Date.now(),
    meFlag: currentUserId ? senderId?.toString() === currentUserId.toString() : false,
    showTimeFlag: false,
    raw: message,
  };
};

class WebSocketManager {
  private static instance: WebSocketManager;

  private readonly state: InternalState = {
    socket: null,
    status: 'disconnected',
    reconnectAttempts: 0,
    pingTimer: null,
    reconnectTimer: null,
    lastAuthToken: null,
    lastUserId: null,
  };

  private desiredRooms: Set<string> = new Set();
  private subscribedRooms: Set<string> = new Set();
  private pendingRooms: Set<string> = new Set();

  public static getInstance(): WebSocketManager {
    if (!WebSocketManager.instance) {
      WebSocketManager.instance = new WebSocketManager();
    }
    return WebSocketManager.instance;
  }

  public async initWebSocketSafely(params: WebSocketParams): Promise<void> {
    if (!params?.userId || !params?.token) {
      console.warn('WebSocket 参数缺失，跳过连接');
      return;
    }

    // 已连接且认证用户一致时直接返回
    if (
      this.state.status === 'authenticated' &&
      this.state.lastUserId === params.userId &&
      this.state.lastAuthToken === params.token &&
      this.state.socket
    ) {
      return;
    }

    this.desiredRooms.clear();
    this.subscribedRooms.clear();
    this.pendingRooms.clear();

    this.state.lastAuthToken = params.token;
    this.state.lastUserId = params.userId;

    await this.createConnection(params);
  }

  public initWebSocket(params: WebSocketParams): void {
    void this.initWebSocketSafely(params);
  }

  private async createConnection(params: WebSocketParams): Promise<void> {
    this.clearReconnectTimer();
    this.closeWebSocket();

    try {
      this.state.status = 'connecting';
      store.commit('SET_NETWORK_STATE', false);

      const wsUrl = new URL(apiConfig.WS_URL);
      wsUrl.searchParams.set('format', 'proto');

      const socket = new WebSocket(wsUrl.toString());
      socket.binaryType = 'arraybuffer';
      this.state.socket = socket;

      socket.onopen = () => {
        this.state.status = 'connecting';
        this.state.reconnectAttempts = 0;
        store.commit('SET_WEBSOCKET', socket);
        store.commit('SET_NETWORK_STATE', true);
        this.sendBinary(encodeClientAuth(params.token));
        this.startPing();
      };

      socket.onmessage = async (event) => {
        try {
          const buffer = await arrayBufferFromData(event.data);
          const serverEvent = decodeServerEvent(new Uint8Array(buffer));
          this.handleServerEvent(serverEvent);
        } catch (error) {
          console.error('解析服务器事件失败:', error);
        }
      };

      socket.onerror = (error) => {
        console.error('WebSocket 发生错误:', error);
        this.scheduleReconnect();
      };

      socket.onclose = (event) => {
        console.warn('WebSocket 连接关闭:', event.code, event.reason);
        if (this.state.status === 'authenticated') {
          toast.warning('消息服务连接已断开，正在尝试重连');
        }
        this.scheduleReconnect();
      };
    } catch (error) {
      console.error('创建 WebSocket 连接失败:', error);
      this.scheduleReconnect();
    }
  }

  private handleServerEvent(serverEvent: any) {
    const payload = serverEvent;

    if (payload.authed) {
      this.state.status = 'authenticated';
      this.flushPendingRooms();
      return;
    }

    if (payload.joined) {
      const roomId = payload.joined.room_id;
      this.pendingRooms.delete(roomId);
      this.subscribedRooms.add(roomId);
      return;
    }

    if (payload.left) {
      const roomId = payload.left.room_id;
      this.pendingRooms.delete(roomId);
      this.subscribedRooms.delete(roomId);
      return;
    }

    if (payload.message) {
      const normalized = normalizeServerMessage(payload.message, this.state.lastUserId);
      window.dispatchEvent(
        new CustomEvent('websocket-chat-message', {
          detail: normalized,
        }),
      );
      return;
    }

    if (payload.message_read) {
      window.dispatchEvent(
        new CustomEvent('websocket-message-read', {
          detail: payload.message_read,
        }),
      );
      return;
    }

    if (payload.message_update) {
      window.dispatchEvent(
        new CustomEvent('websocket-message-update', {
          detail: payload.message_update,
        }),
      );
      return;
    }

    if (payload.pin_update) {
      window.dispatchEvent(
        new CustomEvent('websocket-pin-update', {
          detail: payload.pin_update,
        }),
      );
      return;
    }

    if (payload.friend_request_update) {
      store.commit('SET_PENDING_FRIEND_REQUESTS', payload.friend_request_update.pending_count);
      return;
    }

    if (payload.room_created) {
      window.dispatchEvent(
        new CustomEvent('websocket-room-created', {
          detail: payload.room_created,
        }),
      );
      return;
    }

    if (payload.error) {
      console.error('WebSocket 错误:', payload.error.message);
      toast.error(payload.error.message || '消息服务错误');
      return;
    }
  }

  private flushPendingRooms() {
    if (!this.state.socket || this.state.status !== 'authenticated') {
      return;
    }
    this.desiredRooms.forEach((roomId) => {
      if (!this.subscribedRooms.has(roomId) && !this.pendingRooms.has(roomId)) {
        this.pendingRooms.add(roomId);
        this.sendBinary(encodeClientJoin(roomId));
      }
    });
  }

  public ensureRoomsSubscribed(roomIds: Iterable<string>, pruneMissing = false) {
    const normalized = new Set(
      Array.from(roomIds)
        .map((roomId) => roomId.trim())
        .filter((roomId) => roomId.length > 0),
    );

    normalized.forEach((roomId) => this.desiredRooms.add(roomId));

    if (pruneMissing) {
      Array.from(this.subscribedRooms).forEach((roomId) => {
        if (!normalized.has(roomId)) {
          this.leaveRoom(roomId);
        }
      });
    }

    this.flushPendingRooms();
  }

  public joinRoom(roomId: string) {
    if (!roomId) return;
    this.desiredRooms.add(roomId);
    this.flushPendingRooms();
  }

  public leaveRoom(roomId: string) {
    if (!roomId) return;
    this.desiredRooms.delete(roomId);
    if (this.subscribedRooms.has(roomId)) {
      this.sendBinary(encodeClientLeave(roomId));
      this.subscribedRooms.delete(roomId);
    }
    this.pendingRooms.delete(roomId);
  }

  public async sendMessage(
    payload: any,
    code: string = BUSINESS_CODE.chatting,
    callback?: (success: boolean) => void,
  ): Promise<any> {
    if (code !== BUSINESS_CODE.chatting) {
      console.warn('暂未实现该类型的发送:', code);
      callback?.(false);
      throw new Error('暂未实现的消息类型');
    }

    try {
      const response = await MessageApi.sendTextMessage({
        groupId: payload.chatGroupId || payload.room_id || payload.groupId,
        content: typeof payload.content === 'string' ? payload.content : payload.content?.text || '',
        replyToMessageId: payload.quotedMessageId,
      });

      if (response.success && response.data) {
        callback?.(true);
        return response.data;
      }

      callback?.(false);
      throw new Error(response.message || '消息发送失败');
    } catch (error: any) {
      console.error('消息发送失败:', error);
      toast.error(error?.message || '消息发送失败');
      callback?.(false);
      throw error;
    }

    // 理论上不会执行到此处
    // 仅为了类型完整性
    // eslint-disable-next-line no-unreachable
    return null;
  }

  private sendBinary(data: Uint8Array) {
    if (!this.state.socket || this.state.socket.readyState !== WebSocket.OPEN) {
      return;
    }
    this.state.socket.send(data);
  }

  private startPing() {
    this.clearPingTimer();
    this.state.pingTimer = window.setInterval(() => {
      this.sendBinary(encodeClientPing());
    }, PING_INTERVAL);
  }

  private clearPingTimer() {
    if (this.state.pingTimer) {
      clearInterval(this.state.pingTimer);
      this.state.pingTimer = null;
    }
  }

  private scheduleReconnect() {
    this.clearPingTimer();

    if (this.state.socket) {
      try {
        this.state.socket.close();
      } catch (error) {
        console.warn('关闭 WebSocket 失败:', error);
      }
    }
    this.state.socket = null;
    store.commit('SET_WEBSOCKET', null);
    store.commit('SET_NETWORK_STATE', false);
    this.state.status = 'disconnected';

    if (this.state.reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
      console.error('WebSocket 重连超过最大次数');
      toast.error('消息服务连接失败，请检查网络或稍后再试');
      return;
    }

    this.state.reconnectAttempts += 1;
    this.clearReconnectTimer();
    this.state.reconnectTimer = window.setTimeout(() => {
      if (this.state.lastAuthToken && this.state.lastUserId) {
        this.createConnection({
          token: this.state.lastAuthToken,
          userId: this.state.lastUserId,
        });
      }
    }, RECONNECT_DELAY * this.state.reconnectAttempts);
  }

  private clearReconnectTimer() {
    if (this.state.reconnectTimer) {
      clearTimeout(this.state.reconnectTimer);
      this.state.reconnectTimer = null;
    }
  }

  public closeWebSocket(): void {
    this.clearPingTimer();
    this.clearReconnectTimer();

    if (this.state.socket) {
      try {
        this.state.socket.close();
      } catch (error) {
        console.warn('关闭 WebSocket 失败:', error);
      }
    }

    this.state.socket = null;
    this.state.status = 'disconnected';
    this.state.reconnectAttempts = 0;
    store.commit('SET_WEBSOCKET', null);
    store.commit('SET_NETWORK_STATE', false);
  }

  private get isConnected(): boolean {
    return this.state.status === 'authenticated' && !!this.state.socket;
  }

  public getConnectionState(): boolean {
    return this.isConnected;
  }
}

export const webSocketManager = WebSocketManager.getInstance();
