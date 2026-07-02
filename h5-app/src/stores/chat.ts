import { defineStore } from 'pinia';

import { appEnv } from '@/config/env';
import { messageService } from '@/services/message-service';
import { roomService } from '@/services/room-service';
import { webSocketService, type WebSocketConnectionStatus, type WebSocketServerEvent } from '@/services/websocket-service';
import { ChatSummaryStorage } from '@/storage/chat-summary-storage';
import { MessageStorage } from '@/storage/message-storage';
import type { ChatMessage, ChatSummary, ChatType, MessageType } from '@/types/chat';

import { useAuthStore } from './auth';

let stopWsEvent: (() => void) | null = null;
let stopWsStatus: (() => void) | null = null;

const chatSummaryStorage = new ChatSummaryStorage();
const messageStorage = new MessageStorage();

export const useChatStore = defineStore('chat', {
  state: () => ({
    chats: [] as ChatSummary[],
    searchKeyword: '',
    loading: false,
    refreshing: false,
    cacheLoaded: false,
    initialized: false,
    error: '',
    websocketStatus: webSocketService.status as WebSocketConnectionStatus,
  }),
  getters: {
    filteredChats: (state) => {
      const keyword = state.searchKeyword.trim().toLowerCase();
      if (!keyword) return state.chats;
      return state.chats.filter((chat) => {
        const raw = chat.raw ?? {};
        const fields = [
          chat.name,
          chat.lastMessage,
          raw.friend_remark,
          raw.friend_nickname,
          raw.friend_username,
          raw.description,
        ];
        return fields.some((field) => String(field ?? '').toLowerCase().includes(keyword));
      });
    },
    unreadTotal: (state) => state.chats.reduce((sum, chat) => sum + chat.unreadCount, 0),
    isOffline: (state) => !appEnv.useMockData && state.websocketStatus !== 'authenticated',
  },
  actions: {
    async initialize() {
      if (this.initialized) return;
      this.initialized = true;
      this.bindWebSocket();
      await this.loadCachedChats();
      if (appEnv.useMockData) {
        if (this.chats.length === 0) {
          this.chats = createMockChats();
        }
        return;
      }
      await this.refreshChats();
      await this.connectWebSocket();
    },

    async loadCachedChats() {
      try {
        const cached = await chatSummaryStorage.loadChats();
        if (cached.length > 0) {
          this.chats = sortChats(cached);
        }
        this.cacheLoaded = true;
      } catch (error) {
        this.error = error instanceof Error ? error.message : '读取本地会话缓存失败';
      }
    },

    async refreshChats() {
      if (this.refreshing) return;
      this.refreshing = true;
      this.error = '';
      try {
        const chats = await messageService.fetchChats();
        this.chats = sortChats(chats);
        await chatSummaryStorage.saveChats(this.chats);
        this.syncWebSocketRooms();
      } catch (error) {
        this.error = error instanceof Error ? error.message : '加载会话失败';
      } finally {
        this.refreshing = false;
      }
    },

    async connectWebSocket() {
      try {
        await webSocketService.connect();
      } catch (error) {
        this.error = error instanceof Error ? error.message : 'WebSocket 连接失败';
      }
    },

    bindWebSocket() {
      if (!stopWsEvent) {
        stopWsEvent = webSocketService.onEvent((event) => {
          void this.handleWebSocketEvent(event);
        });
      }
      if (!stopWsStatus) {
        stopWsStatus = webSocketService.onStatus((status) => {
          this.websocketStatus = status;
          if (status === 'authenticated') {
            this.syncWebSocketRooms();
          }
        });
      }
      this.websocketStatus = webSocketService.status;
    },

    dispose() {
      stopWsEvent?.();
      stopWsStatus?.();
      stopWsEvent = null;
      stopWsStatus = null;
      webSocketService.disconnect();
      this.initialized = false;
      this.websocketStatus = webSocketService.status;
    },

    setSearchKeyword(keyword: string) {
      this.searchKeyword = keyword;
    },

    async deleteChat(roomId: string) {
      const previous = this.chats;
      this.chats = this.chats.filter((chat) => chat.roomId !== roomId);
      await chatSummaryStorage.saveChats(this.chats);
      try {
        await messageService.deleteChat(roomId);
      } catch (error) {
        this.chats = previous;
        await chatSummaryStorage.saveChats(this.chats);
        throw error;
      }
    },

    async pinChat(roomId: string, pinned: boolean) {
      const index = this.chats.findIndex((chat) => chat.roomId === roomId);
      if (index < 0 || this.chats[index]?.type === 'favorite') return;
      const previous = this.chats;
      this.chats = sortChats(
        this.chats.map((chat) => (chat.roomId === roomId ? { ...chat, isPinned: pinned } : chat)),
      );
      await chatSummaryStorage.saveChats(this.chats);
      try {
        await roomService.pinRoom(roomId, pinned);
      } catch (error) {
        this.chats = previous;
        await chatSummaryStorage.saveChats(this.chats);
        throw error;
      }
    },

    async handleWebSocketEvent(event: WebSocketServerEvent) {
      switch (event.type) {
        case 'message':
          await this.applyIncomingMessage(messageFromEvent(event, useAuthStore().currentUser?.id ?? ''));
          break;
        case 'room_updated':
          await this.applyRoomUpdated(event);
          break;
        case 'room_created':
          await this.refreshChats();
          break;
        case 'message_read':
          await this.applyMessageRead(event);
          break;
        case 'room_history_cleared':
        case 'group_dissolved':
          await this.removeRoom(String(event.room_id ?? ''));
          break;
        default:
          break;
      }
    },

    async applyIncomingMessage(message: ChatMessage) {
      if (!message.roomId || !message.id) return;
      const cachedMessages = await messageStorage.loadMessages(message.roomId);
      const alreadyCached = cachedMessages.some((item) => item.id === message.id);
      const nextMessages = mergeMessage(cachedMessages, message);
      await messageStorage.saveMessages(message.roomId, nextMessages);

      const index = this.chats.findIndex((chat) => chat.roomId === message.roomId);
      const isSelf = message.senderId === useAuthStore().currentUser?.id;
      if (index >= 0) {
        const current = this.chats[index];
        if (!current) return;
        const next: ChatSummary = {
          ...current,
          lastMessage: buildPreview(message),
          lastMessageTime: message.timestamp,
          unreadCount: isSelf || alreadyCached ? current.unreadCount : current.unreadCount + 1,
          raw: {
            ...current.raw,
            last_message_id: message.id,
          },
        };
        this.chats = sortChats([
          ...this.chats.slice(0, index),
          next,
          ...this.chats.slice(index + 1),
        ]);
      } else {
        this.chats = sortChats([
          ...this.chats,
          {
            id: message.roomId,
            roomId: message.roomId,
            name: message.senderName || '新会话',
            avatar: null,
            avatarObjectKey: null,
            lastMessage: buildPreview(message),
            lastMessageTime: message.timestamp,
            unreadCount: isSelf ? 0 : 1,
            type: 'private',
            isPinned: false,
            isMuted: false,
            raw: { last_message_id: message.id },
          },
        ]);
      }
      await chatSummaryStorage.saveChats(this.chats);
      this.syncWebSocketRooms();
    },

    async applyRoomUpdated(event: WebSocketServerEvent) {
      const roomId = String(event.room_id ?? '');
      if (!roomId) return;
      this.chats = sortChats(
        this.chats.map((chat) => {
          if (chat.roomId !== roomId) return chat;
          return {
            ...chat,
            name: String(event.room_name ?? chat.name),
            avatar: event.avatar_url == null ? chat.avatar : String(event.avatar_url),
            avatarObjectKey: event.avatar_object_key == null ? chat.avatarObjectKey : String(event.avatar_object_key),
            type: normalizeChatType(event.room_type ?? chat.type),
            raw: { ...chat.raw, ...event },
          };
        }),
      );
      await chatSummaryStorage.saveChats(this.chats);
    },

    async applyMessageRead(event: WebSocketServerEvent) {
      const roomId = String(event.room_id ?? '');
      const readerId = String(event.reader_id ?? '');
      if (!roomId || readerId !== useAuthStore().currentUser?.id) return;
      this.chats = this.chats.map((chat) => (
        chat.roomId === roomId ? { ...chat, unreadCount: 0 } : chat
      ));
      await chatSummaryStorage.saveChats(this.chats);
    },

    async removeRoom(roomId: string) {
      if (!roomId) return;
      this.chats = this.chats.filter((chat) => chat.roomId !== roomId);
      await chatSummaryStorage.saveChats(this.chats);
      await messageStorage.clear(roomId);
      this.syncWebSocketRooms();
    },

    syncWebSocketRooms() {
      webSocketService.ensureRoomsSubscribed(
        this.chats
          .filter((chat) => chat.type !== 'favorite')
          .map((chat) => chat.roomId),
        { pruneMissing: true },
      );
    },
  },
});

export const sortChats = (chats: ChatSummary[]) => chats
  .slice()
  .sort((a, b) => Number(b.isPinned) - Number(a.isPinned)
    || Number(a.type !== 'favorite') - Number(b.type !== 'favorite')
    || b.lastMessageTime - a.lastMessageTime);

export const formatChatDisplayTime = (timestamp: number, now = new Date()) => {
  if (!Number.isFinite(timestamp) || timestamp <= 0) return '';
  const time = new Date(timestamp);
  const sameDay = time.getFullYear() === now.getFullYear()
    && time.getMonth() === now.getMonth()
    && time.getDate() === now.getDate();
  const diffMs = now.getTime() - time.getTime();
  if (diffMs >= 0 && diffMs < 60_000) return '刚刚';
  if (sameDay) return `${pad(time.getHours())}:${pad(time.getMinutes())}`;
  const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
  if (
    time.getFullYear() === yesterday.getFullYear()
    && time.getMonth() === yesterday.getMonth()
    && time.getDate() === yesterday.getDate()
  ) {
    return '昨天';
  }
  if (time.getFullYear() === now.getFullYear()) {
    return `${time.getMonth() + 1}月${time.getDate()}日`;
  }
  return `${time.getFullYear()}/${pad(time.getMonth() + 1)}/${pad(time.getDate())}`;
};

const messageFromEvent = (event: WebSocketServerEvent, currentUserId: string): ChatMessage => ({
  id: String(event.message_id ?? event.id ?? ''),
  roomId: String(event.room_id ?? ''),
  senderId: String(event.sender_id ?? ''),
  senderName: String(event.sender_nickname ?? event.sender_username ?? event.sender_id ?? ''),
  content: String(event.content ?? ''),
  type: normalizeMessageType(event.message_type),
  timestamp: parseTimestamp(event.timestamp),
  status: event.sender_id === currentUserId ? 'sent' : undefined,
  isDeleted: Boolean(event.is_deleted ?? false),
  raw: event,
});

const mergeMessage = (messages: ChatMessage[], message: ChatMessage) => {
  const index = messages.findIndex((item) => item.id === message.id);
  if (index < 0) {
    return [...messages, message].sort((a, b) => a.timestamp - b.timestamp);
  }
  return [
    ...messages.slice(0, index),
    { ...messages[index], ...message },
    ...messages.slice(index + 1),
  ].sort((a, b) => a.timestamp - b.timestamp);
};

const buildPreview = (message: ChatMessage) => {
  if (message.isDeleted) return '[消息已删除]';
  const content = message.content.trim();
  if (content) return content;
  switch (message.type) {
    case 'image':
      return '[图片]';
    case 'audio':
      return '[语音]';
    case 'video':
      return '[视频]';
    case 'file':
      return '[文件]';
    case 'mixed':
      return '[多媒体消息]';
    case 'system':
      return '[系统消息]';
    case 'text':
    default:
      return '[消息]';
  }
};

const normalizeMessageType = (value: unknown): MessageType => {
  const normalized = String(value ?? 'text');
  if (['text', 'image', 'audio', 'video', 'file', 'system', 'mixed'].includes(normalized)) {
    return normalized as MessageType;
  }
  return 'text';
};

const normalizeChatType = (value: unknown): ChatType => {
  const normalized = String(value ?? 'private').toLowerCase();
  if (normalized === 'group' || normalized === 'public') return 'group';
  if (normalized === 'favorite') return 'favorite';
  return 'private';
};

const parseTimestamp = (value: unknown) => {
  if (typeof value === 'number') return value > 1_000_000_000_000 ? value : value * 1000;
  if (typeof value === 'string' && value) {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : Date.now();
  }
  return Date.now();
};

const pad = (value: number) => value.toString().padStart(2, '0');

const createMockChats = (): ChatSummary[] => sortChats([
  {
    id: 'favorite',
    roomId: 'favorite',
    name: '收藏',
    avatar: null,
    avatarObjectKey: null,
    lastMessage: '保存的消息和文件会出现在这里',
    lastMessageTime: Date.now(),
    unreadCount: 0,
    type: 'favorite',
    isPinned: true,
    isMuted: false,
  },
  {
    id: 'mock-team',
    roomId: 'mock-team',
    name: 'RedCode IM 项目组',
    avatar: null,
    avatarObjectKey: null,
    lastMessage: 'H5 App 已接入真实聊天列表和 WebSocket 状态',
    lastMessageTime: Date.now(),
    unreadCount: 2,
    type: 'group',
    isPinned: false,
    isMuted: false,
  },
]);
