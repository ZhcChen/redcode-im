import { del, get, patch, post } from "./http";
import type { ApiResponse } from "./http";
import type {
  AuthUser,
  FriendInfo,
  FriendRequestInfo,
  EnsureChatResult,
} from "@/types/models";
import { FriendRequestStatus } from "@/types/models";

type BackendFriendRequestStatus = "pending" | "accepted" | "declined";

interface BackendUserSummary {
  id: string;
  username: string;
  nickname?: string | null;
  avatar_url?: string | null;
  avatar_object_key?: string | null;
  email?: string | null;
  status?: string | null;
}

interface BackendFriendInfo {
  id: string;
  user: BackendUserSummary;
  created_at: string;
  friend_remark?: string | null;
}

interface BackendFriendRequestInfo {
  id: string;
  requester: BackendUserSummary;
  addressee: BackendUserSummary;
  status: BackendFriendRequestStatus;
  message?: string | null;
  created_at: string;
  responded_at?: string | null;
  is_incoming: boolean;
}

interface BackendEnsureChatResponse {
  room_id: string;
  room_name: string;
  room_type: string;
  friend_id: string;
  friend_name: string;
  friend_avatar?: string | null;
}

const parseTimestamp = (value: string): Date => {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return new Date();
  }
  return parsed;
};

const mapAuthUser = (user: BackendUserSummary): AuthUser => {
  const mapped = {
    id: user.id,
    username: user.username,
    email: user.email ?? null,
    nickname: user.nickname ?? null,
    avatarUrl: user.avatar_url ?? null,
    avatarObjectKey: user.avatar_object_key ?? null,
    status: user.status ?? null,
  };

  console.log('🔄 [mapAuthUser] 映射用户数据:', {
    原始: { avatar_url: user.avatar_url, avatar_object_key: user.avatar_object_key },
    映射后: { avatarUrl: mapped.avatarUrl, avatarObjectKey: mapped.avatarObjectKey }
  });

  return mapped;
};

const parseFriendRequestStatus = (
  status: BackendFriendRequestStatus,
): FriendRequestStatus => {
  switch (status) {
    case "accepted":
      return FriendRequestStatus.ACCEPTED;
    case "declined":
      return FriendRequestStatus.DECLINED;
    case "pending":
    default:
      return FriendRequestStatus.PENDING;
  }
};

const mapFriendInfo = (info: BackendFriendInfo): FriendInfo => ({
  id: info.id,
  user: mapAuthUser(info.user),
  createdAt: parseTimestamp(info.created_at),
  friendRemark: info.friend_remark ?? null,
});

const mapFriendRequest = (
  request: BackendFriendRequestInfo,
): FriendRequestInfo => ({
  id: request.id,
  requester: mapAuthUser(request.requester),
  addressee: mapAuthUser(request.addressee),
  status: parseFriendRequestStatus(request.status),
  createdAt: parseTimestamp(request.created_at),
  respondedAt: request.responded_at
    ? parseTimestamp(request.responded_at)
    : null,
  message: request.message ?? null,
  isIncoming: Boolean(request.is_incoming),
});

export class FriendApi {
  static async getMyFriendList(
    params: {
      keyword?: string;
      page?: number;
      size?: number;
    } = {},
  ): Promise<ApiResponse<FriendInfo[]>> {
    const response = await get<BackendFriendInfo[]>("/friends");

    console.log('🔍 [FriendApi.getMyFriendList] 后端原始响应:', JSON.stringify(response.data, null, 2));

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const keyword = params.keyword?.trim().toLowerCase() ?? "";
    const mapped = response.data.map(mapFriendInfo).filter((friend) => {
      if (!keyword) {
        return true;
      }
      const user = friend.user;
      const nickname = user.nickname?.toLowerCase() ?? "";
      const email = user.email?.toLowerCase() ?? "";
      return (
        user.username.toLowerCase().includes(keyword) ||
        nickname.includes(keyword) ||
        email.includes(keyword)
      );
    });

    return {
      ...response,
      data: mapped,
    };
  }

  static async addFriend(params: {
    friendId: string;
    description?: string;
  }): Promise<ApiResponse<FriendRequestInfo>> {
    const payload = {
      target_user_id: String(params.friendId),
      message: params.description,
    };

    const response = await post<BackendFriendRequestInfo>(
      "/friends/requests",
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
      data: mapFriendRequest(response.data),
    };
  }

  static async getFriendRequests(
    params: {
      direction?: "incoming" | "outgoing";
      status?: FriendRequestStatus;
    } = {},
  ): Promise<ApiResponse<FriendRequestInfo[]>> {
    const query = new URLSearchParams();
    query.set("direction", params.direction ?? "incoming");

    if (params.status !== undefined) {
      let backendStatus: BackendFriendRequestStatus | null = null;
      switch (params.status) {
        case FriendRequestStatus.ACCEPTED:
          backendStatus = "accepted";
          break;
        case FriendRequestStatus.DECLINED:
          backendStatus = "declined";
          break;
        case FriendRequestStatus.PENDING:
          backendStatus = "pending";
          break;
        default:
          backendStatus = null;
      }
      if (backendStatus) {
        query.set("status", backendStatus);
      }
    }

    const response = await get<BackendFriendRequestInfo[]>(
      `/friends/requests${query.toString() ? `?${query.toString()}` : ""}`,
    );

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: response.data.map(mapFriendRequest),
    };
  }

  static async getPendingFriendRequestCount(): Promise<ApiResponse<number>> {
    const response = await FriendApi.getFriendRequests({
      direction: "incoming",
      status: FriendRequestStatus.PENDING,
    });

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const pendingCount = response.data.filter(
      (request) => request.isIncoming,
    ).length;
    return {
      code: 200,
      success: true,
      message: "ok",
      data: pendingCount,
    };
  }

  static async handleFriendRequest(params: {
    requestId: string;
    action: "accept" | "decline";
  }): Promise<ApiResponse<FriendRequestInfo>> {
    const response = await post<BackendFriendRequestInfo>(
      `/friends/requests/${params.requestId}/respond`,
      {
        action: params.action,
      },
    );

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: mapFriendRequest(response.data),
    };
  }

  static async cancelFriendRequest(params: {
    requestId: string;
  }): Promise<ApiResponse<null>> {
    const response = await del(`/friends/requests/${params.requestId}`);
    return {
      ...response,
      data: null,
    };
  }

  static async ensureChat(params: {
    friendId: string;
  }): Promise<ApiResponse<EnsureChatResult>> {
    const response = await post<BackendEnsureChatResponse>(
      `/friends/${params.friendId}/chat`,
      {},
    );
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
        roomName: response.data.room_name,
        roomType: response.data.room_type,
        friendId: response.data.friend_id,
        friendName: response.data.friend_name,
        friendAvatar: response.data.friend_avatar ?? null,
      },
    };
  }

  static async updateRemark(params: {
    friendId: string;
    remark: string | null;
  }): Promise<ApiResponse<{ remark: string | null }>> {
    const response = await patch<{ remark: string | null }>(
      `/friends/${params.friendId}/remark`,
      {
        remark: params.remark,
      },
    );

    return response;
  }
}
