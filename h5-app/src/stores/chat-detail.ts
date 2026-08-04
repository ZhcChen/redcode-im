import { defineStore } from 'pinia';

import { appEnv } from '@/config/env';
import { ApiError } from '@/api/http';
import { e2eeDirectMessageCoordinator } from '@/e2ee/direct-message-coordinator';
import { mapMessage, mapWebSocketMessage, messageService } from '@/services/message-service';
import { messageAttachmentUploadService, type BrowserAttachmentType } from '@/services/message-attachment-upload-service';
import { settingsService } from '@/services/settings-service';
import { webSocketService, type WebSocketServerEvent } from '@/services/websocket-service';
import { MessageStorage } from '@/storage/message-storage';
import type { ChatMessage, ChatMessageQuote, ChatSummary, OutgoingMessagePart } from '@/types/chat';

import { useAuthStore } from './auth';
import { useChatStore } from './chat';
import { useMessageSearchStore } from './message-search';

const messageStorage = new MessageStorage();

let stopWsEvent: (() => void) | null = null;
let attachmentAbortController: AbortController | null = null;

export const useChatDetailStore = defineStore('chatDetail', {
  state: () => ({
    roomId: '',
    chat: null as ChatSummary | null,
    messages: [] as ChatMessage[],
    loading: false,
    sending: false,
    uploadingAttachment: false,
    failedAttachment: null as { file: File; type: BrowserAttachmentType } | null,
    error: '',
    quotedMessage: null as ChatMessage | null,
  }),
  getters: {
    title: (state) => state.chat?.name || '聊天',
    canSend: (state) => Boolean(state.roomId) && !state.sending,
  },
  actions: {
    async enterRoom(roomId: string, chat?: ChatSummary | null) {
      if (!roomId) return;
      this.bindWebSocket();
      this.roomId = roomId;
      this.chat = chat ?? useChatStore().chats.find((item) => item.roomId === roomId) ?? null;
      this.error = '';
      this.loading = true;
      webSocketService.ensureRoomsSubscribed([roomId]);

      try {
        const cached = await this.loadCachedMessages(roomId);
        if (cached.length > 0) {
          this.messages = cached;
        }

        if (appEnv.useMockData) {
          if (this.messages.length === 0) {
            this.messages = createMockMessages(roomId, useAuthStore().currentUser?.id ?? '');
          }
          await this.persist();
          return;
        }

        const remote = await messageService.loadMessages(
          roomId,
          { limit: 50 },
          useAuthStore().currentUser?.id,
        );
        this.messages = mergeMessages(this.messages, remote);
        await this.persist();
        await this.syncReadState();
      } catch (error) {
        this.error = error instanceof Error ? error.message : '加载消息失败';
      } finally {
        this.loading = false;
      }
    },

    leaveRoom() {
      this.roomId = '';
      this.chat = null;
      this.messages = [];
      this.loading = false;
      this.sending = false;
      this.uploadingAttachment = false;
      this.failedAttachment = null;
      attachmentAbortController?.abort();
      attachmentAbortController = null;
      this.error = '';
      this.quotedMessage = null;
    },

    bindWebSocket() {
      if (stopWsEvent) return;
      stopWsEvent = webSocketService.onEvent((event) => {
        void this.handleWebSocketEvent(event);
      });
    },

    dispose() {
      stopWsEvent?.();
      stopWsEvent = null;
      this.leaveRoom();
    },

    async sendText(content: string) {
      const text = content.trim();
      if (!text || !this.roomId) return;
      const quote = this.quotedMessage ? toMessageQuote(this.quotedMessage) : null;
      const accountId = useAuthStore().currentUser?.id ?? '';
      let e2eePending = false;
      try {
        if (!appEnv.useMockData) {
          const runtime = (await settingsService.fetchGeneralSettings()).messageRuntime;
          if (runtime.contentAuditMode === 'e2ee') {
            if (quote) throw new Error('E2EE 引用消息将在后续版本支持');
            const peerUserId = privatePeerUserId(this.chat);
            if (!peerUserId) throw new Error('当前会话缺少 E2EE 联系人标识');
            await e2eeDirectMessageCoordinator.prepareText({
              accountId,
              deviceLabel: 'RedCode H5',
              roomId: this.roomId,
              peerUserId,
              text,
            });
            e2eePending = true;
          }
        }
      } catch (error) {
        this.error = error instanceof Error ? error.message : '发送准备失败';
        throw error;
      }
      const pending = createPendingMessage(this.roomId, text, accountId, quote, e2eePending);
      this.quotedMessage = null;
      await this.upsertLocalMessage(pending);
      await this.flushPendingMessage(pending.id, text, quote?.id);
    },

    async sendAttachment(file: File, type: BrowserAttachmentType) {
      if (!this.roomId || this.uploadingAttachment) return;
      this.error = '';
      this.failedAttachment = null;
      this.uploadingAttachment = true;
      attachmentAbortController = new AbortController();
      try {
        if (!appEnv.useMockData) {
          const runtime = (await abortable(
            settingsService.fetchGeneralSettings(),
            attachmentAbortController.signal,
          )).messageRuntime;
          if (runtime.contentAuditMode === 'e2ee') {
            throw new Error('E2EE 附件将在后续版本支持');
          }
        }
        const part = appEnv.useMockData
          ? { type, key: `messages/${this.roomId}/${type}/${file.name}`, name: file.name, mimeType: file.type, size: file.size }
          : await messageAttachmentUploadService.upload(this.roomId, file, type, attachmentAbortController.signal);
        const sent = appEnv.useMockData
          ? mockSentAttachment(this.roomId, part, useAuthStore().currentUser?.id ?? '')
          : await messageService.sendRichMessage(this.roomId, [part], {
              quotedMessageId: this.quotedMessage?.id,
            });
        this.quotedMessage = null;
        await this.upsertLocalMessage({ ...sent, status: 'sent' });
        await useChatStore().applyIncomingMessage({ ...sent, status: 'sent' });
      } catch (error) {
        if (error instanceof DOMException && error.name === 'AbortError') {
          this.error = '已取消附件发送';
        } else {
          this.failedAttachment = { file, type };
          this.error = error instanceof Error ? error.message : '附件发送失败';
        }
      } finally {
        this.uploadingAttachment = false;
        attachmentAbortController = null;
      }
    },

    cancelAttachmentUpload() {
      attachmentAbortController?.abort();
    },

    async retryAttachment() {
      const failed = this.failedAttachment;
      if (!failed) return;
      await this.sendAttachment(failed.file, failed.type);
    },

    quoteMessage(messageId: string) {
      const message = this.messages.find((item) => item.id === messageId && !item.isDeleted);
      if (!message) return;
      this.quotedMessage = message;
    },

    clearQuote() {
      this.quotedMessage = null;
    },

    async resendMessage(messageId: string) {
      const failed = this.messages.find((message) => message.id === messageId && message.status === 'failed');
      if (!failed) return;
      if (failed.e2eeDecryptionFailed) {
        const resolved = await messageService.retryEncryptedMessage(
          failed,
          useAuthStore().currentUser?.id ?? '',
        );
        await this.upsertLocalMessage(resolved);
        return;
      }
      await this.flushPendingMessage(failed.id, failed.content, failed.quotedMessage?.id);
    },

    async handleWebSocketEvent(event: WebSocketServerEvent) {
      if (event.type === 'message') {
        const messageId = String(event.message_id ?? event.id ?? '');
        if (!messageId || this.messages.some((message) => message.id === messageId)) return;
        const accountId = useAuthStore().currentUser?.id ?? '';
        let message = mapWebSocketMessage(event);
        const pending = message.senderId === accountId && message.encryptedContent
          ? this.messages.find((item) => item.raw?.e2ee_pending === true)
          : null;
        if (pending) {
          message = { ...message, content: pending.content, status: 'sent' };
          this.messages = this.messages.filter((item) => item.id !== pending.id);
        } else {
          message = await messageService.resolveEncryptedMessage(message, accountId);
        }
        if (!message.id || message.roomId !== this.roomId) return;
        await this.upsertLocalMessage(message);
        await this.syncReadState();
        return;
      }
      if (event.type === 'message_update') {
        await this.applyMessageUpdate(event);
        return;
      }
      if (event.type === 'message_read') {
        await this.applyReadReceipt(event);
        return;
      }
      if (event.type === 'pin_update') {
        await this.applyPinUpdate(event);
      }
    },

    async upsertLocalMessage(message: ChatMessage) {
      const nextMessages = mergeMessages(this.messages, [message]);
      await this.persist(nextMessages);
      this.messages = nextMessages;
    },

    async flushPendingMessage(localId: string, content: string, quotedMessageId?: string) {
      if (!this.roomId) return;
      this.sending = true;
      this.error = '';
      this.messages = this.messages.map((message) => (
        message.id === localId ? { ...message, status: 'sending' } : message
      ));
      await this.persist();

      try {
        const pending = this.messages.find((message) => message.id === localId);
        const isE2eePending = pending?.raw?.e2ee_pending === true;
        const sent = appEnv.useMockData
          ? mockSentMessage(this.roomId, content, useAuthStore().currentUser?.id ?? '', quotedMessageId)
          : isE2eePending
            ? mapMessage(
                responseMessage(await e2eeDirectMessageCoordinator.retryPendingSend(
                  useAuthStore().currentUser?.id ?? '',
                )),
                this.roomId,
              )
            : await messageService.sendTextMessage(this.roomId, content, quotedMessageId);
        const visibleSent = isE2eePending ? { ...sent, content } : sent;
        this.messages = mergeMessages(
          this.messages.filter((message) => message.id !== localId),
          [{ ...visibleSent, status: 'sent' }],
        );
        await this.persist();
        await useChatStore().applyIncomingMessage({ ...visibleSent, status: 'sent' });
      } catch (error) {
        if (isMessageRuntimeConflict(error)) {
          await settingsService.fetchGeneralSettings();
        }
        this.messages = this.messages.map((message) => (
          message.id === localId ? { ...message, status: 'failed' } : message
        ));
        this.error = error instanceof Error ? error.message : '发送失败';
        await this.persist();
      } finally {
        this.sending = false;
      }
    },

    async deleteMessage(messageId: string) {
      if (!this.roomId || !messageId) return;
      const previous = this.messages;
      this.messages = this.messages.map((message) => (
        message.id === messageId
          ? { ...message, isDeleted: true, status: 'deleted', content: '' }
          : message
      ));
      await this.persist();
      try {
        if (!appEnv.useMockData && !messageId.startsWith('local-')) {
          await messageService.deleteMessage(this.roomId, messageId);
        }
      } catch (error) {
        this.messages = previous;
        this.error = error instanceof Error ? error.message : '删除消息失败';
        await this.persist();
      }
    },

    async setMessagePinned(messageId: string, pinned: boolean) {
      if (!this.roomId || !messageId) return;
      const previous = this.messages;
      this.messages = this.messages.map((message) => (
        message.id === messageId
          ? {
              ...message,
              isPinned: pinned,
              pinnedAt: pinned ? Date.now() : null,
              pinnedBy: pinned ? useAuthStore().currentUser?.id ?? null : null,
            }
          : message
      ));
      await this.persist();
      try {
        if (!appEnv.useMockData && !messageId.startsWith('local-')) {
          await messageService.pinMessage(this.roomId, messageId, pinned);
        }
      } catch (error) {
        this.messages = previous;
        this.error = error instanceof Error ? error.message : (pinned ? '置顶消息失败' : '取消置顶失败');
        await this.persist();
      }
    },

    async applyMessageUpdate(event: WebSocketServerEvent) {
      const roomId = String(event.room_id ?? '');
      const messageId = String(event.message_id ?? '');
      if (!messageId || roomId !== this.roomId) return;
      this.messages = this.messages.map((message) => (
        message.id === messageId
          ? {
              ...message,
              isDeleted: Boolean(event.is_deleted ?? message.isDeleted),
              status: event.is_deleted ? 'deleted' : message.status,
              content: event.is_deleted ? '' : message.content,
            }
          : message
      ));
      await this.persist();
    },

    async applyReadReceipt(event: WebSocketServerEvent) {
      const roomId = String(event.room_id ?? '');
      const messageId = String(event.message_id ?? '');
      const readerId = String(event.reader_id ?? '');
      if (!messageId || roomId !== this.roomId || readerId === useAuthStore().currentUser?.id) return;
      const targetIndex = this.messages.findIndex((message) => message.id === messageId);
      if (targetIndex < 0) return;
      const currentUserId = useAuthStore().currentUser?.id;
      this.messages = this.messages.map((message, index) => (
        index <= targetIndex && message.senderId === currentUserId && !message.isDeleted
          ? { ...message, status: 'read' }
          : message
      ));
      await this.persist();
    },

    async applyPinUpdate(event: WebSocketServerEvent) {
      const roomId = String(event.room_id ?? '');
      const messageId = String(event.message_id ?? '');
      if (!messageId || roomId !== this.roomId) return;
      this.messages = this.messages.map((message) => (
        message.id === messageId
          ? {
              ...message,
              isPinned: Boolean(event.is_pinned ?? false),
              pinnedAt: parseOptionalTimestamp(event.pinned_at),
              pinnedBy: event.pinned_by == null ? null : String(event.pinned_by),
            }
          : message
      ));
      await this.persist();
    },

    async syncReadState() {
      const currentUserId = useAuthStore().currentUser?.id;
      if (!this.roomId || !currentUserId) return;
      const latestIncoming = this.messages
        .filter((message) => message.senderId !== currentUserId && !message.isDeleted)
        .at(-1);
      if (!latestIncoming) return;
      try {
        await messageService.markMessagesAsRead(this.roomId, latestIncoming.id);
        await useChatStore().applyMessageRead({
          type: 'message_read',
          room_id: this.roomId,
          message_id: latestIncoming.id,
          reader_id: currentUserId,
        });
      } catch {
        // 已读同步不能阻塞消息浏览。
      }
    },

    async persist(messages?: ChatMessage[]) {
      if (!this.roomId) return;
      const snapshot = messages ?? this.messages;
      try {
        await messageStorage.saveMessages(this.roomId, snapshot);
      } catch (error) {
        console.warn('[h5-app] 消息本地缓存写入失败，已忽略', error);
      }
      try {
        await useMessageSearchStore().replaceRoomIndex({
          roomId: this.roomId,
          roomName: this.chat?.name || useChatStore().chats.find((item) => item.roomId === this.roomId)?.name || '聊天',
          messages: snapshot,
        });
      } catch (error) {
        console.warn('[h5-app] 消息搜索索引写入失败，已忽略', error);
      }
    },

    async loadCachedMessages(roomId: string) {
      try {
        return await messageStorage.loadMessages(roomId);
      } catch (error) {
        console.warn('[h5-app] 消息本地缓存读取失败，已忽略', error);
        return [];
      }
    },

    async loadUntilFound(messageId: string, maxPages = 10): Promise<boolean> {
      if (!messageId || !this.roomId) return false;
      if (this.messages.some((message) => message.id === messageId)) return true;
      if (appEnv.useMockData) return false;

      for (let page = 0; page < maxPages; page += 1) {
        const beforeId = this.messages[0]?.id;
        if (!beforeId) return false;
        const previousIds = new Set(this.messages.map((message) => message.id));
        const older = await messageService.loadMessages(
          this.roomId,
          { limit: 50, beforeId },
          useAuthStore().currentUser?.id,
        );
        if (older.length === 0) return false;
        this.messages = mergeMessages(this.messages, older);
        await this.persist();
        if (this.messages.some((message) => message.id === messageId)) return true;
        if (older.every((message) => previousIds.has(message.id))) return false;
      }
      return false;
    },
  },
});

export const mergeMessages = (current: ChatMessage[], incoming: ChatMessage[]) => {
  const byId = new Map<string, ChatMessage>();
  for (const message of current) {
    if (message.id) byId.set(message.id, message);
  }
  for (const message of incoming) {
    if (!message.id) continue;
    for (const [id, pending] of byId.entries()) {
      const matchesPending = id.startsWith('local-')
        && pending.roomId === message.roomId
        && pending.senderId === message.senderId
        && pending.content === message.content
        && (pending.quotedMessage?.id ?? '') === (message.quotedMessage?.id ?? '');
      if (matchesPending) {
        byId.delete(id);
      }
    }
    const previous = byId.get(message.id);
    byId.set(message.id, previous ? { ...previous, ...message } : message);
  }
  return [...byId.values()].sort((a, b) => a.timestamp - b.timestamp);
};

const createPendingMessage = (
  roomId: string,
  content: string,
  currentUserId: string,
  quotedMessage?: ChatMessageQuote | null,
  e2eePending = false,
): ChatMessage => ({
  id: `local-${Date.now()}-${Math.random().toString(16).slice(2)}`,
  roomId,
  senderId: currentUserId,
  senderName: '我',
  content,
  type: 'text',
  timestamp: Date.now(),
  status: 'sending',
  quotedMessage,
  raw: e2eePending ? { e2ee_pending: true } : undefined,
});

const privatePeerUserId = (chat: ChatSummary | null) => {
  if (chat?.type !== 'private') return null;
  const value = chat.raw?.friend_user_id ?? chat.raw?.friendUserId;
  return typeof value === 'string' && value.trim() ? value.trim() : null;
};

const responseMessage = (response: Record<string, unknown>) => {
  const message = response.message;
  if (!message || typeof message !== 'object' || Array.isArray(message)) {
    throw new Error('E2EE 消息响应格式无效');
  }
  return message as Record<string, unknown>;
};

const isMessageRuntimeConflict = (error: unknown) => {
  if (!(error instanceof ApiError) || error.status !== 409) return false;
  if (!error.payload || typeof error.payload !== 'object' || Array.isArray(error.payload)) return false;
  return Number((error.payload as Record<string, unknown>).code) === 40902;
};

const abortable = <T>(operation: Promise<T>, signal: AbortSignal): Promise<T> => {
  if (signal.aborted) return Promise.reject(new DOMException('Aborted', 'AbortError'));
  return new Promise<T>((resolve, reject) => {
    const onAbort = () => reject(new DOMException('Aborted', 'AbortError'));
    signal.addEventListener('abort', onAbort, { once: true });
    operation.then(resolve, reject).finally(() => signal.removeEventListener('abort', onAbort));
  });
};
const toMessageQuote = (message: ChatMessage): ChatMessageQuote => ({
  id: message.id,
  roomId: message.roomId,
  senderId: message.senderId,
  senderName: message.senderName,
  content: message.content,
  type: message.type,
  timestamp: message.timestamp,
  isDeleted: message.isDeleted,
});

const parseTimestamp = (value: unknown) => {
  if (typeof value === 'number') return value > 1_000_000_000_000 ? value : value * 1000;
  if (typeof value === 'string' && value) {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : Date.now();
  }
  return Date.now();
};

const parseOptionalTimestamp = (value: unknown) => {
  if (value === null || value === undefined || value === '') return null;
  return parseTimestamp(value);
};

const createMockMessages = (roomId: string, currentUserId: string): ChatMessage[] => [
  {
    id: `mock-${roomId}-1`,
    roomId,
    senderId: 'mock-teammate',
    senderName: 'RedCode',
    content: 'H5 聊天详情已接入本地缓存和发送状态。',
    type: 'text',
    timestamp: Date.now() - 90_000,
    status: 'sent',
  },
  {
    id: `mock-${roomId}-2`,
    roomId,
    senderId: currentUserId,
    senderName: '我',
    content: '收到，继续做联调验收。',
    type: 'text',
    timestamp: Date.now() - 30_000,
    status: 'sent',
  },
];

const mockSentMessage = (
  roomId: string,
  content: string,
  currentUserId: string,
  quotedMessageId?: string,
): ChatMessage => ({
  id: `mock-sent-${Date.now()}-${Math.random().toString(16).slice(2)}`,
  roomId,
  senderId: currentUserId,
  senderName: '我',
  content,
  type: 'text',
  timestamp: Date.now(),
  status: 'sent',
  quotedMessage: quotedMessageId
    ? {
        id: quotedMessageId,
        roomId,
        senderId: '',
        senderName: '',
        content: '引用消息',
        type: 'text',
      }
    : null,
});

const mockSentAttachment = (
  roomId: string,
  part: OutgoingMessagePart,
  currentUserId: string,
): ChatMessage => ({
  id: `mock-sent-${Date.now()}-${Math.random().toString(16).slice(2)}`,
  roomId,
  senderId: currentUserId,
  senderName: '我',
  content: '',
  type: part.type,
  timestamp: Date.now(),
  status: 'sent',
  attachments: part.key ? [{
    key: part.key,
    name: part.name,
    mimeType: part.mimeType,
    size: part.size,
    cacheKey: `message:${part.key}`,
  }] : [],
});
