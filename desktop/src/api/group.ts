import { get, post } from './http';
import type { ApiResponse } from './http';

type RoomType = 'private' | 'group' | 'public' | 'favorite';
type MemberRole = 'owner' | 'admin' | 'member';

interface BackendChatMessagePreview {
  id: string;
  content: string;
  message_type: string;
  created_at: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string | null;
}

interface BackendChatSummary {
  room_id: string;
  name: string;
  room_type: RoomType;
  avatar_url?: string | null;
  description?: string | null;
  unread_count: number;
  last_read_message_id?: string | null;
  last_read_at?: string | null;
  last_message?: BackendChatMessagePreview | null;
}

interface BackendRoomInfo {
  id: string;
  name: string;
  description?: string | null;
  avatar_url?: string | null;
  room_type: RoomType;
  owner_id: string;
  created_at: string;
}

interface BackendRoomMember {
  user_id: string;
  role: MemberRole;
}

export interface ChatGroupInfo {
  imGroup: {
    groupId: string;
    groupName: string;
    groupCode: string;
    groupAvatar: string | null;
    groupNotice: string | null;
    groupType: number;
    groupStatus: number;
    maxMemberCount: number;
    canAddFriendFlag: number;
    createUser: string;
    createTime: string;
    updateTime: string | null;
    showNoticeFlag: number;
    remark: string | null;
    memberCounts: number | null;
    friendUserId: string | null;
    delFlag: number;
  };
  groupUser: {
    id: string;
    userId: string;
    groupId: string;
    chatStatus: number;
    topFlag: number;
    memberType: number;
    saveFlag: number;
    createUser: string;
    readTime: string;
    createTime: string;
    clearTime: string | null;
    remark: string | null;
    delFlag: number;
    unReadNum: number;
    hiddenFlag: number;
    showOptionFlag: boolean;
    pushClientId: string | null;
    userName: string | null;
    friendName: string | null;
    userAvatar: string | null;
  };
  imGroupMessageRef: {
    msgId: string;
    msgGroupId: string;
    msgType: number;
    msgFromUserId: string;
    msgFromPlat: number;
    msgContent: string;
    msgContentType: number;
    msgSearchWords: string;
    createTime: string;
    delFlag: number;
    lastMsgContent: string;
    userAvatar: string | null;
    userName: string | null;
    meFlag: boolean;
    revertFlag: boolean;
  };
}

export interface GroupMemberInfo {
  id: string;
  groupId: string;
  userId: string;
  username: string;
  nickname: string;
  avatar: string;
  role: number;
  isMuted: boolean;
  joinTime: string;
}

const DEFAULT_REST_CHAT_GROUP_INFO: ChatGroupInfo = {
  imGroup: {
    groupId: '',
    groupName: '',
    groupCode: '',
    groupAvatar: null,
    groupNotice: null,
    groupType: 0,
    groupStatus: 1,
    maxMemberCount: 500,
    canAddFriendFlag: 1,
    createUser: '',
    createTime: '',
    updateTime: null,
    showNoticeFlag: 0,
    remark: null,
    memberCounts: null,
    friendUserId: null,
    delFlag: 0,
  },
  groupUser: {
    id: '',
    userId: '',
    groupId: '',
    chatStatus: 1,
    topFlag: 0,
    memberType: 3,
    saveFlag: 1,
    createUser: '',
    readTime: '',
    createTime: '',
    clearTime: null,
    remark: null,
    delFlag: 0,
    unReadNum: 0,
    hiddenFlag: 0,
    showOptionFlag: true,
    pushClientId: null,
    userName: null,
    friendName: null,
    userAvatar: null,
  },
  imGroupMessageRef: {
    msgId: '',
    msgGroupId: '',
    msgType: 1,
    msgFromUserId: '',
    msgFromPlat: 1,
    msgContent: '',
    msgContentType: 1,
    msgSearchWords: '',
    createTime: '',
    delFlag: 0,
    lastMsgContent: '',
    userAvatar: null,
    userName: null,
    meFlag: false,
    revertFlag: false,
  },
};

const toLegacyGroup = (summary: BackendChatSummary): ChatGroupInfo => {
  const base: ChatGroupInfo = JSON.parse(JSON.stringify(DEFAULT_REST_CHAT_GROUP_INFO));

  base.imGroup.groupId = summary.room_id;
  base.imGroup.groupName = summary.name;
  base.imGroup.groupAvatar = summary.avatar_url ?? null;
  base.imGroup.groupType = summary.room_type === 'group' ? 1 : 0;
  base.imGroup.groupNotice = summary.description ?? null;
  base.imGroup.createTime = summary.last_message?.created_at ?? new Date().toISOString();
  base.imGroup.memberCounts = null;

  base.groupUser.groupId = summary.room_id;
  base.groupUser.unReadNum = summary.unread_count ?? 0;
  base.groupUser.readTime = summary.last_read_at ?? '';
  base.groupUser.createTime = summary.last_message?.created_at ?? new Date().toISOString();

  base.imGroupMessageRef.msgGroupId = summary.room_id;
  base.imGroupMessageRef.msgId = summary.last_message?.id ?? '';
  base.imGroupMessageRef.lastMsgContent = summary.last_message?.content ?? '';
  base.imGroupMessageRef.createTime = summary.last_message?.created_at ?? '';
  base.imGroupMessageRef.userName =
    summary.last_message?.sender_nickname ?? summary.last_message?.sender_username ?? null;

  return base;
};

export class GroupApi {
  static async getMyChatGroupList(): Promise<ApiResponse<ChatGroupInfo[]>> {
    const response = await get<BackendChatSummary[]>('/chats');
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const mapped = response.data.map((item) => toLegacyGroup(item));
    return {
      ...response,
      data: mapped,
    };
  }

  static async getMyJoinChatGroupList(): Promise<ApiResponse<ChatGroupInfo[]>> {
    const response = await get<BackendRoomInfo[]>('/rooms');
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const mapped = response.data.map((room) =>
      toLegacyGroup({
        room_id: room.id,
        name: room.name,
        room_type: room.room_type,
        avatar_url: room.avatar_url,
        description: room.description,
        unread_count: 0,
        last_read_message_id: null,
        last_read_at: null,
        last_message: null,
      }),
    );

    return {
      ...response,
      data: mapped,
    };
  }

  static async getChatGroupInfo(params: { chatGroupId: string }): Promise<ApiResponse<ChatGroupInfo>> {
    const response = await get<BackendRoomInfo[]>('/rooms');
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const room = response.data.find((item) => item.id === params.chatGroupId);
    if (!room) {
      return {
        code: 404,
        success: false,
        message: '未找到对应的房间',
        data: null,
      };
    }

    const adapted = toLegacyGroup({
      room_id: room.id,
      name: room.name,
      room_type: room.room_type,
      avatar_url: room.avatar_url,
      description: room.description,
      unread_count: 0,
      last_read_message_id: null,
      last_read_at: null,
      last_message: null,
    });

    adapted.imGroup.createUser = room.owner_id;
    adapted.imGroup.createTime = room.created_at;

    return {
      ...response,
      data: adapted,
      success: true,
      code: response.code ?? 200,
      message: 'ok',
    };
  }

  static async getChatGroupMembers(params: { chatGroupId: string }): Promise<ApiResponse<GroupMemberInfo[]>> {
    const response = await get<BackendRoomMember[]>(`/rooms/${params.chatGroupId}/members`);
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const members: GroupMemberInfo[] = response.data.map((member) => ({
      id: `${params.chatGroupId}-${member.user_id}`,
      groupId: params.chatGroupId,
      userId: member.user_id,
      username: member.user_id,
      nickname: member.user_id,
      avatar: '',
      role: member.role === 'owner' ? 1 : member.role === 'admin' ? 2 : 3,
      isMuted: false,
      joinTime: new Date().toISOString(),
    }));

    return {
      ...response,
      data: members,
    };
  }

  static async createSingleChat(params: { friendId: string }): Promise<ApiResponse<{ roomId: string }>> {
    const response = await post<{ room_id: string }>(`/friends/${params.friendId}/chat`, {});
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: {
        roomId: response.data.room_id,
      },
    };
  }

  static async launchChatGroup(params: { name: string; memberIds: string[]; description?: string }): Promise<ApiResponse<{ roomId: string }>> {
    const response = await post<{ room: BackendRoomInfo }>('/rooms', {
      name: params.name,
      description: params.description,
      member_ids: params.memberIds,
    });

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: {
        roomId: response.data.room.id,
      },
    };
  }

  static async updateGroupInfo(): Promise<ApiResponse<null>> {
    return {
      code: 501,
      success: false,
      message: '当前后端暂未提供群设置更新能力',
      data: null,
    };
  }
}
