import { createStore } from 'vuex';
import { SystemApi, type AuthUser } from '@/api/system';
import { UserApi } from '@/api/user';
import {
  FriendApi,
  type FriendInfo,
  type FriendRequestInfo,
} from '@/api/friend';
import {
  RoomApi,
  type ChatSummary,
} from '@/api/rooms';
import {
  MessageApi,
  type MessageInfo,
  type SendMessagePayload,
} from '@/api/message';
import { websocketClient, type ServerEvent } from '@/services/websocket';
import type { ApiResponse } from '@/api/http';

export interface AuthSession {
  token: string;
  user: AuthUser;
}

export interface RootState {
  token: string | null;
  user: AuthUser | null;
  chats: ChatSummary[];
  messages: Record<string, MessageInfo[]>;
  friends: FriendInfo[];
  friendRequests: FriendRequestInfo[];
  userSearchResults: AuthUser[];
  loading: boolean;
}

const SESSION_STORAGE_KEY = 'desktop_session';

const persistSession = (session: AuthSession | null) => {
  if (!session) {
    localStorage.removeItem(SESSION_STORAGE_KEY);
    return;
  }
  localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(session));
};

const restoreSession = (): AuthSession | null => {
  const raw = localStorage.getItem(SESSION_STORAGE_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as AuthSession;
    if (parsed?.token && parsed?.user?.id) {
      return parsed;
    }
  } catch (error) {
    console.warn('无法解析会话信息，恢复失败', error);
  }
  return null;
};

export const store = createStore<RootState>({
  state: {
    token: null,
    user: null,
    chats: [],
    messages: {},
    friends: [],
    friendRequests: [],
    userSearchResults: [],
    loading: false,
  },
  getters: {
    isLoggedIn: (state) => !!state.token && !!state.user,
    currentUser: (state) => state.user,
    chatById:
      (state) =>
      (roomId: string): ChatSummary | undefined =>
        state.chats.find((chat) => chat.room_id === roomId),
    messagesByRoom:
      (state) =>
      (roomId: string): MessageInfo[] =>
        state.messages[roomId] ?? [],
    userSearchResults: (state) => state.userSearchResults,
  },
  mutations: {
    SET_SESSION(state, session: AuthSession) {
      state.token = session.token;
      state.user = session.user;
      persistSession(session);
    },
    CLEAR_SESSION(state) {
      state.token = null;
      state.user = null;
      state.chats = [];
      state.messages = {};
      state.friends = [];
      state.friendRequests = [];
      state.userSearchResults = [];
      persistSession(null);
    },
    SET_CHATS(state, chats: ChatSummary[]) {
      state.chats = chats;
    },
    SET_MESSAGES(state, payload: { roomId: string; messages: MessageInfo[] }) {
      state.messages = {
        ...state.messages,
        [payload.roomId]: payload.messages,
      };
    },
    APPEND_MESSAGE(state, payload: { roomId: string; message: MessageInfo }) {
      const existing = state.messages[payload.roomId] ?? [];
      state.messages = {
        ...state.messages,
        [payload.roomId]: [...existing, payload.message],
      };
    },
    SET_FRIENDS(state, friends: FriendInfo[]) {
      state.friends = friends;
    },
    SET_FRIEND_REQUESTS(state, requests: FriendRequestInfo[]) {
      state.friendRequests = requests;
    },
    SET_USER_SEARCH_RESULTS(state, results: AuthUser[]) {
      state.userSearchResults = results;
    },
    UPDATE_USER(state, user: AuthUser) {
      state.user = user;
      if (state.token) {
        persistSession({ token: state.token, user });
      }
    },
    SET_LOADING(state, value: boolean) {
      state.loading = value;
    },
  },
  actions: {
    restoreSession({ commit }) {
      const session = restoreSession();
      if (session) {
        commit('SET_SESSION', session);
        websocketClient.connect(session.token);
      }
    },
    async login({ commit }, payload: { username: string; password: string }) {
      const response = await SystemApi.login(payload);
      if (!response.success || !response.data) {
        throw new Error(response.message || '登录失败');
      }
      commit('SET_SESSION', {
        token: response.data.token,
        user: response.data.user,
      });
      websocketClient.connect(response.data.token);
      return response.data;
    },
    async loginWithSms(
      { commit },
      payload: { phone: string; code: string },
    ) {
      const response = await SystemApi.loginWithSms(payload);
      if (!response.success || !response.data) {
        throw new Error(response.message || '登录失败');
      }
      commit('SET_SESSION', {
        token: response.data.token,
        user: response.data.user,
      });
      websocketClient.connect(response.data.token);
      return response.data;
    },
    logout({ commit }) {
      commit('CLEAR_SESSION');
      websocketClient.disconnect();
    },
    async refreshCurrentUser({ commit }) {
      const response = await SystemApi.getCurrentUser();
      if (response.success && response.data) {
        commit('UPDATE_USER', response.data as AuthUser);
      }
      return response;
    },
    async updateProfile({ commit }, payload: { nickname?: string; avatar_url?: string }) {
      const response = await UserApi.updateProfile(payload);
      if (response.success && response.data) {
        commit('UPDATE_USER', response.data as AuthUser);
      }
      return response;
    },
    async changePassword(_ctx, payload: { current_password: string; new_password: string }) {
      return UserApi.changePassword(payload);
    },
    async fetchChats({ commit, dispatch }) {
      const response = await RoomApi.listChatSummaries();
      if (response.success && response.data) {
        commit('SET_CHATS', response.data);
        await dispatch('syncWebsocketRooms');
      }
      return response;
    },
    async fetchMessages({ commit }, roomId: string) {
      const response = await MessageApi.listMessages(roomId, { limit: 50 });
      if (response.success && response.data) {
        commit('SET_MESSAGES', { roomId, messages: response.data });
        const last = response.data[response.data.length - 1];
        if (last) {
          try {
            await MessageApi.markRead(roomId, last.id);
          } catch (error) {
            console.warn('标记消息已读失败', error);
          }
        }
      }
      return response;
    },
    async sendMessage(
      { commit },
      payload: { roomId: string; data: SendMessagePayload },
    ) {
      const response = await MessageApi.sendMessage(
        payload.roomId,
        payload.data,
      );
      if (response.success && response.data) {
        commit('APPEND_MESSAGE', {
          roomId: payload.roomId,
          message: response.data.message,
        });
      }
      return response;
    },
    async fetchFriends({ commit }) {
      const response = await FriendApi.listFriends();
      if (response.success && response.data) {
        commit('SET_FRIENDS', response.data);
      }
      return response;
    },
    async fetchFriendRequests({ commit }) {
      const response = await FriendApi.listFriendRequests();
      if (response.success && response.data) {
        commit('SET_FRIEND_REQUESTS', response.data);
      }
      return response;
    },
    async createFriendRequest(
      { dispatch },
      payload: { targetUserId: string; message?: string },
    ) {
      const response = await FriendApi.createFriendRequest(
        payload.targetUserId,
        payload.message,
      );
      if (response.success) {
        await dispatch('fetchFriendRequests');
      }
      return response;
    },
    async respondFriendRequest(
      { dispatch },
      payload: { requestId: string; action: 'accept' | 'decline' },
    ) {
      const response = await FriendApi.respondFriendRequest(
        payload.requestId,
        payload.action,
      );
      if (response.success) {
        await Promise.all([
          dispatch('fetchFriendRequests'),
          dispatch('fetchFriends'),
        ]);
      }
      return response;
    },
    async ensurePrivateChat(_ctx, friendUserId: string) {
      return FriendApi.ensurePrivateChat(friendUserId);
    },
    async syncWebsocketRooms({ state }) {
      const rooms = state.chats.map((chat) => chat.room_id).filter(Boolean);
      websocketClient.updateDesiredRooms(rooms);
    },
    async handleServerEvent({ dispatch }, event: ServerEvent) {
      switch (event.type) {
        case 'message':
          await dispatch('handleServerMessage', event as Extract<ServerEvent, { type: 'message' }>);
          break;
        case 'friend_request_update':
          await dispatch('fetchFriendRequests');
          break;
        case 'room_created':
          await dispatch('fetchChats');
          break;
        default:
          break;
      }
    },
    async handleServerMessage({ dispatch }, event: Extract<ServerEvent, { type: 'message' }>) {
      if (!event.room_id) return;
      await dispatch('fetchMessages', event.room_id);
      await dispatch('fetchChats');
    },
    async searchUsers({ commit }, payload: { keyword: string; limit?: number }) {
      const keyword = payload.keyword.trim();
      if (!keyword) {
        commit('SET_USER_SEARCH_RESULTS', []);
        const emptyResponse: ApiResponse<AuthUser[]> = {
          code: 200,
          message: '',
          data: [],
          success: true,
        };
        return emptyResponse;
      }
      const response = await UserApi.searchUsers({
        keyword,
        limit: payload.limit ?? 20,
      });
      if (response.success && response.data) {
        commit('SET_USER_SEARCH_RESULTS', response.data);
      }
      return response;
    },
    clearUserSearch({ commit }) {
      commit('SET_USER_SEARCH_RESULTS', []);
    },
  },
});

websocketClient.onEvent((event) => {
  store.dispatch('handleServerEvent', event).catch((error) => {
    console.warn('处理 WebSocket 事件失败', error);
  });
});
