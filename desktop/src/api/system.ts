import { get, post } from './http';
import type { ApiResponse } from './http';

export interface AuthUser {
  id: string;
  username: string;
  email?: string;
  nickname?: string;
  avatar_url?: string;
  status?: string;
}

export interface LoginParams {
  username: string;
  password: string;
}

export interface LoginWithSmsParams {
  phone: string;
  code: string;
}

export interface RegisterParams {
  username: string;
  email: string;
  password: string;
  nickname?: string;
}

export interface LoginResponse {
  token: string;
  user: AuthUser;
}

export interface SmsSendResponse {
  message: string;
}

export class SystemApi {
  static login(params: LoginParams): Promise<ApiResponse<LoginResponse>> {
    return post<LoginResponse>('/auth/login', params);
  }

  static loginWithSms(
    params: LoginWithSmsParams,
  ): Promise<ApiResponse<LoginResponse>> {
    return post<LoginResponse>('/auth/login/sms', params);
  }

  static register(
    params: RegisterParams,
  ): Promise<ApiResponse<AuthUser>> {
    return post<AuthUser>('/auth/register', params);
  }

  static getCurrentUser(): Promise<ApiResponse<AuthUser>> {
    return get<AuthUser>('/auth/me');
  }

  static sendLoginSms(phone: string): Promise<ApiResponse<SmsSendResponse>> {
    return post<SmsSendResponse>('/auth/sms/send', { phone });
  }
}
