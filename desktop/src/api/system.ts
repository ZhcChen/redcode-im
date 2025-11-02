/**
 * 系统相关 API 接口
 * 包含登录、注册、认证等系统基础功能
 */

import { post } from './http';
import type { ApiResponse } from './http';

/**
 * 登录请求参数
 */
export interface LoginParams {
  username?: string;
  mobile?: string;
  password: string;
  captcha?: string;
  byBearToken?: boolean;
  userDeviceId?: number;
  bearUserInfo?: any;
}

/**
 * 登录响应数据
 */
export interface LoginResponse {
  token: string;
  userInfo: {
    id: number;
    userName: string;
    realName: string;
    chatNumber: string;
    mobile: string;
    address: string;
    createTime: string;
    lastLoginTime: string;
    activeStatus: number;
    delFlag: number;
    level: number;
    userDeviceId: string;
    userSign: string;
    trcSdkAppId: number;
    powerList: any[];
  };
}

/**
 * 注册请求参数
 */
export interface RegisterParams {
  username: string;
  password: string;
  mobile: string;
  smsCode: string;
  nickname?: string;
}

/**
 * 应用配置响应数据
 */
export interface AppConfigResponse {
  appName: string;
  version: string;
  updateUrl: string;
  features: string[];
}

/**
 * 版本信息响应数据
 */
export interface VersionResponse {
  version: string;
  versionCode: number;
  updateUrl: string;
  updateContent: string;
  forceUpdate: boolean;
}

/**
 * 系统 API 接口类
 */
export class SystemApi {
  /**
   * 用户登录
   * @param params 登录参数 { username: 用户名, password: 密码, captcha?: 验证码 }
   * @returns Promise<ApiResponse<LoginResponse>> 登录结果，包含 token 和用户信息
   */
  static async login(params: LoginParams): Promise<ApiResponse<LoginResponse>> {
    return post<LoginResponse>('sys/login', params);
  }

  /**
   * 授权登录（第三方登录）
   * @param params 授权参数
   * @returns Promise<ApiResponse<LoginResponse>> 登录结果
   */
  static async authLogin(params: Record<string, any>): Promise<ApiResponse<LoginResponse>> {
    return post<LoginResponse>('sys/authlogin', params);
  }

  /**
   * Token 登录（自动登录）
   * @param params Token 参数 { token: 认证令牌 }
   * @returns Promise<ApiResponse<LoginResponse>> 登录结果
   */
  static async loginByToken(params: { token: string }): Promise<ApiResponse<LoginResponse>> {
    return post<LoginResponse>('sys/startByToken', params);
  }

  /**
   * 腾讯云 Token 登录
   * @param params Token 参数
   * @returns Promise<ApiResponse<any>> 登录结果
   */
  static async txByToken(params: Record<string, any>): Promise<ApiResponse<any>> {
    return post('sys/txByToken', params);
  }

  /**
   * 获取腾讯云 TRC Token
   * @param params 请求参数
   * @returns Promise<ApiResponse<any>> TRC Token 信息
   */
  static async getTrcToken(params: Record<string, any> = {}): Promise<ApiResponse<any>> {
    return post('sys/gettrctoken', params);
  }

  /**
   * 用户注册
   * @param params 注册参数 { username: 用户名, password: 密码, mobile: 手机号, smsCode: 短信验证码, nickname?: 昵称 }
   * @returns Promise<ApiResponse<any>> 注册结果
   */
  static async register(params: RegisterParams): Promise<ApiResponse<any>> {
    return post('sys/register', params);
  }

  /**
   * 用户登出
   * @param params 登出参数
   * @returns Promise<ApiResponse<any>> 登出结果
   */
  static async logout(params: Record<string, any> = {}): Promise<ApiResponse<any>> {
    return post('sys/logout', params);
  }

  /**
   * 注销账户
   * @param params 注销参数
   * @returns Promise<ApiResponse<any>> 注销结果
   */
  static async logOff(params: Record<string, any> = {}): Promise<ApiResponse<any>> {
    return post('sys/LogOff', params);
  }

  /**
   * 检查登录状态
   * @param params 检查参数
   * @returns Promise<ApiResponse<any>> 登录状态信息
   */
  static async checkLoginStatus(params: Record<string, any> = {}): Promise<ApiResponse<any>> {
    return post('sys/checkLoginStatus', params);
  }

  /**
   * 获取应用配置
   * @param params 请求参数
   * @returns Promise<ApiResponse<AppConfigResponse>> 应用配置信息
   */
  static async getAppConfig(params: Record<string, any> = {}): Promise<ApiResponse<AppConfigResponse>> {
    return post<AppConfigResponse>('sys/getAppConfig', params);
  }

  /**
   * 检查手机号是否已注册
   * @param params 手机号参数 { mobile: 手机号 }
   * @returns Promise<ApiResponse<any>> 检查结果
   */
  static async checkMobile(params: { mobile: string }): Promise<ApiResponse<any>> {
    return post('sys/checkMobile', params);
  }

  /**
   * 发送手机短信验证码
   * @param params 短信参数 { mobile: 手机号, type: 短信类型 }
   * @returns Promise<ApiResponse<any>> 发送结果
   */
  static async sendMobileSMS(params: { mobile: string; type: string }): Promise<ApiResponse<any>> {
    return post('sys/senMobileSMS', params);
  }

  /**
   * 发送登录验证码（新后端API）
   * @param params 验证码参数 { phone: 手机号 }
   * @returns Promise<ApiResponse<any>> 发送结果
   */
  static async sendLoginSMS(params: { phone: string }): Promise<ApiResponse<any>> {
    return post('auth/sms/send', params);
  }

  /**
   * 验证码登录（新后端API）
   * @param params 登录参数 { phone: 手机号, code: 验证码 }
   * @returns Promise<ApiResponse<LoginResponse>> 登录结果
   */
  static async loginWithSMS(params: { phone: string; code: string }): Promise<ApiResponse<LoginResponse>> {
    return post<LoginResponse>('auth/login/sms', params);
  }

  /**
   * 获取最新版本信息
   * @param params 版本检查参数
   * @returns Promise<ApiResponse<VersionResponse>> 版本信息
   */
  static async getLatestVersion(params: Record<string, any> = {}): Promise<ApiResponse<VersionResponse>> {
    return post<VersionResponse>('sys/getLatestVersion', params);
  }
}
