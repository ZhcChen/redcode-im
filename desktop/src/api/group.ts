/**
 * 群聊相关 API 接口
 * 包含群聊管理、群成员管理、红包转账等功能
 */

import { post } from './http';
import type { ApiResponse } from './http';

/**
 * 群聊信息接口（对应后端API的完整三对象结构）
 */
export interface ChatGroupInfo {
  // 保持兼容性的旧字段（可选）
  id?: string;
  name?: string;
  avatar?: string;
  description?: string;
  ownerId?: string;
  ownerName?: string;
  memberCount?: number;
  maxMembers?: number;
  isPublic?: boolean;
  isMuted?: boolean; // 是否全体禁言
  status?: number;
  createTime?: string;
  updateTime?: string;
  
  // 新增：完整的三对象结构（对应实际API响应）
  imGroup: {
    groupId: string;
    groupName: string;
    groupCode: string;
    groupAvatar: string | null;
    groupNotice: string | null;
    groupType: number; // 0=单聊, 1=群聊
    groupStatus: number;
    maxMemberCount: number;
    canAddFriendFlag: number;
    createUser: number;
    createTime: string;
    updateTime: string | null;
    showNoticeFlag: number;
    remark: string | null;
    memberCounts: number | null;
    friendUserId: number;
    delFlag: number;
  };
  
  groupUser: {
    id: number;
    userId: number;
    groupId: string;
    chatStatus: number;
    topFlag: number; // 0=不置顶, 1=置顶
    memberType: number;
    saveFlag: number;
    createUser: number;
    readTime: string;
    createTime: string;
    clearTime: string | null;
    remark: string | null;
    delFlag: number;
    unReadNum: number; // 未读消息数量
    hiddenFlag: number; // 0=显示, 1=隐藏
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
    msgFromUserId: number;
    msgFromPlat: number;
    msgContent: string; // JSON格式的消息内容
    msgContentType: number;
    msgSearchWords: string;
    createTime: string;
    delFlag: number;
    lastMsgContent: string; // 解析后的最后消息内容
    userAvatar: string | null;
    userName: string;
    meFlag: boolean;
    revertFlag: boolean;
  };
}

/**
 * 群成员信息接口
 */
export interface GroupMemberInfo {
  id: string;
  groupId: string;
  userId: string;
  username: string;
  nickname: string;
  avatar: string;
  role: number; // 1: 群主, 2: 管理员, 3: 普通成员
  isMuted: boolean; // 是否被禁言
  joinTime: string;
}

/**
 * 红包信息接口
 */
export interface RedPacketInfo {
  id: string;
  senderId: string;
  senderName: string;
  groupId?: string;
  receiverId?: string;
  amount: number;
  count: number; // 红包个数
  message: string;
  type: number; // 1: 单聊红包, 2: 群聊红包
  status: number; // 1: 未领取, 2: 已领取, 3: 已过期
  createTime: string;
  expireTime: string;
}

/**
 * 转账信息接口
 */
export interface TransferInfo {
  id: string;
  senderId: string;
  senderName: string;
  receiverId: string;
  receiverName: string;
  amount: number;
  message: string;
  status: number; // 1: 待接收, 2: 已接收, 3: 已退回
  createTime: string;
  expireTime: string;
}

/**
 * 群聊 API 接口类
 */
export class GroupApi {
  /**
   * 获取我的群聊列表
   * @param params 查询参数 { page?: 页码, size?: 每页数量, keyword?: 搜索关键词 }
   * @returns Promise<ApiResponse<ChatGroupInfo[]>> 群聊列表
   */
  static async getMyChatGroupList(params: { page?: number; size?: number; keyword?: string } = {}): Promise<ApiResponse<ChatGroupInfo[]>> {
    return post<ChatGroupInfo[]>('imChatGroup/getMyChatGroupList', params);
  }

  /**
   * 获取我加入的群聊列表
   * @param params 查询参数 { page?: 页码, size?: 每页数量, keyword?: 搜索关键词 }
   * @returns Promise<ApiResponse<ChatGroupInfo[]>> 加入的群聊列表
   */
  static async getMyJoinChatGroupList(params: { page?: number; size?: number; keyword?: string } = {}): Promise<ApiResponse<ChatGroupInfo[]>> {
    return post<ChatGroupInfo[]>('imChatGroup/getMyJoinChatGroupList', params);
  }

  /**
   * 获取群聊信息 - 使用与bear-chat-uniapp一致的参数名
   * @param params 查询参数 { chatGroupId: 群组ID }
   * @returns Promise<ApiResponse<ChatGroupInfo>> 群聊详细信息
   */
  static async getChatGroupInfo(params: { chatGroupId: string }): Promise<ApiResponse<ChatGroupInfo>> {
    console.log('📤 获取群组详情API调用，参数:', params);
    return post<ChatGroupInfo>('imChatGroup/getChatGroupInfo', params);
  }

  /**
   * 设置群聊信息（包括全体禁言）
   * @param params 设置参数 { groupId: 群组ID, name?: 群名称, description?: 群描述, isMuted?: 是否全体禁言 }
   * @returns Promise<ApiResponse<any>> 设置结果
   */
  static async updateGroupStatus(params: { groupId: string; name?: string; description?: string; isMuted?: boolean }): Promise<ApiResponse<any>> {
    return post('imChatGroup/setChatGroupInfo', params);
  }

  /**
   * 获取群成员列表 - 使用与bear-chat-uniapp一致的参数名
   * @param params 查询参数 { chatGroupId: 群组ID, limitFlag?: 限制条数标志 }
   * @returns Promise<ApiResponse<GroupMemberInfo[]>> 群成员列表
   */
  static async getChatGroupMembers(params: { chatGroupId: string; limitFlag?: number }): Promise<ApiResponse<GroupMemberInfo[]>> {
    console.log('📤 获取群成员列表API调用，参数:', params);
    return post<GroupMemberInfo[]>('imChatGroup/getChatGroupMembers', params);
  }

  /**
   * 创建单聊
   * @param params 创建参数 { fromUser: 发起用户ID, toUser: 目标用户ID, friendName: 好友名称 }
   * @returns Promise<ApiResponse<any>> 创建结果
   */
  static async createSingleChat(params: { fromUser: string; toUser: string; friendName: string }): Promise<ApiResponse<any>> {
    return post('imChatGroup/createSingleChat', params);
  }

  /**
   * 发起群聊 - 与bear-chat-uniapp保持一致的参数结构
   * @param params 创建参数
   * @returns Promise<ApiResponse<any>> 创建结果
   */
  static async launchChatGroup(params: {
    createUser: string;           // 创建者用户ID
    chatGroupName: string;        // 群名称
    chatGroupMembers: string[];   // 成员用户ID列表（必须包含创建者）
    maxCount?: number;            // 最大成员数，默认500
    chatGroupAvatar?: string;     // 群头像URL（可选）
  }): Promise<ApiResponse<any>> {
    console.log('📤 发起群聊API调用，参数:', params);
    return post('imChatGroup/launchChatGroup', params);
  }

  /**
   * 更新群聊信息 - 使用与bear-chat-uniapp一致的字段名
   * @param params 更新参数
   * @returns Promise<ApiResponse<any>> 更新结果
   */
  static async updateGroupInfo(params: {
    groupId: string;
    groupName?: string;       // 群名称
    groupAvatar?: string;     // 群头像
    groupNotice?: string;     // 群公告内容
    showNoticeFlag?: number;  // 公告显示标志 (0=隐藏, 1=显示)
    description?: string;
  }): Promise<ApiResponse<any>> {
    console.log('📤 更新群聊信息API调用，参数:', params);
    return post('imChatGroup/updateGroupInfo', params);
  }
}

/**
 * 群成员管理 API 接口类
 */
export class GroupMemberApi {

  /**
   * 检查是否被屏蔽
   * @param params 检查参数 { groupId: 群组ID, userId?: 用户ID }
   * @returns Promise<ApiResponse<any>> 屏蔽状态
   */
  static async getChatPingBiFlag(params: { groupId: string; userId?: string }): Promise<ApiResponse<any>> {
    return post('imGroupUser/getChatPingBiFlag', params);
  }

  /**
   * 清空我的聊天记录
   * @param params 清空参数 { groupId: 群组ID }
   * @returns Promise<ApiResponse<any>> 清空结果
   */
  static async clearChatMessage(params: { groupId: string }): Promise<ApiResponse<any>> {
    return post('imGroupUser/clearChatMessage', params);
  }

  /**
   * 解散群组
   * @param params 解散参数 { groupId: 群组ID }
   * @returns Promise<ApiResponse<any>> 解散结果
   */
  static async delChatGroup(params: { groupId: string }): Promise<ApiResponse<any>> {
    return post('imGroupUser/delChatGroup', params);
  }

  /**
   * 退出群组
   * @param params 退出参数 { groupId: 群组ID }
   * @returns Promise<ApiResponse<any>> 退出结果
   */
  static async quitChatGroup(params: { groupId: string }): Promise<ApiResponse<any>> {
    return post('imGroupUser/quitChatGroup', params);
  }

  /**
   * 删除群成员
   * @param params 删除参数 { groupId: 群组ID, memberIds: 成员用户ID列表 }
   * @returns Promise<ApiResponse<any>> 删除结果
   */
  static async deleteMemberForGroup(params: { groupId: string; memberIds: string[] }): Promise<ApiResponse<any>> {
    return post('imGroupUser/deleteMemberForGroup', params);
  }

  /**
   * 添加群成员
   * @param params 添加参数 { groupId: 群组ID, memberIds: 成员用户ID列表 }
   * @returns Promise<ApiResponse<any>> 添加结果
   */
  static async addMemberForGroup(params: { groupId: string; memberIds: string[] }): Promise<ApiResponse<any>> {
    return post('imGroupUser/addMemberForGroup', params);
  }

  /**
   * 获取音视频通话的群成员信息
   * @param params 查询参数 { groupId: 群组ID }
   * @returns Promise<ApiResponse<GroupMemberInfo[]>> 通话成员列表
   */
  static async getChatGroupTrcMembers(params: { groupId: string }): Promise<ApiResponse<GroupMemberInfo[]>> {
    return post<GroupMemberInfo[]>('imGroupUser/getChatGroupTrcMembers', params);
  }

  /**
   * 更新我的群聊设置（包括已读时间、未读数量等）
   * @param params 群组设置参数 - 完整的groupUser对象
   * @returns Promise<ApiResponse<any>> 更新结果
   */
  static async updateMyGroupSet(params: {
    id?: number;
    userId: number | string;
    groupId: string; // 注意：这里是groupId而不是chatGroupId
    chatStatus?: number;
    topFlag?: number;
    memberType?: number;
    saveFlag?: number;
    createUser?: number;
    readTime?: string;
    createTime?: string;
    clearTime?: string | null;
    remark?: string | null;
    delFlag?: number;
    unReadNum?: number;
    hiddenFlag?: number;
    showOptionFlag?: boolean;
    pushClientId?: string | null;
    userName?: string | null;
    friendName?: string | null;
    userAvatar?: string | null;
  }): Promise<ApiResponse<any>> {
    return post('imGroupUser/updateMyGroupSet', params);
  }
}

/**
 * 红包转账 API 接口类
 */
export class RedPacketApi {
  /**
   * 发红包（单聊）
   * @param params 红包参数 { receiverId: 接收者ID, amount: 金额, message?: 祝福语 }
   * @returns Promise<ApiResponse<any>> 发送结果
   */
  static async sendRedBag(params: { receiverId: string; amount: number; message?: string }): Promise<ApiResponse<any>> {
    return post('imGroupUser/sendRedBag', params);
  }

  /**
   * 发转账（单聊）
   * @param params 转账参数 { receiverId: 接收者ID, amount: 金额, message?: 转账说明 }
   * @returns Promise<ApiResponse<any>> 发送结果
   */
  static async sendTransfer(params: { receiverId: string; amount: number; message?: string }): Promise<ApiResponse<any>> {
    return post('imGroupUser/sendTransfer', params);
  }

  /**
   * 发红包（群聊）
   * @param params 红包参数 { groupId: 群组ID, amount: 总金额, count: 红包个数, message?: 祝福语 }
   * @returns Promise<ApiResponse<any>> 发送结果
   */
  static async sendRedBagForGroup(params: { groupId: string; amount: number; count: number; message?: string }): Promise<ApiResponse<any>> {
    return post('imGroupUser/sendRedBagForGroup', params);
  }

  /**
   * 领红包（单聊）
   * @param params 领取参数 { redBagId: 红包ID }
   * @returns Promise<ApiResponse<any>> 领取结果
   */
  static async receiveRedBag(params: { redBagId: string }): Promise<ApiResponse<any>> {
    return post('imGroupUser/receviceRedBag', params);
  }

  /**
   * 领取转账
   * @param params 领取参数 { transferId: 转账ID }
   * @returns Promise<ApiResponse<any>> 领取结果
   */
  static async receiveTransfer(params: { transferId: string }): Promise<ApiResponse<any>> {
    return post('imGroupUser/receiveTransfer', params);
  }

  /**
   * 查询转账接收记录
   * @param params 查询参数 { transferId: 转账ID }
   * @returns Promise<ApiResponse<any>> 接收记录
   */
  static async getTransferReceiveRecords(params: { transferId: string }): Promise<ApiResponse<any>> {
    return post('imGroupUser/getTransferReceiveRecords', params);
  }

  /**
   * 抢群聊红包
   * @param params 抢红包参数 { redBagId: 红包ID }
   * @returns Promise<ApiResponse<any>> 抢红包结果
   */
  static async receiveRedBagForGroup(params: { redBagId: string }): Promise<ApiResponse<any>> {
    return post('imGroupUser/receviceRedBagForGroup', params);
  }

  /**
   * 获取红包领取记录
   * @param params 查询参数 { redBagId: 红包ID }
   * @returns Promise<ApiResponse<any[]>> 领取记录列表
   */
  static async getRedBagReceiveList(params: { redBagId: string }): Promise<ApiResponse<any[]>> {
    return post('imGroupUser/getRedBagReceiveList', params);
  }
}
