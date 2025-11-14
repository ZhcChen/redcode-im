/**
 * WebSocket 管理器
 *
 * 架构说明：
 * ┌─────────────────────────────────────────────────────────────┐
 * │ Desktop 端网络请求架构（Tauri 应用）                          │
 * ├─────────────────────────────────────────────────────────────┤
 * │                                                             │
 * │  HTTP 请求：                                                 │
 * │    TypeScript → Tauri Command → Rust HTTP Client → Backend │
 * │    ✅ 已实现 (desktop/src-tauri/src/http/)                  │
 * │                                                             │
 * │  WebSocket 连接：                                            │
 * │    TypeScript → WebSocket (当前) → Backend                  │
 * │    ⚠️ 待重构：应通过 Rust 层处理                             │
 * │    🔜 未来：TypeScript → Tauri Command → Rust WS → Backend  │
 * │                                                             │
 * └─────────────────────────────────────────────────────────────┘
 *
 * WebSocket 职责：
 * - ✅ 接收服务器推送的实时通知（消息、好友变更、群聊事件等）
 * - ❌ 不应用于主动操作（创建群聊、删除好友等应通过 HTTP API）
 *
 * 正确的操作流程：
 * 1. 客户端操作 → HTTP API (通过 Rust)
 * 2. 服务器处理 → 数据库更新
 * 3. 服务器推送 → WebSocket 通知
 * 4. 客户端接收 → 更新UI状态
 *
 * @see docs/桌面端/桌面端剩余工作.md - WebSocket 能力
 */

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
import { MessageApi, transformBackendMessage } from '@/api/message';
import type { MessagePartPayloadInput } from '@/api/message';
import type { Message } from '@/types/models';

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

const arrayBufferFromBinaryData = async (data: Blob | ArrayBuffer): Promise<ArrayBuffer> => {
  if (data instanceof ArrayBuffer) {
    return data;
  }
  return data.arrayBuffer();
};

const arrayBufferFromBase64 = (data: string): ArrayBuffer | null => {
  try {
    const binaryString = atob(data);
    const len = binaryString.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i += 1) {
      bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes.buffer;
  } catch (error) {
    return null;
  }
};

const mapNumericMessageTypeToString = (value: number | string | undefined | null): string => {
  if (typeof value === 'string') {
    return value;
  }
  switch (value) {
    case 2:
      return 'image';
    case 3:
      return 'audio';
    case 4:
      return 'video';
    case 5:
      return 'file';
    case 9:
      return 'system';
    case 1:
    default:
      return 'text';
  }
};

const normalizeServerMessage = (message: any, currentUserId: string | null): Message => {
  const parseNumber = (value: any): number | null => {
    if (value === null || value === undefined) {
      return null;
    }
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value;
    }
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  };

  const normalizeAttachment = (attachment: any) => {
    if (!attachment || typeof attachment !== 'object') {
      return null;
    }

    const key = attachment.key ?? attachment.file_key ?? attachment.ossKey;
    if (!key || typeof key !== 'string') {
      return null;
    }

    return {
      key,
      name: attachment.name ?? null,
      mime: attachment.mime ?? attachment.content_type ?? null,
      size: parseNumber(attachment.size),
      width: parseNumber(attachment.width),
      height: parseNumber(attachment.height),
      duration_ms: parseNumber(attachment.duration_ms ?? attachment.durationMs),
      thumbnail_key: attachment.thumbnail_key ?? attachment.thumbnailKey ?? null,
    } as const;
  };

  type NormalizedAttachment = ReturnType<typeof normalizeAttachment>;

  type NormalizedPart = {
    position: number;
    part_type: string;
    text: string | null;
    attachment: NormalizedAttachment;
  };

  const normalizeParts = (parts: any): NormalizedPart[] => {
    if (!Array.isArray(parts) || parts.length === 0) {
      return [];
    }

    return parts
      .map<NormalizedPart | null>((part) => {
        if (!part || typeof part !== 'object') {
          return null;
        }

        const positionRaw = part.position ?? part.index ?? part.sort ?? 0;
        const position = Number(positionRaw);
        if (Number.isNaN(position)) {
          return null;
        }

        const typeRaw = part.part_type ?? part.type ?? part.partType;
        if (!typeRaw) {
          return null;
        }

        const text: string | null = typeof part.text === 'string'
          ? part.text
          : typeof part.content === 'string'
            ? part.content
            : null;

        const attachment: NormalizedAttachment = normalizeAttachment(
          part.attachment ?? part.file ?? part.media,
        );

        return {
          position,
          part_type: String(typeRaw).toLowerCase(),
          text,
          attachment,
        };
      })
      .filter((part): part is NormalizedPart => part !== null)
      .sort((a, b) => a.position - b.position);
  };

  const normalizeQuotedMessage = (quoted: any) => {
    if (!quoted || typeof quoted !== 'object') {
      return null;
    }

    const quotedType = mapNumericMessageTypeToString(
      quoted.message_type ?? quoted.messageType ?? 'text',
    );

    let content = typeof quoted.content === 'string'
      ? quoted.content
      : quoted.content?.text || '';

    const quotedParts = normalizeParts(quoted.parts);
    if (!content && quotedParts.length > 0) {
      const textPart = quotedParts.find(
        (part) => part.part_type === 'text' && typeof part.text === 'string',
      );
      if (textPart?.text) {
        content = textPart.text;
      }
    }

    return {
      id: quoted.message_id || quoted.id,
      room_id: quoted.room_id,
      sender_id: quoted.sender_id ?? quoted.user_id ?? '',
      sender_username: quoted.sender_username ?? quoted.senderUsername ?? '',
      sender_nickname: quoted.sender_nickname ?? quoted.senderNickname ?? null,
      sender_avatar_url: quoted.sender_avatar_url ?? quoted.senderAvatarUrl ?? null,
      content,
      message_type: quotedType,
      created_at: quoted.created_at || quoted.timestamp || null,
      is_deleted: quoted.is_deleted ?? quoted.deleted ?? false,
      parts: quotedParts,
    };
  };

  const normalizedParts = normalizeParts(message.parts);
  const messageType = mapNumericMessageTypeToString(message.message_type ?? message.messageType ?? 'text');
  let normalizedContent = typeof message.content === 'string'
    ? message.content
    : message.content?.text || '';

  if (!normalizedContent && normalizedParts.length > 0) {
    const textPart = normalizedParts.find((part) => part.part_type === 'text' && typeof part.text === 'string');
    if (textPart?.text) {
      normalizedContent = textPart.text;
    }
  }
  const backendMessage = {
    id: message.message_id || message.id,
    room_id: message.room_id,
    sender_id: message.sender_id || message.senderId,
    sender_username: message.sender_username || message.senderUsername || '',
    sender_nickname: message.sender_nickname || null,
    sender_avatar_url: message.sender_avatar_url || null,
    content: normalizedContent,
    message_type: messageType,
    status: message.status,
    created_at: message.timestamp || message.created_at || new Date().toISOString(),
    quoted_message: normalizeQuotedMessage(message.quoted_message),
    forward_message: message.forward_message || null,
    is_deleted: message.is_deleted || false,
    deleted_at: message.deleted_at || null,
    is_pinned: message.is_pinned || false,
    pinned_at: message.pinned_at || null,
    pinned_by: message.pinned_by || null,
    extra: message.extra || null,
    parts: normalizedParts,
  } as any;

  return transformBackendMessage(backendMessage, currentUserId || undefined);
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
  private lastChatListRefreshAt = 0;
  private lastContactRefreshAt = 0;

  public static getInstance(): WebSocketManager {
    if (!WebSocketManager.instance) {
      WebSocketManager.instance = new WebSocketManager();
    }
    return WebSocketManager.instance;
  }

  public async initWebSocketSafely(params: WebSocketParams): Promise<void> {
    if (!params?.userId || !params?.token) {
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
        const payload = event.data;

        if (typeof payload === 'string') {
          if (this.handleTextFrame(payload)) {
            return;
          }

          const buffer = arrayBufferFromBase64(payload);
          if (buffer) {
            this.processBinaryFrame(buffer);
            return;
          }

          return;
        }

        if (payload instanceof ArrayBuffer) {
          this.processBinaryFrame(payload);
          return;
        }

        if (ArrayBuffer.isView(payload)) {
          const view = payload as ArrayBufferView;
          const buffer = view.buffer.slice(view.byteOffset, view.byteOffset + view.byteLength);
          this.processBinaryFrame(buffer);
          return;
        }

        if (payload instanceof Blob) {
          try {
            const buffer = await arrayBufferFromBinaryData(payload);
            this.processBinaryFrame(buffer);
          } catch (error) {
          }
          return;
        }

      };

      socket.onerror = (error) => {
        this.scheduleReconnect();
      };

      socket.onclose = (event) => {
        if (this.state.status === 'authenticated') {
          toast.warning('消息服务连接已断开，正在尝试重连');
        }
        this.scheduleReconnect();
      };
    } catch (error) {
      this.scheduleReconnect();
    }
  }

  private processBinaryFrame(buffer: ArrayBuffer): void {
    try {
      const serverEvent = decodeServerEvent(new Uint8Array(buffer));
      this.handleServerEvent(serverEvent);
    } catch (error) {
    }
  }

  private handleTextFrame(text: string): boolean {
    const trimmed = text.trim();
    if (!trimmed) {
      return true;
    }

    try {
      const parsed = JSON.parse(trimmed);
      if (parsed && typeof parsed === 'object') {
        if (parsed.code) {
          this.handleBusinessPayload(parsed);
          return true;
        }

        if (parsed.type) {
          this.handleLegacyPayload(parsed as Record<string, any>);
          return true;
        }
      }
    } catch (error) {
      // 尝试将文本按 base64 处理，由调用方继续
      return false;
    }

    return false;
  }

  private handleBusinessPayload(payload: any): void {
    const code = String(payload?.code ?? '').trim();
    const messageBody = payload?.message ?? payload?.data ?? null;

    switch (code) {
      case BUSINESS_CODE.chatting:
        if (messageBody) {
          this.emitChatMessage(messageBody);
        }
        break;
      case BUSINESS_CODE.AI:
        if (messageBody !== undefined) {
          this.dispatchDomEvent('websocket-ai-message', messageBody);
        }
        break;
      case BUSINESS_CODE.FriendBindChange:
        if (messageBody !== undefined) {
          this.dispatchDomEvent('websocket-friend-change', messageBody);
          this.refreshContacts();
          this.refreshChatList();
        }
        break;
      case BUSINESS_CODE.DeleteFriend:
        if (messageBody !== undefined) {
          this.dispatchDomEvent('websocket-delete-friend', messageBody);
          this.refreshContacts();
          this.refreshChatList();
        }
        break;
      case BUSINESS_CODE.FriendCircle:
        if (messageBody !== undefined) {
          this.dispatchDomEvent('websocket-friend-circle', messageBody);
        }
        break;
      case BUSINESS_CODE.launchGroup:
        if (messageBody !== undefined) {
          this.dispatchDomEvent('websocket-launch-group', messageBody);
          this.refreshChatList();
        }
        break;
      case BUSINESS_CODE.deleteGroup:
        if (messageBody !== undefined) {
          this.dispatchDomEvent('websocket-delete-group', messageBody);
          this.refreshChatList();
        }
        break;
      case BUSINESS_CODE.Calling:
        if (messageBody !== undefined) {
          this.dispatchDomEvent('websocket-calling', messageBody);
        }
        break;
      case BUSINESS_CODE.ping:
        break;
      default:
        if (code) {
        }
        break;
    }
  }

  private handleLegacyPayload(message: Record<string, any>): void {
    const rawType = message?.type;
    if (!rawType) {
      return;
    }

    const type = String(rawType).toLowerCase();

    switch (type) {
      case 'authed': {
        const userId = message.user_id ?? message.userId;
        if (typeof userId === 'string' && userId.length > 0) {
          this.state.lastUserId = userId;
        }
        const connectionId = message.conn_id ?? message.connId;
        this.onAuthenticated(connectionId ?? null);
        break;
      }
      case 'joined': {
        const roomId = message.room_id ?? message.roomId;
        if (typeof roomId === 'string' && roomId.length > 0) {
          this.onRoomJoined(roomId);
        }
        break;
      }
      case 'left': {
        const roomId = message.room_id ?? message.roomId;
        if (typeof roomId === 'string' && roomId.length > 0) {
          this.onRoomLeft(roomId);
        }
        break;
      }
      case 'message':
        if (message.message) {
          this.emitChatMessage(message.message);
        } else {
          this.emitChatMessage(message);
        }
        break;
      case 'message_read':
        this.emitMessageRead(message);
        break;
      case 'message_update':
        this.emitMessageUpdate(message);
        break;
      case 'pin_update':
        this.emitPinUpdate(message);
        break;
      case 'friend_request_update':
        if (typeof message.pending_count === 'number') {
          store.commit('SET_PENDING_FRIEND_REQUESTS', message.pending_count);
        }
        break;
      case 'room_created':
      case 'room.created':
        this.dispatchDomEvent('websocket-room-created', message);
        this.refreshChatList();
        break;
      case 'friendship.created':
      case 'friendship_created':
        this.dispatchDomEvent('websocket-friend-change', {
          type: 'created',
          payload: message.friend ?? message.user ?? null,
        });
        this.refreshContacts();
        this.refreshChatList();
        break;
      case 'friendship.deleted':
      case 'friendship_deleted':
        this.dispatchDomEvent('websocket-friend-change', {
          type: 'deleted',
          payload: message.friend ?? message.user ?? null,
        });
        this.refreshContacts();
        this.refreshChatList();
        break;
      case 'friend.updated':
      case 'friend_profile_updated':
        this.dispatchDomEvent('websocket-friend-change', {
          type: 'updated',
          payload: message,
        });
        this.refreshContacts();
        break;
      case 'friends.version':
      case 'friends_version':
        this.refreshContacts();
        break;
      case 'error':
        if (message.message) {
          toast.error(message.message);
        }
        break;
      case 'pong':
        break;
      default:
        break;
    }
  }

  private handleServerEvent(serverEvent: any) {
    const payload = serverEvent;

    if (payload.authed) {
      const userId = payload.authed.user_id ?? payload.authed.userId ?? null;
      if (typeof userId === 'string' && userId.length > 0) {
        this.state.lastUserId = userId;
      }
      this.onAuthenticated(payload.authed.conn_id ?? payload.authed.connId ?? null);
      return;
    }

    if (payload.joined) {
      const roomId = payload.joined.room_id ?? payload.joined.roomId;
      if (typeof roomId === 'string' && roomId.length > 0) {
        this.onRoomJoined(roomId);
      }
      return;
    }

    if (payload.left) {
      const roomId = payload.left.room_id ?? payload.left.roomId;
      if (typeof roomId === 'string' && roomId.length > 0) {
        this.onRoomLeft(roomId);
      }
      return;
    }

    if (payload.message) {
      this.emitChatMessage(payload.message);
      return;
    }

    if (payload.message_read) {
      this.emitMessageRead(payload.message_read);
      return;
    }

    if (payload.message_update) {
      this.emitMessageUpdate(payload.message_update);
      return;
    }

    if (payload.pin_update) {
      this.emitPinUpdate(payload.pin_update);
      return;
    }

    if (payload.friend_request_update) {
      store.commit('SET_PENDING_FRIEND_REQUESTS', payload.friend_request_update.pending_count);
      return;
    }

    if (payload.room_created) {
      this.dispatchDomEvent('websocket-room-created', payload.room_created);
      this.refreshChatList();
      return;
    }

    if (payload.error) {
      toast.error(payload.error.message || '消息服务错误');
      return;
    }
  }

  private dispatchDomEvent(eventName: string, detail: any): void {
    window.dispatchEvent(
      new CustomEvent(eventName, {
        detail,
      }),
    );
  }

  private emitChatMessage(rawMessage: any): void {
    let normalized: Message | null = null;
    try {
      normalized = normalizeServerMessage(rawMessage, this.state.lastUserId);
    } catch (error) {
    }

    this.dispatchDomEvent('websocket-chat-message', {
      message: normalized ?? rawMessage,
      raw: rawMessage,
    });
  }

  private emitMessageRead(raw: any): void {
    const detail = { ...raw };
    delete (detail as Record<string, unknown>).type;
    this.dispatchDomEvent('websocket-message-read', detail);
  }

  private emitMessageUpdate(raw: any): void {
    const detail: any = { ...raw };
    delete detail.type;
    if (detail.message) {
      try {
        detail.message = normalizeServerMessage(detail.message, this.state.lastUserId);
      } catch (error) {
      }
    }
    this.dispatchDomEvent('websocket-message-update', detail);
  }

  private emitPinUpdate(raw: any): void {
    const detail: any = { ...raw };
    delete detail.type;
    if (detail.message) {
      try {
        detail.message = normalizeServerMessage(detail.message, this.state.lastUserId);
      } catch (error) {
      }
    }
    this.dispatchDomEvent('websocket-pin-update', detail);
  }

  private onAuthenticated(connectionId?: string | null): void {
    this.state.status = 'authenticated';
    this.flushPendingRooms();
    this.refreshAfterAuthenticated();

    if (connectionId) {
      store.commit('SET_NETWORK_STATE', true);
    }
  }

  private refreshAfterAuthenticated(): void {
    this.refreshChatList(true);
    this.refreshContacts(true);
    void store
      .dispatch('updatePendingFriendRequests')
  }

  private refreshChatList(force = false): void {
    const now = Date.now();
    if (!force && now - this.lastChatListRefreshAt < 1000) {
      return;
    }
    this.lastChatListRefreshAt = now;
    void store
      .dispatch('loadChatList', { forceRefresh: true })
  }

  private refreshContacts(force = false): void {
    const now = Date.now();
    if (!force && now - this.lastContactRefreshAt < 1000) {
      return;
    }
    this.lastContactRefreshAt = now;
    void store
      .dispatch('loadContacts', { forceRefresh: true })
  }

  private onRoomJoined(roomId: string): void {
    this.pendingRooms.delete(roomId);
    this.subscribedRooms.add(roomId);
  }

  private onRoomLeft(roomId: string): void {
    this.pendingRooms.delete(roomId);
    this.subscribedRooms.delete(roomId);
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
    // 支持的消息类型
    const supportedCodes = [
      BUSINESS_CODE.chatting,
      BUSINESS_CODE.launchGroup,
      BUSINESS_CODE.deleteGroup,
      BUSINESS_CODE.DeleteFriend,
      BUSINESS_CODE.FriendBindChange,
    ];

    if (!supportedCodes.includes(code as any)) {
      callback?.(false);
      throw new Error('暂未实现的消息类型');
    }

    try {
      // 根据不同的消息类型处理
      switch (code) {
        case BUSINESS_CODE.chatting:
          return await this._sendChatMessage(payload, callback);

        // NOTE: 以下操作应通过 HTTP API 完成，而非 WebSocket
        // - 群聊创建/删除 → 使用 RoomApi
        // - 好友删除/状态变更 → 使用 FriendApi
        // WebSocket 只负责接收服务器推送的通知事件
        case BUSINESS_CODE.launchGroup:
        case BUSINESS_CODE.deleteGroup:
        case BUSINESS_CODE.DeleteFriend:
        case BUSINESS_CODE.FriendBindChange:
          callback?.(false);
          throw new Error('该操作应通过 HTTP API 调用');

        default:
          callback?.(false);
          throw new Error('未知的消息类型');
      }
    } catch (error: any) {
      callback?.(false);
      throw error;
    }
  }

  // 发送聊天消息
  private async _sendChatMessage(payload: any, callback?: (success: boolean) => void) {
    const roomId =
      payload?.roomId ||
      payload?.chatGroupId ||
      payload?.groupId ||
      payload?.room_id;

    if (!roomId || typeof roomId !== 'string') {
      callback?.(false);
      throw new Error('缺少群组 ID，无法发送消息');
    }

    let content: string | undefined;
    if (typeof payload?.content === 'string') {
      content = payload.content;
    } else if (payload?.content && typeof payload.content.text === 'string') {
      content = payload.content.text;
    } else if (typeof payload?.text === 'string') {
      content = payload.text;
    }

    let parts: MessagePartPayloadInput[] | undefined;
    if (Array.isArray(payload?.parts)) {
      parts = payload.parts as MessagePartPayloadInput[];
    } else if (Array.isArray(payload?.partsPayload)) {
      parts = payload.partsPayload as MessagePartPayloadInput[];
    }

    const replyToMessageId =
      payload?.replyToMessageId ||
      payload?.quotedMessageId ||
      payload?.quoted_message_id ||
      undefined;

    const response = await MessageApi.sendMessage({
      groupId: roomId,
      content,
      parts,
      replyToMessageId,
      currentUserId: this.state.lastUserId ?? undefined,
    });

    if (response.success && response.data) {
      callback?.(true);
      return response.data;
    }
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
      }
    }
    this.state.socket = null;
    store.commit('SET_WEBSOCKET', null);
    store.commit('SET_NETWORK_STATE', false);
    this.state.status = 'disconnected';

    if (this.state.reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
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
