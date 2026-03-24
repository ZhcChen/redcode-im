import type { ApiResponse } from "./http";

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

export interface FriendUser {
  id: string;
  username: string;
  email: string | null;
  nickname: string | null;
  avatarUrl: string | null;
  avatarObjectKey: string | null;
  status: string | null;
}

export interface FriendInfo {
  id: string;
  user: FriendUser;
  createdAt: Date;
  friendRemark: string | null;
}

export interface FriendRequestInfo {
  id: string;
  requester: FriendUser;
  addressee: FriendUser;
  status: BackendFriendRequestStatus;
  createdAt: Date;
  respondedAt: Date | null;
  message: string | null;
  isIncoming: boolean;
}

const requireDesktopRuntime = () => {
  if (!window.desktopEl) {
    throw new Error("desktop-el runtime is not available");
  }
  return window.desktopEl;
};

const parseTimestamp = (value: string): Date => {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return new Date();
  }
  return parsed;
};

const mapFriendUser = (user: BackendUserSummary): FriendUser => ({
  id: user.id,
  username: user.username,
  email: user.email ?? null,
  nickname: user.nickname ?? null,
  avatarUrl: user.avatar_url ?? null,
  avatarObjectKey: user.avatar_object_key ?? null,
  status: user.status ?? null
});

const mapFriendInfo = (info: BackendFriendInfo): FriendInfo => ({
  id: info.id,
  user: mapFriendUser(info.user),
  createdAt: parseTimestamp(info.created_at),
  friendRemark: info.friend_remark ?? null
});

const mapFriendRequest = (request: BackendFriendRequestInfo): FriendRequestInfo => ({
  id: request.id,
  requester: mapFriendUser(request.requester),
  addressee: mapFriendUser(request.addressee),
  status: request.status,
  createdAt: parseTimestamp(request.created_at),
  respondedAt: request.responded_at ? parseTimestamp(request.responded_at) : null,
  message: request.message ?? null,
  isIncoming: Boolean(request.is_incoming)
});

export class FriendApi {
  static async getMyFriendList(): Promise<ApiResponse<FriendInfo[]>> {
    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendFriendInfo[]>>("friend.list");
    return {
      ...response,
      data: response.data ? response.data.map(mapFriendInfo) : null
    };
  }

  static async getFriendRequests(params: {
    direction?: "incoming" | "outgoing";
    status?: BackendFriendRequestStatus;
  } = {}): Promise<ApiResponse<FriendRequestInfo[]>> {
    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendFriendRequestInfo[]>>(
      "friend.requests.list",
      {
        direction: params.direction ?? "incoming",
        status: params.status
      }
    );
    return {
      ...response,
      data: response.data ? response.data.map(mapFriendRequest) : null
    };
  }

  static async handleFriendRequest(params: {
    requestId: string;
    action: "accept" | "decline";
  }): Promise<ApiResponse<FriendRequestInfo>> {
    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendFriendRequestInfo>>(
      "friend.request.respond",
      {
        request_id: params.requestId,
        action: params.action
      }
    );
    return {
      ...response,
      data: response.data ? mapFriendRequest(response.data) : null
    };
  }
}
