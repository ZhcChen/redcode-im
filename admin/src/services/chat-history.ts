import http from '@/services/http';

export interface MessagePart {
  id: string;
  message_id: string;
  part_type: string;
  content: string;
  content_type?: string;
  object_key?: string;
  file_name?: string;
  file_size?: number;
  thumbnail_key?: string;
  duration?: number;
  width?: number;
  height?: number;
  created_at: string;
}

export interface ChatMessage {
  id: string;
  room_id: string;
  room_name?: string;
  sender_id: string;
  sender_name: string;
  sender_avatar?: string;
  message_type: string;
  content: string;
  parts: MessagePart[];
  created_at: string;
  updated_at: string;
  deleted_at?: string;
}

export interface ChatHistoryParams {
  page?: number;
  pageSize?: number;
  room_id?: string;
  user_id?: string;
  start_date?: string;
  end_date?: string;
  keyword?: string;
}

export interface ChatHistoryResponse {
  messages: ChatMessage[];
  total: number;
  page: number;
  pageSize: number;
}

export interface UserRoom {
  id: string;
  name: string;
  description?: string;
  avatar_url?: string;
  is_private: boolean;
  is_group: boolean;
  member_count: number;
  last_message?: ChatMessage;
  created_at: string;
  updated_at: string;
}

export interface UserRoomResponse {
  rooms: UserRoom[];
  total: number;
}

// 获取聊天记录
export function getChatHistory(params?: ChatHistoryParams) {
  return http.get<ChatHistoryResponse>('/api/admin/chat-history', { params });
}

// 获取用户参与的房间列表
export function getUserRooms(userId: string) {
  return http.get<UserRoomResponse>(`/api/admin/users/${userId}/rooms`);
}

// 获取特定房间的聊天记录
export function getRoomChatHistory(
  roomId: string,
  params?: Omit<ChatHistoryParams, 'room_id'>
) {
  return http.get<ChatHistoryResponse>(
    `/api/admin/rooms/${roomId}/chat-history`,
    { params }
  );
}
