import { requestJson, withQuery } from '@/api/http';
import type { AddMembersResult, CreatedRoom, GroupAdmin, GroupDirectoryEntry, GroupSettingsInfo, RoomMember } from '@/types/room';

import { mapAddMembersResult, mapCreatedRoom, mapGroupAdmin, mapGroupSettings, mapRoomMember } from './mappers';
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

  async listOperationLogs(roomId: string, limit = 20, offset = 0): Promise<Record<string, unknown>[]> {
    const response = await requestJson<{ logs?: Record<string, unknown>[] }>(
      withQuery(`/rooms/${roomId}/operation-logs`, { limit, offset }),
      {},
      requireToken(),
    );
    return response.logs ?? [];
  },
};
