/**
 * 用户相关 API 接口
 * 包含用户信息管理、好友管理、权限管理等功能
 */

import { post } from './http';
import type { ApiResponse } from './http';

/**
 * 用户信息接口
 */
export interface UserInfo {
  id: number;
  userName: string;
  realName: string;
  chatNumber: string;
  password?: string;
  idCard?: string | null;
  avatar?: string | null;
  chatBgImg?: string | null;
  signature?: string | null;
  sex?: string | null;
  mobile: string;
  address?: string;
  email?: string | null;
  createTime: string;
  updateTime?: string | null;
  lastLoginTime?: string;
  activeStatus: number;
  delFlag: number;
  remark?: string | null;
  level: number;
  addressDetail?: string | null;
  userDeviceId?: string | null;
  isFriend: boolean;
  fromWith?: string | null;
  userSign?: string | null;
  trcSdkAppId?: number | null;
  powerList?: any[] | null;
}


/**
 * 用户 API 接口类
 */
export class UserApi {
  /**
   * 检查用户权限
   * @param params 权限检查参数 { permission: 权限名称 }
   * @returns Promise<ApiResponse<any>> 权限检查结果
   */
  static async checkUserPower(params: { permission: string }): Promise<ApiResponse<any>> {
    return post('imUserPower/checkUserPower', params);
  }

  /**
   * 更新用户权限
   * @param params 权限更新参数 { userId: 用户ID, permissions: 权限列表 }
   * @returns Promise<ApiResponse<any>> 更新结果
   */
  static async updateUserPower(params: { userId: string; permissions: string[] }): Promise<ApiResponse<any>> {
    return post('imUserPower/updateUserPower', params);
  }

  /**
   * 获取用户账户信息
   * @param params 查询参数 { userId?: 用户ID }
   * @returns Promise<ApiResponse<UserInfo>> 用户账户信息
   */
  static async getUserAccountInfo(params: { userId?: string } = {}): Promise<ApiResponse<UserInfo>> {
    return post<UserInfo>('imUser/getUserAccountInfo', params);
  }

  /**
   * 用户余额充值
   * @param params 充值参数 { amount: 充值金额, payMethod: 支付方式 }
   * @returns Promise<ApiResponse<any>> 充值结果
   */
  static async toPayUserBalance(params: { amount: number; payMethod: string }): Promise<ApiResponse<any>> {
    return post('imUser/toPayUserBalance', params);
  }

  /**
   * 更新用户信息
   * @param params 用户信息参数 { nickname?: 昵称, avatar?: 头像, signature?: 签名, gender?: 性别, birthday?: 生日 }
   * @returns Promise<ApiResponse<any>> 更新结果
   */
  static async updateUserInfo(params: Partial<UserInfo>): Promise<ApiResponse<any>> {
    return post('imUser/updateUserInfo', params);
  }

  /**
   * 更新用户信息并保持在线状态
   * @param params 用户信息参数
   * @returns Promise<ApiResponse<any>> 更新结果
   */
  static async updateUserInfoKeepAlive(params: Partial<UserInfo>): Promise<ApiResponse<any>> {
    return post('imUser/updateUserInfoKeepAlive', params);
  }

  /**
   * 搜索用户
   * @param params 搜索参数 { keyWord: 搜索关键词, page?: 页码, size?: 每页数量 }
   * @returns Promise<ApiResponse<UserInfo[]>> 搜索结果
   */
  static async searchUser(params: { keyWord: string; page?: number; size?: number }): Promise<ApiResponse<UserInfo[]>> {
    return post<UserInfo[]>('imUser/searchUser', params);
  }

  /**
   * 同步通讯录
   * @param params 通讯录数据 { contacts: 联系人列表 }
   * @returns Promise<ApiResponse<any>> 同步结果
   */
  static async syncContacts(params: { contacts: any[] }): Promise<ApiResponse<any>> {
    return post('imUser/syncContacts', params);
  }

  /**
   * 获取群成员信息
   * @param params 查询参数 { groupId: 群组ID, userId: 用户ID }
   * @returns Promise<ApiResponse<any>> 群成员信息
   */
  static async getGroupMemberInfo(params: { groupId: string; userId: string }): Promise<ApiResponse<any>> {
    return post('imUser/getGroupMemberInfo', params);
  }

  /**
   * 获取视频通话信息
   * @param params 查询参数 { callId: 通话ID }
   * @returns Promise<ApiResponse<any>> 通话信息
   */
  static async getVideoCallingInfo(params: { callId: string }): Promise<ApiResponse<any>> {
    return post('imUser/getVideoCallingInfo', params);
  }

  /**
   * 扫码加入群聊
   * @param params 扫码参数 { qrCode: 二维码内容 }
   * @returns Promise<ApiResponse<any>> 加入结果
   */
  static async scanQRJoinGroup(params: { qrCode: string }): Promise<ApiResponse<any>> {
    return post('imUser/scanQRJoinGroup', params);
  }

  /**
   * 验证交易密码
   * @param params 密码参数 { tradePwd: 交易密码 }
   * @returns Promise<ApiResponse<any>> 验证结果
   */
  static async validateTradePwd(params: { tradePwd: string }): Promise<ApiResponse<any>> {
    return post('imUser/validateTradePwd', params);
  }

  /**
   * 验证支付交易密码
   * @param params 密码参数 { tradePwd: 交易密码 }
   * @returns Promise<ApiResponse<any>> 验证结果
   */
  static async validatePayTradePwd(params: { tradePwd: string }): Promise<ApiResponse<any>> {
    return post('imUser/validatePayTradePwd', params);
  }

  /**
   * 修改交易密码
   * @param params 密码参数 { oldPwd: 旧密码, newPwd: 新密码 }
   * @returns Promise<ApiResponse<any>> 修改结果
   */
  static async updateTradePwd(params: { oldPwd: string; newPwd: string }): Promise<ApiResponse<any>> {
    return post('imUser/updateTradePwd', params);
  }

  /**
   * 修改登录密码
   * @param params 密码参数 { oldPwd: 旧密码, newPwd: 新密码 }
   * @returns Promise<ApiResponse<any>> 修改结果
   */
  static async updateUserPassword(params: { oldPwd: string; newPwd: string }): Promise<ApiResponse<any>> {
    return post('imUser/updateUserPassword', params);
  }
}
