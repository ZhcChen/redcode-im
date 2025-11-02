import { get, post } from './http';
import type { ApiResponse } from './http';
import type { AuthUser } from './system';

export type RoomType = 'private' | 'group' | 'public' | 'favorite';

export interface ChatMessagePreview {
  id: string;
  content: string;
  message_type: 'text' | 'image' | 'file' | 'system';
  created_at: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string;
}

export interface ChatSummary {
  room_id: string;
  name: string;
  room_type: RoomType;
  avatar_url?: string;
  description?: string;
  unread_count: number;
  last_read_message_id?: string;
  last_read_at?: string;
  last_message?: ChatMessagePreview;
}

export interface RoomInfo {
  id: string;
  name: string;
  description?: string;
  avatar_url?: string;
  room_type: RoomType;
  owner_id: string;
  created_at: string;
}

export interface RoomMember {
  user_id: string;
  role: 'owner' | 'admin' | 'member';
  joined_at: string;
}

export class RoomApi {
  static listChatSummaries(): Promise<ApiResponse<ChatSummary[]>> {
    return get<ChatSummary[]>('/chats');
  }

  static listMyRooms(): Promise<ApiResponse<RoomInfo[]>> {
    return get<RoomInfo[]>('/rooms');
  }

  static createRoom(payload: {
    name: string;
    description?: string;
    room_type?: RoomType;
    member_ids?: string[];
  }): Promise<ApiResponse<{ room: RoomInfo }>> {
    return post<{ room: RoomInfo }>('/rooms', payload);
  }

  static listMembers(roomId: string): Promise<ApiResponse<RoomMember[]>> {
    return get<RoomMember[]>(`/rooms/${roomId}/members`);
  }

  static join(roomId: string): Promise<ApiResponse<{ ok: boolean }>> {
    return post<{ ok: boolean }>(`/rooms/${roomId}/join`);
  }

  static leave(roomId: string): Promise<ApiResponse<{ ok: boolean }>> {
    return post<{ ok: boolean }>(`/rooms/${roomId}/leave`);
  }
}
