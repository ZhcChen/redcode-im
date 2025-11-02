import { del, get, post } from './http';
import type { ApiResponse } from './http';

export type MessageType = 'text' | 'image' | 'file' | 'system';

export interface QuotedMessageInfo {
  id: string;
  room_id: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string;
  sender_avatar_url?: string;
  content?: string;
  message_type: MessageType;
  created_at?: string;
  is_deleted?: boolean;
}

export interface ForwardMessageInfo {
  message_id: string;
  room_id: string;
  sender_id: string;
  sender_username?: string;
  sender_nickname?: string;
}

export interface MessageInfo {
  id: string;
  room_id: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string;
  sender_avatar_url?: string;
  content: string;
  message_type: MessageType;
  created_at: string;
  is_deleted?: boolean;
  is_pinned?: boolean;
  quoted_message?: QuotedMessageInfo;
  forward_message?: ForwardMessageInfo;
}

export interface SendMessagePayload {
  content: string;
  message_type?: MessageType;
  quoted_message_id?: string;
}

export interface SendMessageResponse {
  message: MessageInfo;
}

export class MessageApi {
  static listMessages(
    roomId: string,
    params: { limit?: number; before_id?: string; since_id?: string } = {},
  ): Promise<ApiResponse<MessageInfo[]>> {
    return get<MessageInfo[]>(`/rooms/${roomId}/messages`, params);
  }

  static sendMessage(
    roomId: string,
    payload: SendMessagePayload,
  ): Promise<ApiResponse<SendMessageResponse>> {
    return post<SendMessageResponse>(
      `/rooms/${roomId}/messages`,
      payload,
    );
  }

  static deleteMessage(
    roomId: string,
    messageId: string,
  ): Promise<ApiResponse<{ ok: boolean }>> {
    return del<{ ok: boolean }>(
      `/rooms/${roomId}/messages/${messageId}`,
    );
  }

  static markRead(
    roomId: string,
    messageId?: string,
  ): Promise<ApiResponse<{ ok: boolean }>> {
    return post<{ ok: boolean }>(`/rooms/${roomId}/messages/read`, {
      message_id: messageId,
    });
  }
}
