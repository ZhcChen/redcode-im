import { get, post } from './http';
import type { ApiResponse } from './http';
import type { AuthUser } from './system';

export interface FriendInfo {
  id: string;
  user: AuthUser;
  created_at: string;
}

export interface FriendRequestInfo {
  id: string;
  requester: AuthUser;
  addressee: AuthUser;
  status: 'Pending' | 'Accepted' | 'Declined';
  message?: string;
  created_at: string;
  responded_at?: string;
  is_incoming: boolean;
}

export class FriendApi {
  static listFriends(): Promise<ApiResponse<FriendInfo[]>> {
    return get<FriendInfo[]>('/friends');
  }

  static listFriendRequests(): Promise<ApiResponse<FriendRequestInfo[]>> {
    return get<FriendRequestInfo[]>('/friends/requests');
  }

  static createFriendRequest(
    targetUserId: string,
    message?: string,
  ): Promise<ApiResponse<FriendRequestInfo>> {
    return post<FriendRequestInfo>('/friends/requests', {
      target_user_id: targetUserId,
      message,
    });
  }

  static respondFriendRequest(
    requestId: string,
    action: 'accept' | 'decline',
  ): Promise<ApiResponse<FriendRequestInfo>> {
    return post<FriendRequestInfo>(
      `/friends/requests/${requestId}/respond`,
      { action },
    );
  }

  static ensurePrivateChat(
    friendUserId: string,
  ): Promise<ApiResponse<{ room_id: string }>> {
    return post<{ room_id: string }>(
      `/friends/${friendUserId}/chat`,
    );
  }
}
