import { del, get, post } from './http';
import type { ApiResponse } from './http';

type BackendMessageType = 'text' | 'image' | 'audio' | 'video' | 'file' | 'system';

interface BackendMessageInfo {
  id: string;
  room_id: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string | null;
  sender_avatar_url?: string | null;
  content: string;
  message_type: BackendMessageType;
  created_at: string;
  quoted_message?: BackendQuotedMessage | null;
  forward_message?: BackendForwardMessage | null;
  is_deleted: boolean;
  deleted_at?: string | null;
  is_pinned: boolean;
  pinned_at?: string | null;
  pinned_by?: string | null;
}

interface BackendQuotedMessage {
  id: string;
  room_id: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string | null;
  content?: string | null;
  message_type: BackendMessageType;
  created_at?: string | null;
  is_deleted: boolean;
}

interface BackendForwardMessage {
  message_id: string;
  room_id: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string | null;
}

interface BackendEnsureChatResponse {
  room_id: string;
  room_name: string;
  room_type: string;
  friend_id: string;
  friend_name: string;
  friend_avatar?: string | null;
}

const MESSAGE_TYPE_CODE: Record<BackendMessageType, number> = {
  text: 1,
  image: 2,
  audio: 3,
  video: 4,
  file: 5,
  system: 9,
};

const MESSAGE_CONTENT_TYPE: Record<BackendMessageType, number> = {
  text: 1,
  image: 2,
  audio: 3,
  video: 4,
  file: 5,
  system: 9,
};

export interface MessageInfo {
  id: string;
  groupId: string;
  userId: string;
  userName: string;
  userAvatar: string | null;
  messageType: number;
  contentType: number;
  content: {
    text?: string;
    raw?: string;
  };
  createTime: string;
  timestamp: number;
  meFlag: boolean;
  showTimeFlag: boolean;
  senderId: string;
  senderName: string;
  senderAvatar: string | null;
  status: number;
  quotedMessageId?: string | null;
  quotedMessageContent?: string | null;
}

export interface GetMessageListParams {
  groupId: string;
  page?: number;
  size?: number;
  lastMessageId?: string;
}

const mapBackendMessage = (message: BackendMessageInfo): MessageInfo => {
  const createdAt = message.created_at;
  const senderName = message.sender_nickname?.trim()
    ? message.sender_nickname
    : message.sender_username;
  const typeCode = MESSAGE_TYPE_CODE[message.message_type] ?? 1;
  const now = Date.parse(createdAt);

  return {
    id: message.id,
    groupId: message.room_id,
    userId: message.sender_id,
    userName: senderName ?? '未知用户',
    userAvatar: message.sender_avatar_url ?? null,
    senderId: message.sender_id,
    senderName: senderName ?? '未知用户',
    senderAvatar: message.sender_avatar_url ?? null,
    messageType: typeCode,
    contentType: MESSAGE_CONTENT_TYPE[message.message_type] ?? 1,
    content: {
      text: message.content,
      raw: message.content,
    },
    createTime: createdAt,
    timestamp: Number.isNaN(now) ? Date.now() : now,
    meFlag: false,
    showTimeFlag: true,
    status: 2,
    quotedMessageId: message.quoted_message?.id ?? null,
    quotedMessageContent: message.quoted_message?.content ?? null,
  };
};

const buildMessageQuery = (params: GetMessageListParams): Record<string, string> => {
  const query: Record<string, string> = {};
  if (params.size) {
    query.limit = String(params.size);
  }
  if (params.lastMessageId) {
    query.before_id = params.lastMessageId;
  }
  return query;
};

export class MessageApi {
  static async getMessageListByChatGroupId(params: GetMessageListParams): Promise<ApiResponse<MessageInfo[]>> {
    const query = buildMessageQuery(params);
    const response = await get<BackendMessageInfo[]>(
      `/rooms/${params.groupId}/messages`,
      query,
    );

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const mapped = response.data.map(mapBackendMessage);
    return {
      ...response,
      data: mapped,
    };
  }

  static async sendTextMessage(params: { groupId: string; content: string; replyToMessageId?: string }): Promise<ApiResponse<MessageInfo>> {
    const payload: Record<string, any> = {
      content: params.content,
      message_type: 'text',
    };

    if (params.replyToMessageId) {
      payload.quoted_message_id = params.replyToMessageId;
    }

    const response = await post<BackendMessageInfo>(
      `/rooms/${params.groupId}/messages`,
      payload,
    );

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: mapBackendMessage(response.data),
    };
  }

  static async sendImageMessage(): Promise<ApiResponse<null>> {
    return {
      code: 501,
      success: false,
      message: '图片消息发送功能尚未对接后端，请稍后再试',
      data: null,
    };
  }

  static async sendAudioMessage(): Promise<ApiResponse<null>> {
    return {
      code: 501,
      success: false,
      message: '语音消息发送功能尚未对接后端，请稍后再试',
      data: null,
    };
  }

  static async sendVideoMessage(): Promise<ApiResponse<null>> {
    return {
      code: 501,
      success: false,
      message: '视频消息发送功能尚未对接后端，请稍后再试',
      data: null,
    };
  }

  static async sendFileMessage(): Promise<ApiResponse<null>> {
    return {
      code: 501,
      success: false,
      message: '文件消息发送功能尚未对接后端，请稍后再试',
      data: null,
    };
  }

  static async sendLocationMessage(): Promise<ApiResponse<null>> {
    return {
      code: 501,
      success: false,
      message: '位置消息发送功能尚未对接后端，请稍后再试',
      data: null,
    };
  }

  static async markMessagesAsRead(params: { groupId: string; messageIds: string[] }): Promise<ApiResponse<unknown>> {
    const lastMessageId = params.messageIds[params.messageIds.length - 1];
    if (!lastMessageId) {
      return {
        code: 400,
        success: false,
        message: '缺少消息ID，无法标记为已读',
        data: null,
      };
    }

    return post(`/rooms/${params.groupId}/messages/read_until`, {
      message_id: lastMessageId,
    });
  }

  static async getUnreadMessageCount(params: { groupId?: string } = {}): Promise<ApiResponse<any>> {
    if (params.groupId) {
      return get(`/rooms/${params.groupId}/unread_count`);
    }
    return get('/unread_counts');
  }

  static async deleteMessages(params: { groupId: string; messageId: string }): Promise<ApiResponse<null>> {
    const response = await del<unknown>(`/rooms/${params.groupId}/messages/${params.messageId}`);
    return {
      ...response,
      data: null,
    };
  }

  static async forwardMessages(): Promise<ApiResponse<null>> {
    return {
      code: 501,
      success: false,
      message: '当前版本暂未提供消息转发能力',
      data: null,
    };
  }
}

export enum MessageType {
  TEXT = 1,
  IMAGE = 2,
  AUDIO = 3,
  VIDEO = 4,
  FILE = 5,
  LOCATION = 6,
  RED_PACKET = 7,
  TRANSFER = 8,
  SYSTEM = 9,
}
