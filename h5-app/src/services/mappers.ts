import type { AuthUser, BackendUser } from '@/types/auth';
import type { BackendFriendInfo, BackendFriendRequest, EnsureChatResult, FriendInfo, FriendRequestInfo } from '@/types/friend';
import type { AddMembersResult, CreatedRoom, GroupAdmin, GroupRule, GroupSettingsInfo, RoomMember } from '@/types/room';

export const mapUser = (user: BackendUser | null | undefined): AuthUser => {
  const id = user?.id ?? user?.email ?? user?.username ?? 'unknown-user';
  const email = user?.email ?? user?.username ?? '';
  return {
    id,
    username: user?.username ?? email,
    nickname: user?.nickname || email || 'RedCode 用户',
    email,
    status: user?.status ?? 'active',
    avatarUrl: user?.avatar_url ?? null,
    avatarObjectKey: user?.avatar_object_key ?? null,
  };
};

export const mapFriendRequest = (input: BackendFriendRequest): FriendRequestInfo => ({
  id: input.id ?? '',
  requesterId: input.requester_id ?? '',
  targetUserId: input.target_user_id ?? '',
  message: input.message ?? null,
  status: normalizeRequestStatus(input.status),
  createdAt: input.created_at ?? null,
  requester: input.requester ? mapUser(input.requester) : null,
  targetUser: input.target_user ? mapUser(input.target_user) : null,
});

export const mapFriend = (input: BackendFriendInfo): FriendInfo => ({
  id: input.id ?? '',
  user: mapUser(input.user),
  createdAt: input.created_at ?? '',
  remark: input.remark ?? null,
});

export const mapEnsureChatResult = (input: Record<string, unknown>): EnsureChatResult => ({
  roomId: String(input.room_id ?? input.roomId ?? ''),
  roomType: String(input.room_type ?? input.roomType ?? 'private'),
  created: Boolean(input.created ?? false),
});

export const mapCreatedRoom = (input: Record<string, unknown>): CreatedRoom => ({
  id: String(input.id ?? ''),
  name: String(input.name ?? ''),
  roomType: String(input.room_type ?? input.roomType ?? 'group'),
  description: input.description == null ? null : String(input.description),
  avatarUrl: input.avatar_url == null ? null : String(input.avatar_url),
  avatarObjectKey: input.avatar_object_key == null ? null : String(input.avatar_object_key),
  ownerId: input.owner_id == null ? null : String(input.owner_id),
});

export const mapRoomMember = (input: Record<string, unknown>): RoomMember => ({
  id: input.id == null ? undefined : String(input.id),
  roomId: input.room_id == null ? undefined : String(input.room_id),
  userId: String(input.user_id ?? input.id ?? ''),
  username: input.username == null ? undefined : String(input.username),
  nickname: input.nickname == null ? null : String(input.nickname),
  avatarUrl: input.avatar_url == null ? null : String(input.avatar_url),
  role: input.role == null ? null : String(input.role),
});

export const mapGroupSettings = (input: Record<string, unknown>): GroupSettingsInfo => ({
  roomId: String(input.room_id ?? ''),
  globalMuteEnabled: Boolean(input.global_mute_enabled ?? false),
  globalMuteReason: input.global_mute_reason == null ? null : String(input.global_mute_reason),
  globalMuteUntil: input.global_mute_until == null ? null : String(input.global_mute_until),
  joinApprovalRequired:
    typeof input.join_approval_required === 'boolean' ? input.join_approval_required : null,
  memberCanInvite: typeof input.member_can_invite === 'boolean' ? input.member_can_invite : null,
  maxMembers: typeof input.max_members === 'number' ? input.max_members : null,
});

export const mapAddMembersResult = (input: Record<string, unknown>): AddMembersResult => ({
  addedUserIds: Array.isArray(input.added_user_ids) ? input.added_user_ids.map(String) : [],
  skippedUserIds: Array.isArray(input.skipped_user_ids) ? input.skipped_user_ids.map(String) : [],
});

export const mapGroupAdmin = (input: Record<string, unknown>): GroupAdmin => ({
  id: String(input.id ?? ''),
  roomId: String(input.room_id ?? input.roomId ?? ''),
  adminId: String(input.admin_id ?? input.adminId ?? ''),
  appointedBy: String(input.appointed_by ?? input.appointedBy ?? ''),
  role: String(input.role ?? 'admin'),
  permissions: Array.isArray(input.permissions) ? input.permissions.map(String) : [],
  appointedAt: String(input.appointed_at ?? input.appointedAt ?? ''),
});

export const mapGroupRule = (input: Record<string, unknown>): GroupRule => ({
  id: String(input.id ?? ''),
  roomId: String(input.room_id ?? input.roomId ?? ''),
  title: String(input.title ?? ''),
  content: String(input.content ?? ''),
  creatorId: String(input.creator_id ?? input.creatorId ?? ''),
  orderIndex: Number(input.order_index ?? input.orderIndex ?? 0),
  isActive: Boolean(input.is_active ?? input.isActive ?? false),
  createdAt: String(input.created_at ?? input.createdAt ?? ''),
  updatedAt: String(input.updated_at ?? input.updatedAt ?? ''),
});

const normalizeRequestStatus = (status: string | number | null | undefined) => {
  if (typeof status === 'number') {
    if (status === 1) return 'accepted';
    if (status === 2) return 'rejected';
    return 'pending';
  }
  return status || 'pending';
};
