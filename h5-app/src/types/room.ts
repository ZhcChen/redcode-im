export interface CreatedRoom {
  id: string;
  name: string;
  roomType: string;
  description?: string | null;
  avatarUrl?: string | null;
  avatarObjectKey?: string | null;
  ownerId?: string | null;
}

export interface RoomMember {
  id?: string;
  roomId?: string;
  userId: string;
  username?: string;
  nickname?: string | null;
  avatarUrl?: string | null;
  role?: string | null;
}

export interface GroupSettingsInfo {
  roomId: string;
  globalMuteEnabled: boolean;
  globalMuteReason?: string | null;
  globalMuteUntil?: string | null;
  joinApprovalRequired?: boolean | null;
  memberCanInvite?: boolean | null;
  maxMembers?: number | null;
}

export interface AddMembersResult {
  addedUserIds: string[];
  skippedUserIds: string[];
}

export interface GroupAdmin {
  id: string;
  roomId: string;
  adminId: string;
  appointedBy: string;
  role: string;
  permissions: string[];
  appointedAt: string;
}

export interface GroupRule {
  id: string;
  roomId: string;
  title: string;
  content: string;
  creatorId: string;
  orderIndex: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface GroupMute {
  id: string;
  roomId: string;
  userId: string;
  mutedBy: string;
  reason: string | null;
  muteDurationHours: number;
  mutedAt: string;
  unmutedAt: string | null;
  isActive: boolean;
}

export type JoinRequestStatus = 'pending' | 'approved' | 'rejected';

export interface GroupJoinRequest {
  id: string;
  roomId: string;
  applicantId: string;
  message: string | null;
  status: JoinRequestStatus;
  reviewerId: string | null;
  reviewMessage: string | null;
  createdAt: string;
  reviewedAt: string | null;
}

export type GroupInvitationStatus = 'pending' | 'accepted' | 'declined' | 'expired';

export interface GroupInvitation {
  id: string;
  roomId: string;
  roomName: string | null;
  roomAvatarUrl: string | null;
  inviterId: string;
  inviterName: string | null;
  inviteeId: string;
  message: string | null;
  status: GroupInvitationStatus;
  invitedAt: string;
  respondedAt: string | null;
  expiresAt: string;
}

export interface GroupOperationLog {
  id: string;
  roomId: string;
  operatorId: string;
  targetUserId: string | null;
  operationType: string;
  operationData: Record<string, unknown> | null;
  createdAt: string;
}

export interface GroupDirectoryEntry {
  roomId: string;
  name: string;
  description: string | null;
  avatarUrl: string | null;
  avatarObjectKey: string | null;
  memberCount: number;
  isFavorited: boolean;
  favoritedAt: string | null;
}
