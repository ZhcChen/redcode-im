import { requestJson, withQuery } from '@/api/http';
import type { AddMembersResult, CreatedRoom, GroupAdmin, GroupDirectoryEntry, GroupInvitation, GroupInvitationStatus, GroupJoinRequest, GroupMute, GroupOperationLog, GroupRule, GroupSettingsInfo, JoinRequestStatus, RoomMember } from '@/types/room';

import { mapAddMembersResult, mapCreatedRoom, mapGroupAdmin, mapGroupInvitation, mapGroupJoinRequest, mapGroupMute, mapGroupOperationLog, mapGroupRule, mapGroupSettings, mapRoomMember } from './mappers';
import { requireToken } from './session';

export const roomService = {
  async createGroup(params: { name: string; description?: string; memberIds: string[] }): Promise<CreatedRoom> {
    const response = await requestJson<{ room?: Record<string, unknown> } & Record<string, unknown>>('/rooms', {
      method: 'POST',
      body: JSON.stringify({
        name: params.name.trim(),
        room_type: 'group',
        member_ids: params.memberIds,
        ...(params.description?.trim() ? { description: params.description.trim() } : {}),
      }),
    }, requireToken());
    return mapCreatedRoom(response.room ?? response);
  },

  async listRooms(): Promise<CreatedRoom[]> {
    const response = await requestJson<Record<string, unknown>[] | { rooms?: Record<string, unknown>[] }>(
      '/rooms',
      {},
      requireToken(),
    );
    const rooms = Array.isArray(response) ? response : response.rooms ?? [];
    return rooms.map(mapCreatedRoom);
  },

  async listGroupDirectory(): Promise<GroupDirectoryEntry[]> {
    const rows = await requestJson<Record<string, unknown>[]>('/groups/directory', {}, requireToken());
    return rows.map((row) => ({
      roomId: String(row.room_id ?? ''), name: String(row.name ?? ''),
      description: row.description == null ? null : String(row.description),
      avatarUrl: row.avatar_url == null ? null : String(row.avatar_url),
      avatarObjectKey: row.avatar_object_key == null ? null : String(row.avatar_object_key),
      memberCount: Number(row.member_count ?? 0), isFavorited: Boolean(row.is_favorited),
      favoritedAt: row.favorited_at == null ? null : String(row.favorited_at),
    }));
  },

  async favoriteGroupDirectory(roomId: string, favorited: boolean): Promise<void> {
    await requestJson(`/rooms/${roomId}/directory-favorite`, { method: favorited ? 'POST' : 'DELETE' }, requireToken());
  },

  async getRoom(roomId: string): Promise<CreatedRoom> {
    const response = await requestJson<{ room?: Record<string, unknown> } & Record<string, unknown>>(
      `/rooms/${roomId}`,
      {},
      requireToken(),
    );
    return mapCreatedRoom(response.room ?? response);
  },

  async updateRoom(roomId: string, params: { name?: string; description?: string }): Promise<CreatedRoom> {
    const response = await requestJson<{ room?: Record<string, unknown> } & Record<string, unknown>>(`/rooms/${roomId}`, {
      method: 'PATCH',
      body: JSON.stringify({
        ...(params.name !== undefined ? { name: params.name.trim() } : {}),
        ...(params.description !== undefined ? { description: params.description.trim() } : {}),
      }),
    }, requireToken());
    return mapCreatedRoom(response.room ?? response);
  },

  async listMembers(roomId: string): Promise<RoomMember[]> {
    const response = await requestJson<Record<string, unknown>[] | { members?: Record<string, unknown>[] }>(
      `/rooms/${roomId}/members`,
      {},
      requireToken(),
    );
    const members = Array.isArray(response) ? response : response.members ?? [];
    return members.map(mapRoomMember);
  },

  async addMembers(roomId: string, userIds: string[]): Promise<AddMembersResult> {
    const response = await requestJson<Record<string, unknown>>(`/rooms/${roomId}/members/add`, {
      method: 'POST',
      body: JSON.stringify({ user_ids: userIds }),
    }, requireToken());
    return mapAddMembersResult(response);
  },

  async removeMember(roomId: string, userId: string): Promise<void> {
    await requestJson(`/rooms/${roomId}/members/${userId}`, { method: 'DELETE' }, requireToken());
  },

  async listAdmins(roomId: string): Promise<GroupAdmin[]> {
    const response = await requestJson<{ admins?: Record<string, unknown>[] }>(
      `/rooms/${roomId}/admins`,
      {},
      requireToken(),
    );
    return (response.admins ?? []).map(mapGroupAdmin);
  },

  async appointAdmin(roomId: string, userId: string): Promise<GroupAdmin> {
    const response = await requestJson<{ admin: Record<string, unknown> }>(`/rooms/${roomId}/admins`, {
      method: 'POST',
      body: JSON.stringify({ user_id: userId, role: 'admin' }),
    }, requireToken());
    return mapGroupAdmin(response.admin);
  },

  async removeAdmin(roomId: string, userId: string): Promise<void> {
    await requestJson(`/rooms/${roomId}/admins/${userId}`, { method: 'DELETE' }, requireToken());
  },

  async listRules(roomId: string): Promise<GroupRule[]> {
    const response = await requestJson<{ rules?: Record<string, unknown>[] }>(
      `/rooms/${roomId}/rules`,
      {},
      requireToken(),
    );
    return (response.rules ?? []).map(mapGroupRule);
  },

  async createRule(roomId: string, input: { title: string; content: string; orderIndex: number }): Promise<GroupRule> {
    const response = await requestJson<{ rule: Record<string, unknown> }>(`/rooms/${roomId}/rules`, {
      method: 'POST',
      body: JSON.stringify({
        title: input.title.trim(),
        content: input.content.trim(),
        order_index: input.orderIndex,
      }),
    }, requireToken());
    return mapGroupRule(response.rule);
  },

  async updateRule(roomId: string, ruleId: string, input: { title: string; content: string }): Promise<GroupRule> {
    const response = await requestJson<{ rule: Record<string, unknown> }>(`/rooms/${roomId}/rules/${ruleId}`, {
      method: 'PATCH',
      body: JSON.stringify({ title: input.title.trim(), content: input.content.trim() }),
    }, requireToken());
    return mapGroupRule(response.rule);
  },

  async deleteRule(roomId: string, ruleId: string): Promise<void> {
    await requestJson(`/rooms/${roomId}/rules/${ruleId}`, { method: 'DELETE' }, requireToken());
  },

  async listMutes(roomId: string): Promise<GroupMute[]> {
    const response = await requestJson<{ mutes?: Record<string, unknown>[] }>(
      `/rooms/${roomId}/mutes`,
      {},
      requireToken(),
    );
    return (response.mutes ?? []).map(mapGroupMute);
  },

  async muteUser(roomId: string, input: { userId: string; durationHours: number; reason?: string }): Promise<GroupMute> {
    const response = await requestJson<{ mute: Record<string, unknown> }>(`/rooms/${roomId}/mutes`, {
      method: 'POST',
      body: JSON.stringify({
        user_id: input.userId,
        duration_hours: input.durationHours,
        ...(input.reason?.trim() ? { reason: input.reason.trim() } : {}),
      }),
    }, requireToken());
    return mapGroupMute(response.mute);
  },

  async unmuteUser(roomId: string, userId: string): Promise<void> {
    await requestJson(`/rooms/${roomId}/mutes/${userId}`, { method: 'DELETE' }, requireToken());
  },

  async updateGlobalMute(
    roomId: string,
    input: { enabled: boolean; reason?: string; durationMinutes?: number },
  ): Promise<GroupSettingsInfo> {
    const response = await requestJson<{ settings: Record<string, unknown> }>(`/rooms/${roomId}/mutes/global`, {
      method: 'POST',
      body: JSON.stringify({
        enabled: input.enabled,
        ...(input.reason?.trim() ? { reason: input.reason.trim() } : {}),
        ...(input.durationMinutes ? { duration_minutes: input.durationMinutes } : {}),
      }),
    }, requireToken());
    return mapGroupSettings(response.settings);
  },

  async listJoinRequests(roomId: string): Promise<GroupJoinRequest[]> {
    const response = await requestJson<{ requests?: Record<string, unknown>[] }>(
      `/rooms/${roomId}/join-requests`,
      {},
      requireToken(),
    );
    return (response.requests ?? []).map(mapGroupJoinRequest);
  },

  async createJoinRequest(roomId: string, message?: string): Promise<GroupJoinRequest> {
    const response = await requestJson<{ request: Record<string, unknown> }>(`/rooms/${roomId}/join-requests`, {
      method: 'POST',
      body: JSON.stringify({ ...(message?.trim() ? { message: message.trim() } : {}) }),
    }, requireToken());
    return mapGroupJoinRequest(response.request);
  },

  async reviewJoinRequest(
    roomId: string,
    requestId: string,
    status: Exclude<JoinRequestStatus, 'pending'>,
    reviewMessage?: string,
  ): Promise<GroupJoinRequest> {
    const response = await requestJson<{ request: Record<string, unknown> }>(
      `/rooms/${roomId}/join-requests/${requestId}/review`,
      {
        method: 'POST',
        body: JSON.stringify({
          status,
          ...(reviewMessage?.trim() ? { review_message: reviewMessage.trim() } : {}),
        }),
      },
      requireToken(),
    );
    return mapGroupJoinRequest(response.request);
  },

  async joinRoom(roomId: string): Promise<void> {
    await requestJson(`/rooms/${roomId}/join`, { method: 'POST' }, requireToken());
  },

  async updateJoinApproval(roomId: string, required: boolean): Promise<GroupSettingsInfo> {
    const response = await requestJson<{ settings: Record<string, unknown> }>(`/rooms/${roomId}/settings`, {
      method: 'PATCH',
      body: JSON.stringify({ join_approval_required: required }),
    }, requireToken());
    return mapGroupSettings(response.settings);
  },

  async listReceivedInvitations(status: GroupInvitationStatus | 'all' = 'all'): Promise<GroupInvitation[]> {
    const response = await requestJson<{ invitations?: Record<string, unknown>[] }>(
      withQuery('/group-invitations', { status }),
      {},
      requireToken(),
    );
    return (response.invitations ?? []).map(mapGroupInvitation);
  },

  async createInvitations(roomId: string, userIds: string[], message?: string): Promise<GroupInvitation[]> {
    const response = await requestJson<{ invitations?: Record<string, unknown>[] }>(`/rooms/${roomId}/invitations`, {
      method: 'POST',
      body: JSON.stringify({
        user_ids: userIds,
        ...(message?.trim() ? { message: message.trim() } : {}),
      }),
    }, requireToken());
    return (response.invitations ?? []).map(mapGroupInvitation);
  },

  async respondToInvitation(
    roomId: string,
    invitationId: string,
    status: Extract<GroupInvitationStatus, 'accepted' | 'declined'>,
  ): Promise<void> {
    await requestJson(`/rooms/${roomId}/invitations/${invitationId}/respond`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    }, requireToken());
  },

  async fetchGroupSettings(roomId: string): Promise<GroupSettingsInfo> {
    const response = await requestJson<{ settings?: Record<string, unknown> } & Record<string, unknown>>(
      `/rooms/${roomId}/settings`,
      {},
      requireToken(),
    );
    return mapGroupSettings(response.settings ?? response);
  },

  async updateNotificationSettings(roomId: string, notificationSettings: number): Promise<void> {
    await requestJson(`/rooms/${roomId}/notification-settings`, {
      method: 'POST',
      body: JSON.stringify({ notification_settings: notificationSettings }),
    }, requireToken());
  },

  async pinRoom(roomId: string, pinned: boolean): Promise<void> {
    await requestJson(`/rooms/${roomId}/pin`, { method: pinned ? 'POST' : 'DELETE' }, requireToken());
  },

  async leaveRoom(roomId: string): Promise<void> {
    await requestJson(`/rooms/${roomId}/leave`, { method: 'POST' }, requireToken());
  },

  async dissolveRoom(roomId: string): Promise<void> {
    await requestJson(`/rooms/${roomId}`, { method: 'DELETE' }, requireToken());
  },

  async listOperationLogs(roomId: string, limit = 20, offset = 0): Promise<GroupOperationLog[]> {
    const response = await requestJson<{ logs?: Record<string, unknown>[] }>(
      withQuery(`/rooms/${roomId}/operation-logs`, { limit, offset }),
      {},
      requireToken(),
    );
    return (response.logs ?? []).map(mapGroupOperationLog);
  },
};
