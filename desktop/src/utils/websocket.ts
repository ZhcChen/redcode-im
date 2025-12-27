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
import { NotificationApi } from '@/api/notification';

/**
 * Tauri 事件负载类型
 */
interface TauriEventPayload {
  type: string;
  payload?: any;
}

/**
 * 带用户标识的事件包装（与 Rust 端 UserEventWrapper 对应）
 */
interface UserEventWrapper {
  user_id: string;
  type: string;
  payload?: any;
}

/**
 * 单个账号的连接信息
 */
interface ConnectionInfo {
  authToken: string;
  userId: string;
  desiredRooms: Set<string>;
  status: ConnectionStatus;
}

/**
 * WebSocket 管理器 - 通过 Rust 层处理
 * 支持多账号同时连接
 */
class WebSocketManager {
  private static instance: WebSocketManager;

  /** 多账号连接管理 Map<userId, ConnectionInfo> */
  private connections: Map<string, ConnectionInfo> = new Map();
  /** 当前活跃账号 ID */
  private currentUserId: string | null = null;
  private eventUnlisteners: UnlistenFn[] = [];
  private lastChatListRefreshAt = 0;
  private lastContactRefreshAt = 0;
  // 好友申请计数缓存，用于检测新增请求触发提醒
  private friendRequestCounts: Map<string, number> = new Map();

  public static getInstance(): WebSocketManager {
    if (!WebSocketManager.instance) {
      WebSocketManager.instance = new WebSocketManager();
    }
    return WebSocketManager.instance;
  }

  /**
   * 初始化 WebSocket 连接（支持多账号）
   * @param params 连接参数
   * @param setAsCurrent 是否设置为当前活跃账号（默认 true）
   */
  public async initWebSocketSafely(params: WebSocketParams, setAsCurrent = true): Promise<void> {
    if (!params?.userId || !params?.token) {
      return;
    }

    const userId = params.userId;

    // 检查该账号是否已有连接
    const existingConnection = this.connections.get(userId);
    if (existingConnection) {
      // 检查连接状态
      const currentStatus = await WebSocketApi.getStatus(userId);
      if (
        currentStatus === 'authenticated' &&
        existingConnection.authToken === params.token
      ) {
        // 已有有效连接，只需切换当前用户
        if (setAsCurrent) {
          this.currentUserId = userId;
          await WebSocketApi.setCurrentUser(userId);
        }
        return;
      }
      // token 变了或连接断开，需要重新连接
    }

    // 设置事件监听器（只需设置一次）
    if (this.eventUnlisteners.length === 0) {
      await this.setupEventListeners();
    }

    // 创建或更新连接信息
    const connectionInfo: ConnectionInfo = {
      authToken: params.token,
      userId: userId,
      desiredRooms: existingConnection?.desiredRooms ?? new Set(),
      status: 'connecting',
    };
    this.connections.set(userId, connectionInfo);

    // 连接 WebSocket
    try {
      await WebSocketApi.connect(params, apiConfig.WS_URL);
      connectionInfo.status = 'authenticated';

      // 设置当前活跃账号
      if (setAsCurrent) {
        this.currentUserId = userId;
        await WebSocketApi.setCurrentUser(userId);
      }
    } catch (error) {
      connectionInfo.status = 'disconnected';
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

    // 监听 WebSocket 事件（现在事件带有 user_id）
    const websocketUnlisten = await listen<UserEventWrapper>('websocket-event', (event) => {
      const wrapper = event.payload;
      // 解析事件：新格式带 user_id，旧格式需要兼容
      const userId = wrapper.user_id;

      // 调试日志：检查事件解析
      if (wrapper.type?.toLowerCase() === 'message') {
        console.log('[WebSocket setupEventListeners] 收到消息事件:', {
          wrapper_user_id: wrapper.user_id,
          wrapper_type: wrapper.type,
          payload_sender_id: wrapper.payload?.sender_id,
          raw_wrapper: JSON.stringify(wrapper).substring(0, 500),
        });
      }

      const eventPayload: TauriEventPayload = {
        type: wrapper.type,
        payload: wrapper.payload,
      };
      this.handleTauriEvent(eventPayload, userId);
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
   * @param payload 事件负载
   * @param eventUserId 事件所属的用户ID（多账号支持）
   */
  private handleTauriEvent(payload: TauriEventPayload, eventUserId?: string): void {
    const eventType = payload.type?.toLowerCase();
    // 判断事件是否来自当前活跃账号
    const isCurrentUser = !eventUserId || eventUserId === this.currentUserId;

    switch (eventType) {
      case 'authed': {
        const data = payload.payload as { user_id: string; conn_id: string };
        // 更新连接状态
        const userId = eventUserId || data.user_id;
        const connection = this.connections.get(userId);
        if (connection) {
          connection.status = 'authenticated';
        }
        // 只有当前账号才更新全局网络状态
        if (isCurrentUser) {
          store.commit('SET_NETWORK_STATE', true);
        }
        this.onAuthenticated(userId);
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
          // 消息事件携带 userId，用于多账号消息分发
          this.emitChatMessage(message, eventUserId);
        }
        break;
      }

      case 'messageread': {
        this.emitMessageRead(payload.payload, eventUserId);
        break;
      }

      case 'messageupdate': {
        this.emitMessageUpdate(payload.payload, eventUserId);
        break;
      }

      case 'pinupdate': {
        this.emitPinUpdate(payload.payload, eventUserId);
        break;
      }

      case 'reactionupdate':
      case 'reaction_update': {
        this.emitReactionUpdate(payload.payload, eventUserId);
        break;
      }

      case 'friendrequestupdate': {
        const data = payload.payload as { pending_count: number };
        if (typeof data.pending_count === 'number') {
          // 根据 eventUserId 更新对应账号的好友请求数
          const targetAccountId = eventUserId || this.currentUserId;
          const previousCount = targetAccountId
            ? this.friendRequestCounts.get(targetAccountId) ?? 0
            : 0;
          if (targetAccountId) {
            store.commit('accounts/UPDATE_FRIEND_REQUEST_COUNT', {
              accountId: targetAccountId,
              count: data.pending_count
            }, { root: true });
            this.friendRequestCounts.set(targetAccountId, data.pending_count);
          }
          // 只有当前账号才更新全局状态
          if (isCurrentUser) {
            store.commit('SET_PENDING_FRIEND_REQUESTS', data.pending_count);

            // 有新增好友请求时触发通知（声音 + 任务栏提醒）
            if (data.pending_count > previousCount) {
              NotificationApi.showNewMessageNotification();
            }
          }
        }
        break;
      }

      case 'friendshipdeleted':
      case 'friendship_deleted': {
        // 好友关系删除事件
        if (isCurrentUser) {
          const detail = ((payload as any)?.payload ?? payload) || {};
          const deletedUserId = detail.user_id ?? detail.userId;

          // 通知上层删除好友，兼容 legacy 监听器
          this.dispatchDomEvent('websocket-delete-friend', {
            userId: deletedUserId,
          });

          this.dispatchDomEvent('websocket-friend-change', {
            type: 'deleted',
            payload: {
              user_id: deletedUserId,
            },
          });

          // 刷新联系人和聊天列表
          this.refreshContacts();
          this.refreshChatList();
        }
        break;
      }

      case 'friendprofileupdated':
      case 'friend_profile_updated':
      case 'friend.updated': {
        // 好友资料变更事件（昵称 / 头像 等）
        // 仅当前活跃账号需要刷新本地联系人/会话列表
        if (isCurrentUser) {
          const detail = ((payload as any)?.payload ?? payload) || {};
          const userId = detail.user_id ?? detail.userId;

          // 向上层派发统一的好友变更事件，沿用 legacy 约定：
          // type: 'updated', payload: 好友最新资料
          this.dispatchDomEvent('websocket-friend-change', {
            type: 'updated',
            payload: {
              user_id: userId,
              username: detail.username,
              nickname: detail.nickname,
              avatar_url: detail.avatar_url ?? detail.avatarUrl,
              avatar_object_key: detail.avatar_object_key ?? detail.avatarObjectKey,
            },
          });

          // 更新全局用户资料映射，保证昵称 / 头像在所有视图中保持一致
          if (userId) {
            store.commit('UPSERT_USER_PROFILE', {
              userId: String(userId),
              username: detail.username ?? null,
              nickname: detail.nickname ?? null,
              avatarUrl: (detail.avatar_url ?? detail.avatarUrl) || null,
              avatarObjectKey: (detail.avatar_object_key ?? detail.avatarObjectKey) || null,
            });
          }

          // 静默刷新联系人列表，保证与后端数据完全对齐
          this.refreshContacts();
          // 同步刷新聊天列表，确保单聊会话名称 / 头像及时更新
          this.refreshChatList();
        }
        break;
      }

      case 'roomcreated': {
        const roomData = payload.payload as { room_id: string };
        // 修复：非当前账号也需要订阅新创建的房间
        if (eventUserId && roomData?.room_id) {
          this.ensureRoomsSubscribed([roomData.room_id], false, eventUserId);
        }

        // 只有当前账号才刷新聊天列表
        if (isCurrentUser) {
          this.dispatchDomEvent('websocket-room-created', payload.payload);
          this.refreshChatList();
        }
        break;
      }

      case 'error': {
        const data = payload.payload as { message: string };
        // 只显示当前账号的错误
        if (isCurrentUser) {
          const rawMessage = data.message || '';
          const normalized = rawMessage.trim().toLowerCase();
          // 后端在 WebSocket 鉴权失败时会返回 "unauthorized"
          // 这类错误前端已经通过 HTTP 401 处理登录态，这里不再额外弹 toast
          if (normalized === 'unauthorized') {
            // 静默处理，避免在进入主界面时出现多余的错误提示
          } else {
            toast.error(rawMessage || '消息服务错误');
          }
        }
        break;
      }

      case 'pong': {
        // 心跳响应，忽略
        break;
      }

      case 'userbanned':
      case 'user_banned': {
        const detail = ((payload as any)?.payload ?? payload) || {};
        const userId = eventUserId || (detail.user_id ?? detail.userId);
        const reason = detail.reason ?? '管理员封禁';

        console.log('收到用户封禁事件:', {
          userId,
          reason,
          currentUserId: this.currentUserId,
        });

        if (userId) {
          this.handleUserBanned(reason, userId);
        }
        break;
      }
      case 'groupdissolved':
      case 'group_dissolved': {
        const detail = ((payload as any)?.payload ?? payload) || {};
        const roomId = detail.room_id ?? detail.roomId;
        // 只有当前账号才处理群解散
        if (roomId && isCurrentUser) {
          this.handleGroupDissolved(roomId);
        }
        break;
      }
      case 'groupownertransferred':
      case 'group_owner_transferred': {
        const detail = ((payload as any)?.payload ?? payload) || {};
        const roomId = detail.room_id ?? detail.roomId;
        const newOwnerId = detail.new_owner_id ?? detail.newOwnerId;
        const oldOwnerId = detail.old_owner_id ?? detail.oldOwnerId;
        // 只有当前账号才处理群主转让
        if (roomId && newOwnerId && isCurrentUser) {
          this.handleGroupOwnerTransferred(roomId, newOwnerId, oldOwnerId);
        }
        break;
      }

      case 'groupsettingsupdated':
      case 'group_settings_updated': {
        // 只有当前账号才处理
        if (isCurrentUser) {
          const detail = ((payload as any)?.payload ?? payload) || {};
          this.dispatchDomEvent('websocket-group-settings-updated', {
            room_id: detail.room_id ?? detail.roomId,
            global_mute_enabled: detail.global_mute_enabled ?? detail.globalMuteEnabled,
            global_mute_reason: detail.global_mute_reason ?? detail.globalMuteReason,
            global_mute_until: detail.global_mute_until ?? detail.globalMuteUntil,
            global_mute_set_by: detail.global_mute_set_by ?? detail.globalMuteSetBy,
          });
        }
        break;
      }

      case 'groupmemberchanged':
      case 'group_member_changed': {
        // 只有当前账号才处理
        if (isCurrentUser) {
          const detail = ((payload as any)?.payload ?? payload) || {};
          this.dispatchDomEvent('websocket-group-member-changed', {
            room_id: detail.room_id ?? detail.roomId,
            member_id: detail.member_id ?? detail.memberId,
            change_type: detail.change_type ?? detail.changeType,
            new_role: detail.new_role ?? detail.newRole,
            operator_id: detail.operator_id ?? detail.operatorId,
            reason: detail.reason,
            until: detail.until,
          });
        }
        break;
      }

      case 'roomupdated':
      case 'room_updated': {
        // 只有当前账号才处理
        if (isCurrentUser) {
          const detail = ((payload as any)?.payload ?? payload) || {};
          this.dispatchDomEvent('websocket-room-updated', {
            room_id: detail.room_id ?? detail.roomId,
            room_name: detail.room_name ?? detail.roomName,
            room_type: detail.room_type ?? detail.roomType,
            avatar_url: detail.avatar_url ?? detail.avatarUrl,
            avatar_object_key: detail.avatar_object_key ?? detail.avatarObjectKey,
            description: detail.description,
          });
          this.refreshChatList();
        }
        break;
      }

      default:
        break;
    }
  }

  /**
   * 处理用户封禁事件
   * @param reason 封禁原因
   * @param bannedUserId 被封禁的用户ID
   */
  private handleUserBanned(reason: string, bannedUserId?: string): void {
    const userId = bannedUserId || this.currentUserId;
    console.warn('用户被封禁:', userId, reason);

    // 显示封禁提示
    toast.error(`账户已被封禁：${reason}`);

    // 获取当前账号信息
    const currentAccountId = (store.state as any).accounts?.currentAccountId;
    const allAccounts = (store.state as any).accounts?.accounts || [];

    if (!userId) {
      return;
    }

    // 查找被封禁的账号信息
    const bannedAccount = allAccounts.find((acc: any) =>
      acc.userInfo.id === userId || acc.id === userId
    );

    if (!bannedAccount) {
      return;
    }

    // 断开该账号的 WebSocket 连接
    this.connections.delete(userId);
    void WebSocketApi.disconnect(userId);

    // 检查是否为多账号模式
    if (allAccounts.length > 1) {
      // 多账号模式：移除被封禁的账号
      console.log('多账号模式，移除被封禁账号:', bannedAccount.id);
      void store.dispatch('accounts/removeAccount', bannedAccount.id);

      // 如果被封禁的是当前账号，切换到其他账号
      if (bannedAccount.id === currentAccountId) {
        const remainingAccounts = allAccounts.filter((acc: any) => acc.id !== bannedAccount.id);
        if (remainingAccounts.length > 0) {
          // 切换到第一个可用账号
          this.currentUserId = remainingAccounts[0].userInfo?.id || remainingAccounts[0].id;
          void store.dispatch('accounts/switchAccount', remainingAccounts[0].id);
        }
      }
    } else {
      // 单账号模式：直接登出并跳转登录页
      console.log('单账号模式，跳转登录页');
      this.currentUserId = null;
      void store.dispatch('logout');
      window.location.href = '/login';
    }
  }

  private handleGroupDissolved(roomId: string): void {
    if (!roomId) return;
    void store.dispatch('removeChatItem', roomId);
    // 从当前账号的房间订阅中移除
    const currentConnection = this.currentUserId ? this.connections.get(this.currentUserId) : null;
    if (currentConnection) {
      currentConnection.desiredRooms.delete(roomId);
    }
    this.leaveRoom(roomId);
    const currentGroupId = (store.state as any).currentChatGroupId;
    if (currentGroupId && currentGroupId === roomId) {
      store.commit('SET_CURRENT_CHAT_GROUP_ID', null);
    }
    toast.warning('有群聊已被解散');
    this.dispatchDomEvent('websocket-group-dissolved', { room_id: roomId });
  }

  private handleGroupOwnerTransferred(
    roomId: string,
    newOwnerId: string,
    oldOwnerId?: string,
  ): void {
    if (!roomId || !newOwnerId) return;
    const getter = (store.getters as any)?.getChatByGroupId;
    const chat = typeof getter === 'function' ? getter(roomId) : null;
    if (chat) {
      const updatedChat = {
        ...chat,
        extra: {
          ...(chat.extra || {}),
          owner_id: newOwnerId,
          ownerId: newOwnerId,
        },
      };
      void store.dispatch('updateChatItem', updatedChat);
    }

    if (newOwnerId === this.currentUserId) {
      toast.success('你已成为新的群主');
    } else if (oldOwnerId && oldOwnerId === this.currentUserId) {
      toast.info('群主已转让给其他成员');
    }

    this.dispatchDomEvent('websocket-group-owner-transferred', {
      room_id: roomId,
      new_owner_id: newOwnerId,
      old_owner_id: oldOwnerId,
    });
  }

  /**
   * 认证成功后的处理
   * @param userId 认证成功的用户ID
   */
  private onAuthenticated(userId?: string): void {
    // 只有当前账号才刷新数据
    const isCurrentUser = !userId || userId === this.currentUserId;
    if (isCurrentUser) {
      this.refreshAfterAuthenticated();
    }

    // 订阅待加入的房间
    this.flushPendingRooms(userId);
  }

  /**
   * 认证后刷新数据
   */
  private refreshAfterAuthenticated(): void {
    // 启动阶段：走一次完整数据刷新，但保持静默（使用骨架屏由视图决定）
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
    // WebSocket 触发的刷新统一采用静默模式：
    // - 有现有列表时不再切换到 loading，仅做智能合并
    // - 列表为空时由视图自行决定是否展示骨架屏
    void store.dispatch('loadChatList', {
      forceRefresh: false,
      compareWithStore: true,
    });
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
    // 同聊天列表，联系人列表也采用静默刷新策略
    void store.dispatch('loadContacts', {
      forceRefresh: false,
      compareWithStore: true,
    });
  }

  /**
   * 订阅待加入的房间
   * @param userId 指定用户ID，默认为当前用户
   */
  private flushPendingRooms(userId?: string): void {
    const targetUserId = userId || this.currentUserId;
    if (!targetUserId) return;

    const connection = this.connections.get(targetUserId);
    if (!connection || connection.desiredRooms.size === 0) {
      return;
    }

    const roomIds = Array.from(connection.desiredRooms);
    WebSocketApi.joinRooms(roomIds, targetUserId).catch(() => {});
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
   * @param rawMessage 原始消息
   * @param eventUserId 事件所属用户ID（多账号支持）
   */
  private emitChatMessage(rawMessage: any, eventUserId?: string): void {
    let normalized: Message | null = null;
    const userId = eventUserId || this.currentUserId;

    // 调试日志：检查 isSelf 判断
    console.log('[WebSocket emitChatMessage] 调试信息:', {
      eventUserId,
      currentUserId: this.currentUserId,
      resolvedUserId: userId,
      sender_id: rawMessage?.sender_id,
      isSelf: userId ? String(userId) === String(rawMessage?.sender_id) : false,
    });

    try {
      // 使用现有的消息转换函数
      normalized = transformBackendMessage(rawMessage, userId ?? undefined);
    } catch (error) {
      console.error('[WebSocket emitChatMessage] transformBackendMessage 错误:', error);
    }

    // 事件携带 userId，用于多账号消息分发和未读数更新
    this.dispatchDomEvent('websocket-chat-message', {
      message: normalized ?? rawMessage,
      raw: rawMessage,
      userId: eventUserId, // 携带用户ID，供上层处理
    });
  }

  /**
   * 发送消息已读事件
   */
  private emitMessageRead(raw: any, eventUserId?: string): void {
    const detail = { ...raw, userId: eventUserId };
    delete (detail as Record<string, unknown>).type;
    this.dispatchDomEvent('websocket-message-read', detail);
  }

  /**
   * 发送消息更新事件
   */
  private emitMessageUpdate(raw: any, eventUserId?: string): void {
    const userId = eventUserId || this.currentUserId;
    const detail: any = { ...raw, userId: eventUserId };
    delete detail.type;
    if (detail.message) {
      try {
        detail.message = transformBackendMessage(detail.message, userId ?? undefined);
      } catch (error) {
      }
    }
    this.dispatchDomEvent('websocket-message-update', detail);
  }

  /**
   * 发送置顶更新事件
   */
  private emitPinUpdate(raw: any, eventUserId?: string): void {
    const userId = eventUserId || this.currentUserId;
    const detail: any = { ...raw, userId: eventUserId };
    delete detail.type;
    if (detail.message) {
      try {
        detail.message = transformBackendMessage(detail.message, userId ?? undefined);
      } catch (error) {
      }
    }
    this.dispatchDomEvent('websocket-pin-update', detail);
  }

  /**
   * 发送反应更新事件
   */
  private emitReactionUpdate(raw: any, eventUserId?: string): void {
    const detail: any = { ...raw, userId: eventUserId };
    delete detail.type;
    this.dispatchDomEvent('websocket-reaction-update', detail);
  }

  /**
   * 确保房间已订阅
   * @param roomIds 房间ID列表
   * @param pruneMissing 是否清理多余的订阅
   * @param userId 指定用户ID，默认为当前用户
   */
  public ensureRoomsSubscribed(roomIds: Iterable<string>, pruneMissing = false, userId?: string): void {
    const targetUserId = userId || this.currentUserId;
    if (!targetUserId) return;

    const connection = this.connections.get(targetUserId);
    if (!connection) return;

    const normalized = new Set(
      Array.from(roomIds)
        .map((roomId) => roomId.trim())
        .filter((roomId) => roomId.length > 0),
    );

    // 添加到期望订阅列表
    normalized.forEach((roomId) => connection.desiredRooms.add(roomId));

    // 立即加入房间
    if (normalized.size > 0) {
      WebSocketApi.joinRooms(Array.from(normalized), targetUserId).catch((error) => {
      });
    }

    // 清理不需要的房间订阅
    if (pruneMissing) {
      WebSocketApi.getSubscribedRooms(targetUserId)
        .then((subscribedRooms) => {
          subscribedRooms.forEach((roomId) => {
            if (!normalized.has(roomId)) {
              this.leaveRoom(roomId, targetUserId);
            }
          });
        })
        .catch((error) => {
        });
    }
  }

  /**
   * 加入房间
   * @param roomId 房间ID
   * @param userId 指定用户ID，默认为当前用户
   */
  public joinRoom(roomId: string, userId?: string): void {
    if (!roomId) return;
    const targetUserId = userId || this.currentUserId;
    if (!targetUserId) return;

    const connection = this.connections.get(targetUserId);
    if (connection) {
      connection.desiredRooms.add(roomId);
    }
    WebSocketApi.joinRoom(roomId, targetUserId).catch((error) => {
    });
  }

  /**
   * 离开房间
   * @param roomId 房间ID
   * @param userId 指定用户ID，默认为当前用户
   */
  public leaveRoom(roomId: string, userId?: string): void {
    if (!roomId) return;
    const targetUserId = userId || this.currentUserId;
    if (!targetUserId) return;

    const connection = this.connections.get(targetUserId);
    if (connection) {
      connection.desiredRooms.delete(roomId);
    }
    WebSocketApi.leaveRoom(roomId, targetUserId).catch((error) => {
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
      currentUserId: this.currentUserId ?? undefined,
    });

    if (response.success && response.data) {
      callback?.(true);
      return response.data;
    }
  }

  /**
   * 关闭指定账号的 WebSocket 连接
   * @param userId 用户ID，如果不指定则关闭当前账号的连接
   */
  public async closeWebSocket(userId?: string): Promise<void> {
    const targetUserId = userId || this.currentUserId;

    if (targetUserId) {
      // 断开指定账号的连接
      this.connections.delete(targetUserId);
      await WebSocketApi.disconnect(targetUserId);

      // 如果关闭的是当前账号，更新网络状态
      if (targetUserId === this.currentUserId) {
        store.commit('SET_NETWORK_STATE', false);
      }
    } else {
      // 如果没有指定且没有当前用户，断开所有连接
      await this.closeAllWebSockets();
    }
  }

  /**
   * 关闭所有 WebSocket 连接
   */
  public async closeAllWebSockets(): Promise<void> {
    // 清理事件监听器
    this.eventUnlisteners.forEach((unlisten) => unlisten());
    this.eventUnlisteners = [];

    // 断开所有 WebSocket 连接
    await WebSocketApi.disconnectAll();

    // 清空状态
    this.connections.clear();
    this.currentUserId = null;

    store.commit('SET_NETWORK_STATE', false);
  }

  /**
   * 获取指定账号的连接状态
   * @param userId 用户ID，默认为当前用户
   */
  public async getConnectionState(userId?: string): Promise<boolean> {
    const targetUserId = userId || this.currentUserId;
    if (!targetUserId) return false;

    const status = await WebSocketApi.getStatus(targetUserId);
    return status === 'authenticated';
  }

  /**
   * 获取所有连接状态
   */
  public async getAllConnectionStates(): Promise<Record<string, ConnectionStatus>> {
    return await WebSocketApi.getAllStatus();
  }

  /**
   * 获取已连接的账号数量
   */
  public async getConnectedCount(): Promise<number> {
    return await WebSocketApi.getConnectedCount();
  }

  /**
   * 设置当前活跃账号
   * @param userId 用户ID
   */
  public async setCurrentUser(userId: string): Promise<void> {
    if (!userId) return;

    this.currentUserId = userId;
    await WebSocketApi.setCurrentUser(userId);

    // 更新网络状态
    const connection = this.connections.get(userId);
    if (connection) {
      store.commit('SET_NETWORK_STATE', connection.status === 'authenticated');
    }
  }

  /**
   * 获取当前活跃账号ID
   */
  public getCurrentUserId(): string | null {
    return this.currentUserId;
  }

  /**
   * 检查指定账号是否已连接
   * @param userId 用户ID
   */
  public isUserConnected(userId: string): boolean {
    const connection = this.connections.get(userId);
    return connection?.status === 'authenticated';
  }

  /**
   * 获取所有已连接的用户ID列表
   */
  public getConnectedUserIds(): string[] {
    const userIds: string[] = [];
    this.connections.forEach((connection, userId) => {
      if (connection.status === 'authenticated') {
        userIds.push(userId);
      }
    });
    return userIds;
  }
}

export const webSocketManager = WebSocketManager.getInstance();
