/**
 * 账户记录相关 API 接口
 * 包含账户交易记录的增删改查功能
 */

import { post } from './http';
import type { ApiResponse } from './http';

/**
 * 账户记录接口
 */
export interface AccountRecord {
  id: string;
  userId: string;
  type: number; // 交易类型：1-收入, 2-支出, 3-转账, 4-红包, 5-充值, 6-提现
  amount: number; // 交易金额
  balance: number; // 交易后余额
  description: string; // 交易描述
  relatedUserId?: string; // 关联用户ID（转账、红包等）
  relatedUserName?: string; // 关联用户名称
  status: number; // 状态：1-成功, 2-失败, 3-处理中
  createTime: string;
  updateTime: string;
}

/**
 * 添加账户记录参数
 */
export interface AddAccountRecordParams {
  type: number;
  amount: number;
  description: string;
  relatedUserId?: string;
  relatedUserName?: string;
}

/**
 * 更新账户记录参数
 */
export interface UpdateAccountRecordParams {
  id: string;
  type?: number;
  amount?: number;
  description?: string;
  status?: number;
}

/**
 * 查询账户记录参数
 */
export interface GetAccountRecordListParams {
  page?: number;
  size?: number;
  type?: number;
  startDate?: string;
  endDate?: string;
  keyword?: string;
}

/**
 * 账户记录 API 接口类
 */
export class AccountApi {
  /**
   * 添加用户账户记录
   * @param params 记录参数 { type: 交易类型, amount: 金额, description: 描述, relatedUserId?: 关联用户ID, relatedUserName?: 关联用户名 }
   * @returns Promise<ApiResponse<any>> 添加结果
   */
  static async addUserAccountRecord(params: AddAccountRecordParams): Promise<ApiResponse<any>> {
    return post('accountRecord/addUserAccountRecord', params);
  }

  /**
   * 获取用户账户记录列表
   * @param params 查询参数 { page?: 页码, size?: 每页数量, type?: 交易类型, startDate?: 开始日期, endDate?: 结束日期, keyword?: 搜索关键词 }
   * @returns Promise<ApiResponse<{ list: AccountRecord[], total: number, page: number, size: number }>> 账户记录列表
   */
  static async getUserAccountRecordList(params: GetAccountRecordListParams = {}): Promise<ApiResponse<{
    list: AccountRecord[];
    total: number;
    page: number;
    size: number;
  }>> {
    return post('accountRecord/getUserAccountRecordList', params);
  }

  /**
   * 更新用户账户记录
   * @param params 更新参数 { id: 记录ID, type?: 交易类型, amount?: 金额, description?: 描述, status?: 状态 }
   * @returns Promise<ApiResponse<any>> 更新结果
   */
  static async updateUserAccountRecord(params: UpdateAccountRecordParams): Promise<ApiResponse<any>> {
    return post('accountRecord/updateUserAccountRecord', params);
  }

  /**
   * 删除用户账户记录
   * @param params 删除参数 { id: 记录ID }
   * @returns Promise<ApiResponse<any>> 删除结果
   */
  static async deleteUserAccountRecord(params: { id: string }): Promise<ApiResponse<any>> {
    return post('accountRecord/deleteUserAccountRecord', params);
  }

  /**
   * 批量删除用户账户记录
   * @param params 删除参数 { ids: 记录ID数组 }
   * @returns Promise<ApiResponse<any>> 删除结果
   */
  static async batchDeleteUserAccountRecord(params: { ids: string[] }): Promise<ApiResponse<any>> {
    return post('accountRecord/batchDeleteUserAccountRecord', params);
  }

  /**
   * 获取账户统计信息
   * @param params 查询参数 { startDate?: 开始日期, endDate?: 结束日期 }
   * @returns Promise<ApiResponse<any>> 统计信息
   */
  static async getAccountStatistics(params: { startDate?: string; endDate?: string } = {}): Promise<ApiResponse<{
    totalIncome: number; // 总收入
    totalExpense: number; // 总支出
    currentBalance: number; // 当前余额
    recordCount: number; // 记录总数
    typeStatistics: Array<{ type: number; count: number; amount: number }>; // 按类型统计
  }>> {
    return post('accountRecord/getAccountStatistics', params);
  }

  /**
   * 导出账户记录
   * @param params 导出参数 { startDate?: 开始日期, endDate?: 结束日期, type?: 交易类型, format?: 导出格式 }
   * @returns Promise<ApiResponse<any>> 导出结果
   */
  static async exportAccountRecords(params: {
    startDate?: string;
    endDate?: string;
    type?: number;
    format?: 'excel' | 'csv';
  } = {}): Promise<ApiResponse<any>> {
    return post('accountRecord/exportAccountRecords', params);
  }
}

/**
 * 交易类型枚举
 */
export enum TransactionType {
  INCOME = 1, // 收入
  EXPENSE = 2, // 支出
  TRANSFER = 3, // 转账
  RED_PACKET = 4, // 红包
  RECHARGE = 5, // 充值
  WITHDRAW = 6 // 提现
}

/**
 * 交易状态枚举
 */
export enum TransactionStatus {
  SUCCESS = 1, // 成功
  FAILED = 2, // 失败
  PROCESSING = 3 // 处理中
}

/**
 * 获取交易类型名称
 * @param type 交易类型
 * @returns 类型名称
 */
export function getTransactionTypeName(type: number): string {
  const typeNames: Record<number, string> = {
    [TransactionType.INCOME]: '收入',
    [TransactionType.EXPENSE]: '支出',
    [TransactionType.TRANSFER]: '转账',
    [TransactionType.RED_PACKET]: '红包',
    [TransactionType.RECHARGE]: '充值',
    [TransactionType.WITHDRAW]: '提现'
  };
  return typeNames[type] || '未知';
}

/**
 * 获取交易状态名称
 * @param status 交易状态
 * @returns 状态名称
 */
export function getTransactionStatusName(status: number): string {
  const statusNames: Record<number, string> = {
    [TransactionStatus.SUCCESS]: '成功',
    [TransactionStatus.FAILED]: '失败',
    [TransactionStatus.PROCESSING]: '处理中'
  };
  return statusNames[status] || '未知';
}
