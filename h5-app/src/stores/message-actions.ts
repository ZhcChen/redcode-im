import { defineStore } from 'pinia';

import { messageService } from '@/services/message-service';
import { roomService } from '@/services/room-service';
import type { MessageReader, MessageReceiptMember } from '@/types/chat';

import { useChatStore } from './chat';

export interface ForwardResult {
  succeeded: string[];
  failed: string[];
}

export const useMessageActionsStore = defineStore('messageActions', {
  state: () => ({
    readers: [] as MessageReader[],
    members: [] as MessageReceiptMember[],
    senderId: '',
    loadingReaders: false,
    forwarding: false,
    error: '',
    notice: '',
  }),
  getters: {
    eligibleReaders: (state) => state.readers.filter((reader) => reader.userId !== state.senderId),
    unreadMembers: (state) => {
      const readIds = new Set(state.readers.map((reader) => reader.userId));
      return state.members.filter((member) => member.userId !== state.senderId && !readIds.has(member.userId));
    },
  },
  actions: {
    async loadReaders(roomId: string, messageId: string, senderId = '') {
      this.readers = [];
      this.members = [];
      this.senderId = senderId;
      this.error = '';
      if (!roomId || !messageId) {
        this.error = '消息参数无效';
        return;
      }
      this.loadingReaders = true;
      try {
        const [readers, members] = await Promise.all([
          messageService.fetchMessageReaders(roomId, messageId),
          roomService.listMembers(roomId),
        ]);
        this.readers = readers.slice().sort((a, b) => a.readAt - b.readAt);
        this.members = members.map((member) => ({
          userId: member.userId,
          username: member.username ?? '',
          nickname: member.nickname ?? null,
          avatarUrl: null,
        }));
      } catch (error) {
        this.error = error instanceof Error ? error.message : '加载已读成员失败';
      } finally {
        this.loadingReaders = false;
      }
    },

    async forwardMessage(messageId: string, targetRoomIds: string[]): Promise<ForwardResult> {
      const targets = [...new Set(targetRoomIds.filter(Boolean))];
      const result: ForwardResult = { succeeded: [], failed: [] };
      this.error = '';
      this.notice = '';
      if (!messageId || targets.length === 0) return result;

      this.forwarding = true;
      try {
        for (const roomId of targets) {
          try {
            await messageService.forwardMessage(roomId, messageId);
            result.succeeded.push(roomId);
          } catch {
            result.failed.push(roomId);
          }
        }
        if (result.succeeded.length > 0) {
          try {
            await useChatStore().refreshChats();
          } catch {
            // 转发已经由服务端确认，会话列表可在下次刷新时恢复。
          }
          this.notice = `已转发到 ${result.succeeded.length} 个会话`;
        }
        if (result.failed.length > 0) {
          this.error = `${result.failed.length} 个会话转发失败，请重试`;
        }
        return result;
      } finally {
        this.forwarding = false;
      }
    },

    reset() {
      this.readers = [];
      this.members = [];
      this.senderId = '';
      this.loadingReaders = false;
      this.forwarding = false;
      this.error = '';
      this.notice = '';
    },
  },
});
