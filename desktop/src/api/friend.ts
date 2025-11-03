import { get, post } from './http';
import type { ApiResponse } from './http';

type BackendFriendRequestStatus = 'pending' | 'accepted' | 'declined';

interface BackendUserSummary {
  id: string;
  username: string;
  nickname?: string | null;
  avatar_url?: string | null;
  email?: string | null;
}

interface BackendFriendInfo {
  id: string;
  user: BackendUserSummary;
  created_at: string;
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

export interface FriendInfo {
  id: string;
  userId: string;
  friendId: string;
  friendName: string;
  friendMobile: string;
  createTime: string;
  status: number;
  avatar?: string;
  nickname?: string;
  remark?: string;
  email?: string;
  description?: string;
  initials?: string;
  isBlocked?: boolean;
  username?: string;
}

export interface FriendGroup {
  firstLetter: string;
  friends: FriendInfo[];
}

export interface FriendListResponse {
  myFriendsIndexList: string[];
  myFriendList: FriendGroup[];
}

export interface FriendApply {
  id: string;
  fromUserId: string;
  toUserId: string;
  message?: string | null;
  status: number;
  createTime: string;
  updateTime?: string | null;
  isIncoming: boolean;
  requesterName: string;
  addresseeName: string;
  userName?: string;
  nickname?: string;
  realName?: string;
  avatar?: string | null;
  mobile?: string | null;
}

const statusMapToNumber: Record<BackendFriendRequestStatus, number> = {
  pending: 0,
  accepted: 1,
  declined: 2
};

const toDisplayName = (user: BackendUserSummary): string => {
  return user.nickname?.trim() || user.username;
};

const toInitial = (name: string): string => {
  if (!name) {
    return '#';
  }
  const trimmed = name.trim();
  if (!trimmed) {
    return '#';
  }
  const firstChar = trimmed.charAt(0).toUpperCase();
  return /^[A-Z]$/.test(firstChar) ? firstChar : '#';
};

const mapFriendInfo = (info: BackendFriendInfo): FriendInfo => {
  const displayName = toDisplayName(info.user);
  return {
    id: info.id,
    userId: info.user.id,
    friendId: info.user.id,
    friendName: displayName,
    friendMobile: '',
    createTime: info.created_at,
    status: 1,
    avatar: info.user.avatar_url || '',
    nickname: info.user.nickname || undefined,
    remark: info.user.nickname || undefined,
    email: info.user.email || undefined,
    description: '',
    initials: toInitial(displayName),
    isBlocked: false,
    username: info.user.username
  };
};

const mapFriendRequest = (request: BackendFriendRequestInfo): FriendApply => ({
  id: request.id,
  fromUserId: request.requester.id,
  toUserId: request.addressee.id,
  message: request.message || '',
  status: statusMapToNumber[request.status],
  createTime: request.created_at,
  updateTime: request.responded_at || null,
  isIncoming: request.is_incoming,
  requesterName: toDisplayName(request.requester),
  addresseeName: toDisplayName(request.addressee),
  userName: toDisplayName(request.requester),
  nickname: request.requester.nickname || undefined,
  realName: toDisplayName(request.requester),
  avatar: request.requester.avatar_url || null,
  mobile: request.requester.username
});

const wrapFriendRequestResponse = (
  response: ApiResponse<BackendFriendRequestInfo>
): ApiResponse<FriendApply> => {
  if (!response.success || !response.data) {
    return {
      ...response,
      data: null
    };
  }

  return {
    ...response,
    data: mapFriendRequest(response.data)
  };
};

export class FriendApi {
  /**
   * 获取好友列表，并按照首字母分组
   */
  static async getMyFriendList(params: { keyword?: string; page?: number; size?: number } = {}): Promise<ApiResponse<FriendListResponse>> {
    const response = await get<BackendFriendInfo[]>('/friends');
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null
      };
    }

    const keyword = params.keyword?.trim().toLowerCase() || '';

    const mappedFriends = response.data
      .map(mapFriendInfo)
      .filter((friend) => {
        if (!keyword) {
          return true;
        }
        return (
          friend.friendName.toLowerCase().includes(keyword) ||
          friend.nickname?.toLowerCase().includes(keyword) ||
          friend.email?.toLowerCase().includes(keyword)
        );
      });

    const grouped = new Map<string, FriendInfo[]>();
    mappedFriends.forEach((friend) => {
      const letter = friend.initials || '#';
      if (!grouped.has(letter)) {
        grouped.set(letter, []);
      }
      grouped.get(letter)!.push(friend);
    });

    const sortedLetters = Array.from(grouped.keys()).sort((a, b) => {
      if (a === '#') return 1;
      if (b === '#') return -1;
      return a.localeCompare(b, 'zh-CN');
    });

    const myFriendList: FriendGroup[] = sortedLetters.map((letter) => ({
      firstLetter: letter,
      friends: grouped
        .get(letter)!
        .slice()
        .sort((a, b) => a.friendName.localeCompare(b.friendName, 'zh-CN'))
    }));

    return {
      ...response,
      data: {
        myFriendsIndexList: sortedLetters,
        myFriendList
      }
    };
  }

  /**
   * 发起添加好友请求
   */
  static async addFriend(params: {
    friendId: string;
    description?: string;
  }): Promise<ApiResponse<FriendApply>> {
    const payload = {
      target_user_id: String(params.friendId),
      message: params.description
    };

    const response = await post<BackendFriendRequestInfo>('/friends/requests', payload);
    return wrapFriendRequestResponse(response);
  }

  /**
   * 查询好友申请列表（默认获取收到的申请）
   */
  static async checkFriendApply(params: { direction?: 'incoming' | 'outgoing'; status?: number } = {}): Promise<ApiResponse<FriendApply[]>> {
    const query = new URLSearchParams();
    const direction = params.direction || 'incoming';
    query.set('direction', direction);

    if (params.status !== undefined) {
      const statusValue = Object.entries(statusMapToNumber).find(([, value]) => value === params.status)?.[0];
      if (statusValue) {
        query.set('status', statusValue);
      }
    }

    const queryString = query.toString();
    const url = `/friends/requests${queryString ? `?${queryString}` : ''}`;
    const response = await get<BackendFriendRequestInfo[]>(url);

    if (!response.success || !response.data) {
      return {
        ...response,
        data: []
      };
    }

    return {
      ...response,
      data: response.data.map(mapFriendRequest)
    };
  }

  /**
   * 获取未处理的好友申请数量
   */
  static async unHandleFriendApply(): Promise<ApiResponse<number>> {
    const response = await FriendApi.checkFriendApply({ direction: 'incoming', status: 0 });
    if (!response.success || !response.data) {
      return {
        ...response,
        data: 0
      };
    }

    const pendingCount = response.data.filter((request) => request.status === 0 && request.isIncoming).length;
    return {
      ...response,
      data: pendingCount
    };
  }

  /**
   * 处理好友申请（status: 1=接受, 2=拒绝）
   */
  static async handleFriendApply(params: {
    requestId?: string;
    applyUserId?: string;
    status: number;
  }): Promise<ApiResponse<FriendApply>> {
    let requestId = params.requestId;
    if (!requestId && params.applyUserId) {
      const requests = await FriendApi.checkFriendApply({ direction: 'incoming' });
      if (requests.success && requests.data) {
        const matched = requests.data.find((item) => item.fromUserId === params.applyUserId);
        requestId = matched?.id;
      }
    }

    if (!requestId) {
      return {
        code: 400,
        success: false,
        message: '缺少好友申请 ID，无法处理',
        data: null
      };
    }

    const action = params.status === 1 ? 'accept' : 'decline';
    const response = await post<BackendFriendRequestInfo>(`/friends/requests/${requestId}/respond`, {
      action
    });
    return wrapFriendRequestResponse(response);
  }
}
