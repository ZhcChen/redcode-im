// @ts-nocheck
/**
 * SystemApi Rust 迁移版本
 * 所有系统相关 API 的 Rust 实现
 */

import { rustHttp, isRustEnabled, FEATURE_FLAGS } from './rust-http'
import { get } from './http'
import type { ApiResponse } from './http'
import type { LegacyUserInfo } from './system'

// 后端用户状态
type BackendUserStatus = 'active' | 'inactive' | 'banned'

interface BackendUserInfo {
  id: string
  username: string
  email: string
  nickname?: string | null
  avatar_url?: string | null
  avatar_object_key?: string | null
  status: BackendUserStatus
}

interface BackendLoginResponse {
  token: string
  user: BackendUserInfo
}

const mapStatusToActiveFlag = (status: BackendUserStatus): number | null => {
  switch (status) {
    case 'active':
      return 1
    case 'inactive':
      return 0
    case 'banned':
      return -1
    default:
      return null
  }
}

const mapBackendUserToLegacy = (user: BackendUserInfo): LegacyUserInfo => ({
  id: String(user.id),
  username: user.username,
  nickname: user.nickname || user.username,
  avatar: user.avatar_url || '',
  avatarObjectKey: user.avatar_object_key || null,
  avatarLocalPath: null,
  mobile: user.username,
  email: user.email || '',
  isLoggedIn: true,
  realName: user.nickname || user.username,
  chatNumber: user.username,
  address: '',
  createTime: null,
  lastLoginTime: null,
  activeStatus: mapStatusToActiveFlag(user.status),
  delFlag: null,
  level: null,
  userDeviceId: null,
  userSign: null,
  trcSdkAppId: null,
  powerList: null
})

/**
 * SystemApi - Rust 实现
 */
export class RustSystemApi {
  private static useRust = () => isRustEnabled('USE_RUST_BACKEND')

  /**
   * 登录 - 使用 Rust 后端
   */
  static async login(params: {
    username?: string
    mobile?: string
    password: string
    captcha?: string
    userDeviceId?: number
  }): Promise<ApiResponse<{
    token: string
    userInfo: LegacyUserInfo
  }>> {
    if (this.useRust()) {
      try {
        const response = await rustHttp.post<BackendLoginResponse>('/auth/login/sms', {
          username: params.username,
          password: params.password,
          captcha: params.captcha,
          userDeviceId: params.userDeviceId
        })

        if (response.success && response.data) {
          const userInfo = mapBackendUserToLegacy(response.data.user)
          return {
            code: 200,
            message: '登录成功',
            data: {
              token: response.data.token,
              userInfo
            },
            success: true
          }
        } else {
          return {
            code: response.code,
            message: response.message,
            data: null,
            success: false
          }
        }
      } catch (error: any) {
        // 失败时回退到 TypeScript
        return await this.loginWithTs(params)
      }
    } else {
      return await this.loginWithTs(params)
    }
  }

  /**
   * TypeScript 版本登录（回退方案）
   */
  private static async loginWithTs(params: any): Promise<ApiResponse<any>> {
    const { SystemApi } = await import('./system')
    return await SystemApi.login(params)
  }

  /**
   * 短信登录 - 使用 Rust 后端
   */
  static async smsLogin(params: {
    phone: string
    code: string
  }): Promise<ApiResponse<{
    token: string
    userInfo: LegacyUserInfo
  }>> {
    if (this.useRust()) {
      try {
        const response = await rustHttp.post<BackendLoginResponse>('/auth/login/sms', {
          phone: params.phone,
          code: params.code
        })

        if (response.success && response.data) {
          const userInfo = mapBackendUserToLegacy(response.data.user)
          return {
            code: 200,
            message: '登录成功',
            data: {
              token: response.data.token,
              userInfo
            },
            success: true
          }
        } else {
          return {
            code: response.code,
            message: response.message,
            data: null,
            success: false
          }
        }
      } catch (error: any) {
        const { SystemApi } = await import('./system')
        return await SystemApi.smsLogin(params)
      }
    } else {
      const { SystemApi } = await import('./system')
      return await SystemApi.smsLogin(params)
    }
  }

  /**
   * 登出 - 使用 Rust 后端
   */
  static async logout(): Promise<ApiResponse<any>> {
    if (this.useRust()) {
      try {
        const response = await rustHttp.post('/auth/logout')

        // 清除 token
        await rustHttp.clearToken()

        return {
          code: 200,
          message: '登出成功',
          data: null,
          success: true
        }
      } catch (error: any) {
        const { SystemApi } = await import('./system')
        return await SystemApi.logout()
      }
    } else {
      const { SystemApi } = await import('./system')
      return await SystemApi.logout()
    }
  }

  /**
   * 发送验证码 - 使用 Rust 后端
   */
  static async sendVerificationCode(params: {
    mobile: string
    type: 'register' | 'login' | 'reset'
  }): Promise<ApiResponse<any>> {
    if (this.useRust()) {
      try {
        const response = await rustHttp.post('/auth/sms/send', {
          phone: params.mobile,
          type: params.type
        })

        return {
          code: 200,
          message: '验证码发送成功',
          data: response.data,
          success: true
        }
      } catch (error: any) {
        const { SystemApi } = await import('./system')
        return await SystemApi.sendVerificationCode(params)
      }
    } else {
      const { SystemApi } = await import('./system')
      return await SystemApi.sendVerificationCode(params)
    }
  }

  /**
   * 验证验证码 - 使用 Rust 后端
   */
  static async verifyCode(params: {
    mobile: string
    code: string
  }): Promise<ApiResponse<any>> {
    if (this.useRust()) {
      try {
        const response = await rustHttp.post('/auth/sms/verify', {
          phone: params.mobile,
          code: params.code
        })

        return {
          code: 200,
          message: '验证成功',
          data: response.data,
          success: true
        }
      } catch (error: any) {
        const { SystemApi } = await import('./system')
        return await SystemApi.verifyCode(params)
      }
    } else {
      const { SystemApi } = await import('./system')
      return await SystemApi.verifyCode(params)
    }
  }

  /**
   * 注册 - 使用 Rust 后端
   */
  static async register(params: {
    username: string
    password: string
    mobile: string
    code: string
  }): Promise<ApiResponse<any>> {
    if (this.useRust()) {
      try {
        const response = await rustHttp.post('/auth/register', params)

        return {
          code: 200,
          message: '注册成功',
          data: response.data,
          success: true
        }
      } catch (error: any) {
        const { SystemApi } = await import('./system')
        return await SystemApi.register(params)
      }
    } else {
      const { SystemApi } = await import('./system')
      return await SystemApi.register(params)
    }
  }

  /**
   * 健康检查 - 使用 Rust 后端
   */
  static async healthCheck(): Promise<boolean> {
    if (this.useRust()) {
      return await rustHttp.healthCheck()
    }
    try {
      const response = await get('/health')
      return response.success
    } catch (error) {
      return false
    }
  }

  /**
   * 获取系统信息 - 使用 Rust 后端
   */
  static async getSystemInfo(): Promise<ApiResponse<any>> {
    if (this.useRust()) {
      try {
        const response = await rustHttp.get('/system/info')

        return {
          code: 200,
          message: '获取成功',
          data: response.data,
          success: true
        }
      } catch (error: any) {
        const { SystemApi } = await import('./system')
        return await SystemApi.getSystemInfo()
      }
    } else {
      const { SystemApi } = await import('./system')
      return await SystemApi.getSystemInfo()
    }
  }
}

// 导出
export default RustSystemApi
