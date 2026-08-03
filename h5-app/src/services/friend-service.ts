import { requestJson, withQuery } from '@/api/http';
import type { AuthUser, BackendUser } from '@/types/auth';
import type { BackendFriendInfo, BackendFriendRequest, EnsureChatResult, FriendInfo, FriendRequestAction, FriendRequestInfo } from '@/types/friend';

import { mapEnsureChatResult, mapFriend, mapFriendRequest, mapUser } from './mappers';
import { requireToken } from './session';

export const friendService = {
  async searchUsers(keyword: string, limit = 20): Promise<AuthUser[]> {
    const response = await requestJson<BackendUser[]>(
      withQuery('/users/search', { keyword, limit }),
      {},
      requireToken(),
    );
    return response.map(mapUser);
  },

  async sendFriendRequest(targetUserId: string, message?: string): Promise<FriendRequestInfo> {
    const response = await requestJson<BackendFriendRequest>('/friends/requests', {
      method: 'POST',
      body: JSON.stringify({
        target_user_id: targetUserId,
        ...(message?.trim() ? { message: message.trim() } : {}),
      }),
    }, requireToken());
    return mapFriendRequest(response);
  },

  async fetchFriendRequests(params: { direction?: string; status?: string } = {}): Promise<FriendRequestInfo[]> {
    const response = await requestJson<BackendFriendRequest[]>(
      withQuery('/friends/requests', params),
      {},
      requireToken(),
    );
    return response.map(mapFriendRequest);
  },

  async respondFriendRequest(requestId: string, action: FriendRequestAction): Promise<FriendRequestInfo> {
    const response = await requestJson<BackendFriendRequest>(`/friends/requests/${requestId}/respond`, {
      method: 'POST',
      body: JSON.stringify({ action }),
    }, requireToken());
    return mapFriendRequest(response);
  },

  async fetchFriends(): Promise<FriendInfo[]> {
    const response = await requestJson<BackendFriendInfo[]>('/friends', {}, requireToken());
    return response.map(mapFriend);
  },

  async deleteFriend(friendUserId: string): Promise<void> {
    await requestJson(`/friends/${friendUserId}`, { method: 'DELETE' }, requireToken());
  },

  async updateFriendRemark(friendUserId: string, remark: string): Promise<string | null> {
    const response = await requestJson<{ remark?: string | null }>(`/friends/${friendUserId}/remark`, {
      method: 'PATCH',
      body: JSON.stringify({ remark: remark.trim() || null }),
    }, requireToken());
    return response.remark?.trim() || null;
  },

  async ensurePrivateChat(friendUserId: string): Promise<EnsureChatResult> {
    const response = await requestJson<Record<string, unknown>>(
      `/friends/${friendUserId}/chat`,
      { method: 'POST' },
      requireToken(),
    );
    return mapEnsureChatResult(response);
  },
};
