import { defineStore } from 'pinia';

import { appEnv } from '@/config/env';
import { avatarCacheService } from '@/services/avatar-cache';
import { avatarUploadService, validateAvatarFile } from '@/services/avatar-upload-service';
import { roomService } from '@/services/room-service';
import type { CreatedRoom, GroupSettingsInfo, RoomMember } from '@/types/room';

import { useChatStore } from './chat';

export const useGroupSettingsStore = defineStore('groupSettings', {
  state: () => ({
    roomId: '',
    room: null as CreatedRoom | null,
    members: [] as RoomMember[],
    settings: null as GroupSettingsInfo | null,
    draftName: '',
    muted: false,
    pinned: false,
    loading: false,
    submitting: false,
    avatarUploading: false,
    error: '',
    notice: '',
  }),
  actions: {
    async enterRoom(roomId: string) {
      if (!roomId) return;
      this.roomId = roomId;
      this.error = '';
      this.loading = true;
      const chat = useChatStore().chats.find((item) => item.roomId === roomId);
      this.pinned = Boolean(chat?.isPinned);

      if (appEnv.useMockData) {
        this.room = {
          id: roomId,
          name: chat?.name ?? 'H5 验收群',
          roomType: 'group',
          ownerId: 'mock-current',
        };
        this.members = createMockMembers();
        this.settings = createMockSettings(roomId);
        this.draftName = this.room.name;
        this.notice = '';
        this.loading = false;
        return;
      }

      try {
        const [room, members, settings] = await Promise.all([
          roomService.getRoom(roomId),
          roomService.listMembers(roomId),
          roomService.fetchGroupSettings(roomId),
        ]);
        this.room = room;
        this.members = members;
        this.settings = settings;
        this.draftName = room.name;
        this.notice = '';
      } catch (error) {
        this.error = error instanceof Error ? error.message : '加载群设置失败';
      } finally {
        this.loading = false;
      }
    },

    async updateName() {
      const name = this.draftName.trim();
      if (!this.roomId || !name || name === this.room?.name) return;
      this.submitting = true;
      this.error = '';
      const previous = this.room;
      this.room = previous ? { ...previous, name } : previous;
      try {
        if (!appEnv.useMockData) {
          this.room = await roomService.updateRoom(this.roomId, { name });
        }
        await useChatStore().refreshChats();
      } catch (error) {
        this.room = previous;
        this.draftName = previous?.name ?? this.draftName;
        this.error = error instanceof Error ? error.message : '更新群名称失败';
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    async uploadRoomAvatar(file: File | null | undefined) {
      if (!this.roomId || !file) return;
      const chatStore = useChatStore();
      const previousRoom = this.room;
      const previousChats = chatStore.chats.slice();
      this.avatarUploading = true;
      this.error = '';
      this.notice = '';
      try {
        validateAvatarFile(file);
        const uploaded = appEnv.useMockData
          ? {
              objectKey: `room_avatars/${this.roomId}/${Date.now()}-${file.name || 'avatar.png'}`,
              downloadUrl: null,
            }
          : await avatarUploadService.uploadRoomAvatar(this.roomId, file);
        const nextRoom: CreatedRoom = {
          ...(previousRoom ?? {
            id: this.roomId,
            name: this.draftName || '群聊',
            roomType: 'group',
          }),
          avatarUrl: uploaded.downloadUrl ?? previousRoom?.avatarUrl ?? null,
          avatarObjectKey: uploaded.objectKey,
        };
        this.room = nextRoom;
        await avatarCacheService.loadRoomAvatar({ roomId: this.roomId, objectKey: uploaded.objectKey });
        const currentSummary = chatStore.chats.find((chat) => chat.roomId === this.roomId);
        if (currentSummary) {
          await chatStore.upsertChatSummary({
            ...currentSummary,
            avatar: nextRoom.avatarUrl ?? currentSummary.avatar,
            avatarObjectKey: uploaded.objectKey,
          });
        }
        if (!appEnv.useMockData) {
          try {
            await chatStore.refreshChats();
          } catch (error) {
            console.warn('[h5-app] 群头像上传后刷新会话失败，已保留本地状态', error);
          }
        }
        this.notice = '群头像已更新';
      } catch (error) {
        this.room = previousRoom;
        chatStore.chats = previousChats;
        this.error = error instanceof Error ? error.message : '更新群头像失败';
        throw error;
      } finally {
        this.avatarUploading = false;
      }
    },

    async toggleMuted() {
      const nextMuted = !this.muted;
      const previous = this.muted;
      this.muted = nextMuted;
      this.error = '';
      try {
        if (!appEnv.useMockData && this.roomId) {
          await roomService.updateNotificationSettings(this.roomId, nextMuted ? 2 : 0);
        }
      } catch (error) {
        this.muted = previous;
        this.error = error instanceof Error ? error.message : '更新免打扰失败';
        throw error;
      }
    },

    async togglePinned() {
      const nextPinned = !this.pinned;
      this.pinned = nextPinned;
      this.error = '';
      try {
        await useChatStore().pinChat(this.roomId, nextPinned);
      } catch (error) {
        this.pinned = !nextPinned;
        this.error = error instanceof Error ? error.message : '更新置顶失败';
        throw error;
      }
    },

    async leaveRoom() {
      if (!this.roomId) return;
      this.submitting = true;
      this.error = '';
      try {
        if (!appEnv.useMockData) {
          await roomService.leaveRoom(this.roomId);
        }
        await useChatStore().removeRoom(this.roomId);
      } catch (error) {
        this.error = error instanceof Error ? error.message : '退出群聊失败';
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    async dissolveRoom() {
      if (!this.roomId) return;
      this.submitting = true;
      this.error = '';
      try {
        if (!appEnv.useMockData) {
          await roomService.dissolveRoom(this.roomId);
        }
        await useChatStore().removeRoom(this.roomId);
      } catch (error) {
        this.error = error instanceof Error ? error.message : '解散群聊失败';
        throw error;
      } finally {
        this.submitting = false;
      }
    },
  },
});

const createMockMembers = (): RoomMember[] => [
  {
    userId: 'mock-current',
    username: 'current@example.com',
    nickname: '我',
    role: 'owner',
  },
  {
    userId: 'mock-mia',
    username: 'mia@example.com',
    nickname: 'Mia',
    role: 'member',
  },
];

const createMockSettings = (roomId: string): GroupSettingsInfo => ({
  roomId,
  globalMuteEnabled: false,
  joinApprovalRequired: false,
  memberCanInvite: true,
  maxMembers: 500,
});
