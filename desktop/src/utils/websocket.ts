/**
 * WebSocket 管理器 (Rust 层版本)
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
 * │    TypeScript → Tauri Command → Rust WS Client → Backend   │
 * │    ✅ 已实现 (desktop/src-tauri/src/websocket/)             │
 * │                                                             │
 * │  事件流：                                                    │
 * │    Backend → Rust WS Client → Tauri Event → TypeScript     │
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
 */

import { listen } from '@tauri-apps/api/event';
import type { UnlistenFn } from '@tauri-apps/api/event';
import { apiConfig } from '@/api/config';
import { store } from '@/store';
import { toast } from '@/utils/toast';
import { WebSocketApi } from '@/api/websocket';
import type { WebSocketParams } from '@/types/websocket';
import { BUSINESS_CODE } from '@/types/websocket';
import { MessageApi, transformBackendMessage } from '@/api/message';
import type { MessagePartPayloadInput } from '@/api/message';
import type { Message } from '@/types/models';
import type { ConnectionStatus } from '@/api/websocket';

/**
 * Tauri 事件负载类型
 */
interface TauriEventPayload {
  type: string;
  payload?: any;
}

/**
 * WebSocket 管理器 - 通过 Rust 层处理
 */
class WebSocketManager {
  private static instance: WebSocketManager;

  private lastAuthToken: string | null = null;
  private lastUserId: string | null = null;
  private desiredRooms: Set<string> = new Set();
  private eventUnlisteners: UnlistenFn[] = [];
  private lastChatListRefreshAt = 0;
  private lastContactRefreshAt = 0;

  public static getInstance(): WebSocketManager {
    if (!WebSocketManager.instance) {
      WebSocketManager.instance = new WebSocketManager();
    }
    return WebSocketManager.instance;
  }

  /**
   * 初始化 WebSocket 连接
   */
  public async initWebSocketSafely(params: WebSocketParams): Promise<void> {
    if (!params?.userId || !params?.token) {
      return;
    }

    // 检查是否需要重新连接
    const currentStatus = await WebSocketApi.getStatus();
    if (
      currentStatus === 'authenticated' &&
      this.lastUserId === params.userId &&
      this.lastAuthToken === params.token
    ) {
      return;
    }

    // 保存认证信息
    this.lastAuthToken = params.token;
    this.lastUserId = params.userId;

    // 清空房间订阅
    this.desiredRooms.clear();

    // 设置事件监听器
    await this.setupEventListeners();

    // 连接 WebSocket
    try {
      await WebSocketApi.connect(params, apiConfig.WS_URL);
    } catch (error) {
      toast.error('消息服务连接失败');
      throw error;
    }
  }

  public initWebSocket(params: WebSocketParams): void {
    void this.initWebSocketSafely(params);
  }

  /**
   * 设置 Tauri 事件监听器
   */
  private async setupEventListeners(): Promise<void> {
    // 清理旧的监听器
    this.eventUnlisteners.forEach((unlisten) => unlisten());
    this.eventUnlisteners = [];

    // 监听 WebSocket 事件
    const websocketUnlisten = await listen<TauriEventPayload>('websocket-event', (event) => {
      this.handleTauriEvent(event.payload);
    });
    this.eventUnlisteners.push(websocketUnlisten);

    // 监听网络状态事件
    const networkUnlisten = await listen<boolean>('network-state', (event) => {
      const isConnected = event.payload;
      store.commit('SET_NETWORK_STATE', isConnected);
      if (!isConnected) {
      }
    });
    this.eventUnlisteners.push(networkUnlisten);
  }

  /**
   * 处理 Rust 层发送的 Tauri 事件
   */
  private handleTauriEvent(payload: TauriEventPayload): void {
    const eventType = payload.type?.toLowerCase();

    switch (eventType) {
      case 'authed': {
        const data = payload.payload as { user_id: string; conn_id: string };
        store.commit('SET_NETWORK_STATE', true);
        this.onAuthenticated();
        break;
      }

      case 'joined': {
        const data = payload.payload as { room_id: string };
        break;
      }

      case 'left': {
        const data = payload.payload as { room_id: string };
        break;
      }

      case 'message': {
        const message = payload.payload;
        if (message) {
          this.emitChatMessage(message);
        }
        break;
      }

      case 'messageread': {
        this.emitMessageRead(payload.payload);
        break;
      }

      case 'messageupdate': {
        this.emitMessageUpdate(payload.payload);
        break;
      }

      case 'pinupdate': {
        this.emitPinUpdate(payload.payload);
        break;
      }

      case 'friendrequestupdate': {
        const data = payload.payload as { pending_count: number };
        if (typeof data.pending_count === 'number') {
          // 更新全局状态
          store.commit('SET_PENDING_FRIEND_REQUESTS', data.pending_count);
          
          // 同步到当前账号
          const currentAccountId = (store.state as any).accounts?.currentAccountId;
          if (currentAccountId) {
            store.commit('accounts/UPDATE_FRIEND_REQUEST_COUNT', {
              accountId: currentAccountId,
              count: data.pending_count
            }, { root: true });
          }
        }
        break;
      }

      case 'roomcreated': {
        this.dispatchDomEvent('websocket-room-created', payload.payload);
        this.refreshChatList();
        break;
      }

      case 'error': {
        const data = payload.payload as { message: string };
        toast.error(data.message || '消息服务错误');
        break;
      }

      case 'pong': {
        // 心跳响应，忽略
        break;
      }

      default:
        break;
    }
  }

  /**
   * 认证成功后的处理
   */
  private onAuthenticated(): void {
    // 刷新数据
    this.refreshAfterAuthenticated();

    // 订阅待加入的房间
    this.flushPendingRooms();
  }

  /**
   * 认证后刷新数据
   */
  private refreshAfterAuthenticated(): void {
    this.refreshChatList(true);
    this.refreshContacts(true);
    void store
      .dispatch('updatePendingFriendRequests')
  }

  /**
   * 刷新聊天列表
   */
  private refreshChatList(force = false): void {
    const now = Date.now();
    if (!force && now - this.lastChatListRefreshAt < 1000) {
      return;
    }
    this.lastChatListRefreshAt = now;
    void store
      .dispatch('loadChatList', { forceRefresh: true })
  }

  /**
   * 刷新联系人列表
   */
  private refreshContacts(force = false): void {
    const now = Date.now();
    if (!force && now - this.lastContactRefreshAt < 1000) {
      return;
    }
    this.lastContactRefreshAt = now;
    void store
      .dispatch('loadContacts', { forceRefresh: true })
  }

  /**
   * 订阅待加入的房间
   */
  private flushPendingRooms(): void {
    if (this.desiredRooms.size === 0) {
      return;
    }

    const roomIds = Array.from(this.desiredRooms);
    WebSocketApi.joinRooms(roomIds).catch((error) => {
    });
  }

  /**
   * 发送 DOM 事件
   */
  private dispatchDomEvent(eventName: string, detail: any): void {
    window.dispatchEvent(
      new CustomEvent(eventName, {
        detail,
      }),
    );
  }

  /**
   * 发送聊天消息事件
   */
  private emitChatMessage(rawMessage: any): void {
    let normalized: Message | null = null;
    try {
      // 使用现有的消息转换函数
      normalized = transformBackendMessage(rawMessage, this.lastUserId ?? undefined);
    } catch (error) {
    }

    this.dispatchDomEvent('websocket-chat-message', {
      message: normalized ?? rawMessage,
      raw: rawMessage,
    });
  }

  /**
   * 发送消息已读事件
   */
  private emitMessageRead(raw: any): void {
    const detail = { ...raw };
    delete (detail as Record<string, unknown>).type;
    this.dispatchDomEvent('websocket-message-read', detail);
  }

  /**
   * 发送消息更新事件
   */
  private emitMessageUpdate(raw: any): void {
    const detail: any = { ...raw };
    delete detail.type;
    if (detail.message) {
      try {
        detail.message = transformBackendMessage(detail.message, this.lastUserId ?? undefined);
      } catch (error) {
      }
    }
    this.dispatchDomEvent('websocket-message-update', detail);
  }

  /**
   * 发送置顶更新事件
   */
  private emitPinUpdate(raw: any): void {
    const detail: any = { ...raw };
    delete detail.type;
    if (detail.message) {
      try {
        detail.message = transformBackendMessage(detail.message, this.lastUserId ?? undefined);
      } catch (error) {
      }
    }
    this.dispatchDomEvent('websocket-pin-update', detail);
  }

  /**
   * 确保房间已订阅
   */
  public ensureRoomsSubscribed(roomIds: Iterable<string>, pruneMissing = false): void {
    const normalized = new Set(
      Array.from(roomIds)
        .map((roomId) => roomId.trim())
        .filter((roomId) => roomId.length > 0),
    );

    // 添加到期望订阅列表
    normalized.forEach((roomId) => this.desiredRooms.add(roomId));

    // 立即加入房间
    if (normalized.size > 0) {
      WebSocketApi.joinRooms(Array.from(normalized)).catch((error) => {
      });
    }

    // 清理不需要的房间订阅
    if (pruneMissing) {
      WebSocketApi.getSubscribedRooms()
        .then((subscribedRooms) => {
          subscribedRooms.forEach((roomId) => {
            if (!normalized.has(roomId)) {
              this.leaveRoom(roomId);
            }
          });
        })
        .catch((error) => {
        });
    }
  }

  /**
   * 加入房间
   */
  public joinRoom(roomId: string): void {
    if (!roomId) return;
    this.desiredRooms.add(roomId);
    WebSocketApi.joinRoom(roomId).catch((error) => {
    });
  }

  /**
   * 离开房间
   */
  public leaveRoom(roomId: string): void {
    if (!roomId) return;
    this.desiredRooms.delete(roomId);
    WebSocketApi.leaveRoom(roomId).catch((error) => {
    });
  }

  /**
   * 发送消息
   */
  public async sendMessage(
    payload: any,
    code: string = BUSINESS_CODE.chatting,
    callback?: (success: boolean) => void,
  ): Promise<any> {
    // 只支持聊天消息发送
    if (code !== BUSINESS_CODE.chatting) {
      callback?.(false);
      throw new Error('该操作应通过 HTTP API 调用');
    }

    try {
      return await this._sendChatMessage(payload, callback);
    } catch (error: any) {
      callback?.(false);
      throw error;
    }
  }

  /**
   * 发送聊天消息
   */
  private async _sendChatMessage(payload: any, callback?: (success: boolean) => void) {
    const roomId =
      payload?.roomId || payload?.chatGroupId || payload?.groupId || payload?.room_id;

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
      currentUserId: this.lastUserId ?? undefined,
    });

    if (response.success && response.data) {
      callback?.(true);
      return response.data;
    }
  }

  /**
   * 关闭 WebSocket 连接
   */
  public async closeWebSocket(): Promise<void> {
    // 清理事件监听器
    this.eventUnlisteners.forEach((unlisten) => unlisten());
    this.eventUnlisteners = [];

    // 断开 WebSocket
    await WebSocketApi.disconnect();

    // 清空状态
    this.desiredRooms.clear();
    this.lastAuthToken = null;
    this.lastUserId = null;

    store.commit('SET_NETWORK_STATE', false);
  }

  /**
   * 获取连接状态
   */
  public async getConnectionState(): Promise<boolean> {
    const status = await WebSocketApi.getStatus();
    return status === 'authenticated';
  }
}

export const webSocketManager = WebSocketManager.getInstance();
