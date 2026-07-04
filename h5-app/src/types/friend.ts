import type { AuthUser, BackendUser } from './auth';

export type FriendRequestAction = 'accept' | 'decline';

export interface FriendRequestInfo {
  id: string;
  requesterId: string;
  targetUserId: string;
  message?: string | null;
  status: string;
  createdAt?: string | null;
  requester?: AuthUser | null;
  targetUser?: AuthUser | null;
}

export interface FriendInfo {
  id: string;
  user: AuthUser;
  createdAt: string;
  remark?: string | null;
}

export interface EnsureChatResult {
  roomId: string;
  roomType: string;
  created: boolean;
}

export interface BackendFriendRequest {
  id?: string;
  requester_id?: string;
  target_user_id?: string;
  message?: string | null;
  status?: string | number | null;
  created_at?: string | null;
  requester?: BackendUser | null;
  target_user?: BackendUser | null;
}

export interface BackendFriendInfo {
  id?: string;
  user?: BackendUser | null;
  created_at?: string | null;
  remark?: string | null;
}
