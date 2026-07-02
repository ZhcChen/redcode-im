export interface CreatedRoom {
  id: string;
  name: string;
  roomType: string;
  description?: string | null;
  avatarUrl?: string | null;
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
