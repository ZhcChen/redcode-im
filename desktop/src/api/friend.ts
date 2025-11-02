/**
 * 好友管理相关 API 接口
 * 包含好友列表、添加删除好友、好友申请处理等功能
 */

import { post } from './http';
import type { ApiResponse } from './http';

/**
 * 好友信息接口 - 单个好友数据
 */
export interface FriendInfo {
  id: number;
  userId: number;
  friendId: number;
  friendName: string;
  friendPower: number;
  friendMobile: string;
  createTime: string;
  delFlag: number;
  description: string;
  initials: string;
  status: number;
  fromWith: string;
  userName: string;
  realName: string;
  chatNumber: string;
  mobile: string;
  address: string;
  isChecked: boolean;
  // 兼容性字段
  nickname?: string;
  avatar?: string;
  remark?: string;
  isBlocked?: boolean;
  updateTime?: string;
}

/**
 * 好友分组信息接口 - 按首字母分组的好友列表
 */
export interface FriendGroup {
  firstLetter: string;
  friends: FriendInfo[];
}

/**
 * 好友列表响应接口 - 完整的 API 响应结构
 */
export interface FriendListResponse {
  myFriendsIndexList: string[];
  myFriendList: FriendGroup[];
}

/**
 * 好友申请信息接口
 */
export interface FriendApply {
  id: string;
  fromUserId: string;
  toUserId: string;
  message: string;
  status: number; // 0: 待处理, 1: 已同意, 2: 已拒绝
  createTime: string;
  updateTime: string;
}

/**
 * 好友管理 API 接口类
 */
export class FriendApi {
  /**
   * 获取我的好友列表
   * @param params 查询参数 { page?: 页码, size?: 每页数量, keyword?: 搜索关键词 }
   * @returns Promise<ApiResponse<FriendListResponse>> 好友列表响应
   */
  static async getMyFriendList(params: { page?: number; size?: number; keyword?: string } = {}): Promise<ApiResponse<FriendListResponse>> {
    return post<FriendListResponse>('imUserFriend/getMyFriendList', params);
  }

  /**
   * 添加好友
   * @param params 添加参数 { friendId: 好友用户ID, friendName?: 好友备注名, friendTag?: 好友标签, friendMobile?: 好友手机号, friendPower?: 权限, description?: 申请描述 }
   * @returns Promise<ApiResponse<any>> 添加结果
   */
  static async addFriend(params: { 
    friendId: number; 
    friendName?: string; 
    friendTag?: string; 
    friendMobile?: string; 
    friendPower?: number; 
    description?: string; 
  }): Promise<ApiResponse<any>> {
    return post('imUserFriend/addFriend', params);
  }

  /**
   * 删除好友
   * @param params 删除参数 { friendId: 好友用户ID }
   * @returns Promise<ApiResponse<any>> 删除结果
   */
  static async deleteFriend(params: { friendId: string }): Promise<ApiResponse<any>> {
    return post('imUserFriend/deleteFriend', params);
  }

  /**
   * 更新好友信息
   * @param params 更新参数 { friendId: 好友用户ID, remark?: 备注名, tags?: 标签 }
   * @returns Promise<ApiResponse<any>> 更新结果
   */
  static async updateFriendInfo(params: { friendId: string; remark?: string; tags?: string[] }): Promise<ApiResponse<any>> {
    return post('imUserFriend/updateFriendInfo', params);
  }

  /**
   * 检查好友申请
   * @param params 检查参数 { fromUserId?: 申请人ID, toUserId?: 被申请人ID }
   * @returns Promise<ApiResponse<FriendApply[]>> 好友申请列表
   */
  static async checkFriendApply(params: { fromUserId?: string; toUserId?: string } = {}): Promise<ApiResponse<FriendApply[]>> {
    return post<FriendApply[]>('imUserFriend/checkFriendApply', params);
  }

  /**
   * 获取未处理的好友申请
   * @param params 查询参数
   * @returns Promise<ApiResponse<FriendApply[]>> 未处理的好友申请列表
   */
  static async unHandleFriendApply(params: Record<string, any> = {}): Promise<ApiResponse<FriendApply[]>> {
    return post<FriendApply[]>('imUserFriend/unHandleFriendApply', params);
  }

  /**
   * 获取未处理的好友申请（方式2）
   * @param params 查询参数
   * @returns Promise<ApiResponse<FriendApply[]>> 未处理的好友申请列表
   */
  static async unHandleFriendApply2(params: Record<string, any> = {}): Promise<ApiResponse<FriendApply[]>> {
    return post<FriendApply[]>('imUserFriend/unHandleFriendApply2', params);
  }

  /**
   * 处理好友申请
   * @param params 处理参数 { applyUserId: 申请用户ID, status: 处理状态 (1: 同意, 2: 拒绝) }
   * @returns Promise<ApiResponse<any>> 处理结果
   */
  static async handleFriendApply(params: { applyUserId: string; status: number }): Promise<ApiResponse<any>> {
    return post('imUserFriend/handleFriendApply', params);
  }

  /**
   * 拉黑/取消拉黑好友
   * @param params 拉黑参数 { friendId: 好友用户ID, isBlocked: 是否拉黑 }
   * @returns Promise<ApiResponse<any>> 操作结果
   */
  static async blackFriend(params: { friendId: string; isBlocked: boolean }): Promise<ApiResponse<any>> {
    return post('imUserFriend/blackFriend', params);
  }

  /**
   * 获取好友详细信息
   * @param params 查询参数 { friendId: 好友用户ID }
   * @returns Promise<ApiResponse<FriendInfo>> 好友详细信息
   */
  static async getFriendInfo(params: { friendId: string }): Promise<ApiResponse<FriendInfo>> {
    return post<FriendInfo>('imUserFriend/getFriendInfo', params);
  }

  /**
   * 获取新好友信息
   * @param params 查询参数 { userId: 用户ID }
   * @returns Promise<ApiResponse<any>> 新好友信息
   */
  static async getNewFriendInfo(params: { userId: string }): Promise<ApiResponse<any>> {
    return post('imUserFriend/getNewFriendInfo', params);
  }

  /**
   * 获取可添加的好友列表
   * @param params 查询参数 { keyword?: 搜索关键词, page?: 页码, size?: 每页数量 }
   * @returns Promise<ApiResponse<any[]>> 可添加的好友列表
   */
  static async getMyFriendListForAdd(params: { keyword?: string; page?: number; size?: number } = {}): Promise<ApiResponse<any[]>> {
    return post('imUserFriend/getMyFriendListForAdd', params);
  }

  /**
   * 获取可删除的好友列表
   * @param params 查询参数 { keyword?: 搜索关键词, page?: 页码, size?: 每页数量 }
   * @returns Promise<ApiResponse<any[]>> 可删除的好友列表
   */
  static async getMyFriendListForDel(params: { keyword?: string; page?: number; size?: number } = {}): Promise<ApiResponse<any[]>> {
    return post('imUserFriend/getMyFriendListForDel', params);
  }
}
