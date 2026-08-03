import { defineStore } from 'pinia';

import { appEnv } from '@/config/env';
import { friendService } from '@/services/friend-service';
import { roomService } from '@/services/room-service';
import { webSocketService, type WebSocketServerEvent } from '@/services/websocket-service';
import { ContactStorage, compareFriend, displayName } from '@/storage/contact-storage';
import type { AuthUser } from '@/types/auth';
import type { ChatSummary } from '@/types/chat';
import type { FriendInfo, FriendRequestAction, FriendRequestInfo } from '@/types/friend';
import type { CreatedRoom } from '@/types/room';

import { useAppShellStore } from './app-shell';
import { useChatStore } from './chat';

const contactStorage = new ContactStorage();

let stopWsEvent: (() => void) | null = null;

export const useContactsStore = defineStore('contacts', {
  state: () => ({
    friends: [] as FriendInfo[],
    incomingRequests: [] as FriendRequestInfo[],
    outgoingRequests: [] as FriendRequestInfo[],
    searchKeyword: '',
    searchResults: [] as AuthUser[],
    selectedFriendIds: [] as string[],
    groupName: '',
    loading: false,
    refreshing: false,
    searching: false,
    submitting: false,
    initialized: false,
    error: '',
  }),
  getters: {
    pendingIncomingCount: (state) =>
      state.incomingRequests.filter((request) => request.status === 'pending').length,
    filteredFriends: (state) => {
      const keyword = state.searchKeyword.trim().toLowerCase();
      const friends = state.friends.slice().sort(compareFriend);
      if (!keyword) return friends;
      return friends.filter((friend) => {
        const user = friend.user;
        return [
          displayName(friend),
          user.email,
          user.username,
          friend.remark ?? '',
        ].some((value) => value.toLowerCase().includes(keyword));
      });
    },
    selectedFriends: (state) =>
      state.friends.filter((friend) => state.selectedFriendIds.includes(friend.user.id)),
  },
  actions: {
    async initialize() {
      if (this.initialized && !appEnv.useMockData) return;
      this.bindWebSocket();
      await this.loadCachedFriends();
      if (appEnv.useMockData) {
        this.friends = createMockFriends();
        this.incomingRequests = createMockIncomingRequests();
        this.outgoingRequests = [];
        this.initialized = true;
        this.syncPendingBadge();
        await this.persistFriends();
        return;
      }
      await Promise.all([this.refreshFriends(), this.refreshRequests()]);
      this.initialized = true;
    },

    async loadCachedFriends() {
      const cached = await loadCachedFriends();
      if (cached.length > 0) {
        this.friends = cached;
      }
    },

    async refreshFriends() {
      this.refreshing = true;
      this.error = '';
      try {
        const friends = await friendService.fetchFriends();
        this.friends = friends.slice().sort(compareFriend);
        await this.persistFriends();
      } catch (error) {
        this.error = error instanceof Error ? error.message : '加载联系人失败';
      } finally {
        this.refreshing = false;
      }
    },

    async refreshRequests() {
      if (appEnv.useMockData) {
        this.incomingRequests = createMockIncomingRequests();
        this.outgoingRequests = [];
        this.syncPendingBadge();
        return;
      }
      try {
        const [incoming, outgoing] = await Promise.all([
          friendService.fetchFriendRequests({ direction: 'incoming', status: 'pending' }),
          friendService.fetchFriendRequests({ direction: 'outgoing', status: 'pending' }),
        ]);
        this.incomingRequests = incoming;
        this.outgoingRequests = outgoing;
        this.syncPendingBadge();
      } catch (error) {
        this.error = error instanceof Error ? error.message : '加载好友请求失败';
      }
    },

    setSearchKeyword(keyword: string) {
      this.searchKeyword = keyword;
    },

    async searchUsers(keyword?: string) {
      const query = (keyword ?? this.searchKeyword).trim();
      this.searchKeyword = query;
      if (!query) {
        this.searchResults = [];
        return;
      }
      this.searching = true;
      this.error = '';
      try {
        this.searchResults = appEnv.useMockData
          ? createMockSearchResults(query)
          : await friendService.searchUsers(query);
      } catch (error) {
        this.error = error instanceof Error ? error.message : '搜索用户失败';
      } finally {
        this.searching = false;
      }
    },

    async sendFriendRequest(userId: string, message?: string) {
      if (!userId) return;
      this.submitting = true;
      this.error = '';
      try {
        const request = appEnv.useMockData
          ? createOutgoingRequest(userId, message)
          : await friendService.sendFriendRequest(userId, message);
        this.outgoingRequests = upsertRequest(this.outgoingRequests, request);
      } catch (error) {
        this.error = error instanceof Error ? error.message : '发送好友申请失败';
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    async respondRequest(requestId: string, action: FriendRequestAction) {
      const previous = this.incomingRequests;
      this.incomingRequests = this.incomingRequests.map((request) => (
        request.id === requestId ? { ...request, status: action === 'accept' ? 'accepted' : 'rejected' } : request
      ));
      this.syncPendingBadge();
      this.submitting = true;
      this.error = '';
      try {
        if (appEnv.useMockData) {
          const accepted = previous.find((request) => request.id === requestId);
          if (action === 'accept' && accepted?.requester) {
            this.friends = [
              ...this.friends.filter((friend) => friend.user.id !== accepted.requester?.id),
              {
                id: `friend-${accepted.requester.id}`,
                user: accepted.requester,
                createdAt: new Date().toISOString(),
                remark: null,
              },
            ].sort(compareFriend);
            await this.persistFriends();
          }
        } else {
          await friendService.respondFriendRequest(requestId, action);
          if (action === 'accept') {
            await this.refreshFriends();
          }
        }
      } catch (error) {
        this.incomingRequests = previous;
        this.syncPendingBadge();
        this.error = error instanceof Error ? error.message : '处理好友请求失败';
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    async openPrivateChat(friendUserId: string) {
      if (!friendUserId) return '';
      const chatStore = useChatStore();
      const friend = this.friends.find((item) => item.user.id === friendUserId);
      const result = appEnv.useMockData
        ? { roomId: `mock-private-${friendUserId}`, roomType: 'private', created: false }
        : await friendService.ensurePrivateChat(friendUserId);
      if (appEnv.useMockData) {
        await chatStore.upsertChatSummary(createMockChatSummary({
          roomId: result.roomId,
          name: friend ? displayName(friend) : '私聊',
          type: 'private',
        }));
      } else {
        await chatStore.refreshChats();
      }
      return result.roomId;
    },

    async updateFriendRemark(friendUserId: string, remark: string) {
      const friend = this.friends.find((item) => item.user.id === friendUserId);
      if (!friend) return null;
      this.submitting = true;
      this.error = '';
      try {
        const nextRemark = appEnv.useMockData ? remark.trim() || null : await friendService.updateFriendRemark(friendUserId, remark);
        this.friends = this.friends.map((item) => (
          item.user.id === friendUserId ? { ...item, remark: nextRemark } : item
        ));
        await this.persistFriends();
        return nextRemark;
      } catch (error) {
        this.error = error instanceof Error ? error.message : '更新好友备注失败';
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    async deleteFriend(friendUserId: string) {
      const previous = this.friends;
      this.friends = this.friends.filter((item) => item.user.id !== friendUserId);
      await this.persistFriends();
      this.submitting = true;
      this.error = '';
      try {
        if (!appEnv.useMockData) await friendService.deleteFriend(friendUserId);
      } catch (error) {
        this.friends = previous;
        await this.persistFriends();
        this.error = error instanceof Error ? error.message : '删除好友失败';
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    toggleGroupMember(friendUserId: string) {
      if (!friendUserId) return;
      this.selectedFriendIds = this.selectedFriendIds.includes(friendUserId)
        ? this.selectedFriendIds.filter((id) => id !== friendUserId)
        : [...this.selectedFriendIds, friendUserId];
    },

    clearGroupDraft() {
      this.groupName = '';
      this.selectedFriendIds = [];
    },

    async createGroup() {
      const name = this.groupName.trim();
      if (!name || this.selectedFriendIds.length === 0) return '';
      this.submitting = true;
      this.error = '';
      try {
        const room = appEnv.useMockData
          ? { id: `mock-group-${Date.now()}`, name, roomType: 'group' }
          : await roomService.createGroup({ name, memberIds: this.selectedFriendIds });
        const chatStore = useChatStore();
        this.clearGroupDraft();
        if (appEnv.useMockData) {
          await chatStore.upsertChatSummary(createMockChatSummary({
            roomId: room.id,
            name: room.name,
            type: 'group',
          }));
        } else {
          await chatStore.upsertChatSummary(chatSummaryFromCreatedRoom(room));
          await chatStore.refreshChats();
          if (!chatStore.chats.some((chat) => chat.roomId === room.id)) {
            await chatStore.upsertChatSummary(chatSummaryFromCreatedRoom(room));
          }
        }
        return room.id;
      } catch (error) {
        this.error = error instanceof Error ? error.message : '创建群聊失败';
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    bindWebSocket() {
      if (stopWsEvent) return;
      stopWsEvent = webSocketService.onEvent((event) => {
        void this.handleWebSocketEvent(event);
      });
    },

    async handleWebSocketEvent(event: WebSocketServerEvent) {
      if (event.type !== 'friend_request_update') return;
      const pendingCount = Number(event.pending_count ?? 0);
      useAppShellStore().setPendingFriends(Number.isFinite(pendingCount) ? pendingCount : 0);
      await this.refreshRequests();
    },

    dispose() {
      stopWsEvent?.();
      stopWsEvent = null;
      this.initialized = false;
    },

    async persistFriends() {
      await persistFriends(this.friends);
    },

    syncPendingBadge() {
      useAppShellStore().setPendingFriends(this.pendingIncomingCount);
    },
  },
});

const loadCachedFriends = async () => {
  try {
    return await contactStorage.loadFriends();
  } catch (error) {
    console.warn('[h5-app] 联系人本地缓存读取失败，已忽略', error);
    return [];
  }
};

const persistFriends = async (friends: FriendInfo[]) => {
  try {
    await contactStorage.saveFriends(friends);
  } catch (error) {
    console.warn('[h5-app] 联系人本地缓存写入失败，已忽略', error);
  }
};

const upsertRequest = (requests: FriendRequestInfo[], request: FriendRequestInfo) => {
  const index = requests.findIndex((item) => item.id === request.id);
  if (index < 0) return [request, ...requests];
  return requests.map((item) => (item.id === request.id ? request : item));
};

const createMockFriends = (): FriendInfo[] => [
  {
    id: 'friend-mia',
    user: {
      id: 'mock-mia',
      username: 'mia@example.com',
      nickname: 'Mia',
      email: 'mia@example.com',
    },
    createdAt: new Date().toISOString(),
    remark: 'Mia',
  },
  {
    id: 'friend-ops',
    user: {
      id: 'mock-ops',
      username: 'ops@example.com',
      nickname: 'Ops',
      email: 'ops@example.com',
    },
    createdAt: new Date().toISOString(),
    remark: null,
  },
];

const createMockIncomingRequests = (): FriendRequestInfo[] => [
  {
    id: 'mock-request-1',
    requesterId: 'mock-neo',
    targetUserId: 'mock-current',
    message: '一起做 H5 联调',
    status: 'pending',
    createdAt: new Date().toISOString(),
    requester: {
      id: 'mock-neo',
      username: 'neo@example.com',
      nickname: 'Neo',
      email: 'neo@example.com',
    },
    targetUser: null,
  },
];

const createMockSearchResults = (query: string): AuthUser[] => [
  {
    id: `mock-search-${query}`,
    username: `${query}@example.com`,
    nickname: query,
    email: `${query}@example.com`,
  },
];

const createOutgoingRequest = (userId: string, message?: string): FriendRequestInfo => ({
  id: `mock-outgoing-${userId}`,
  requesterId: 'mock-current',
  targetUserId: userId,
  message: message ?? null,
  status: 'pending',
  createdAt: new Date().toISOString(),
  requester: null,
  targetUser: null,
});

const createMockChatSummary = (params: { roomId: string; name: string; type: 'private' | 'group' }): ChatSummary => ({
  id: params.roomId,
  roomId: params.roomId,
  name: params.name,
  avatar: null,
  avatarObjectKey: null,
  lastMessage: '',
  lastMessageTime: Date.now(),
  unreadCount: 0,
  type: params.type,
  isPinned: false,
  isMuted: false,
});

const chatSummaryFromCreatedRoom = (room: CreatedRoom): ChatSummary => ({
  id: room.id,
  roomId: room.id,
  name: room.name || '群聊',
  avatar: room.avatarUrl ?? null,
  avatarObjectKey: null,
  lastMessage: '',
  lastMessageTime: Date.now(),
  unreadCount: 0,
  type: 'group',
  isPinned: false,
  isMuted: false,
  raw: {
    id: room.id,
    room_id: room.id,
    name: room.name,
    room_type: room.roomType,
    description: room.description ?? null,
    owner_id: room.ownerId ?? null,
  },
});
