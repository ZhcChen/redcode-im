/**
 * 消息相关 API 接口
 * 包含群聊消息管理、消息撤回等功能
 */

import { post } from './http';
import type { ApiResponse } from './http';

/**
 * 消息信息接口
 */
export interface MessageInfo {
  id: string;
  chatGroupId: string; // 聊天群组ID
  userId: number; // 发送者用户ID
  userName: string; // 发送者用户名
  userAvatar: string | null; // 发送者头像
  messageType: number; // 1: 用户消息, 2: 系统消息等
  contentType: number; // 1: 文本, 2: 图片, 3: 语音, 4: 视频, 5: 文件等
  content: {
    text?: string; // 文本内容
    imageUrl?: string; // 图片URL
    audioUrl?: string; // 语音URL
    videoUrl?: string; // 视频URL
    fileUrl?: string; // 文件URL
    fileName?: string; // 文件名
    fileSize?: number; // 文件大小
    duration?: number; // 音视频时长
  };
  createTime: string; // 创建时间
  timestamp: number; // 时间戳
  platFrom: number; // 平台来源：1: web, 2: ios, 3: android等
  meFlag: boolean; // 是否为当前用户发送的消息
  showTimeFlag: boolean; // 是否显示时间标志
  
  // 兼容旧字段（保持向后兼容）
  groupId?: string;
  senderId?: string;
  senderName?: string;
  senderAvatar?: string;
  mediaUrl?: string;
  mediaSize?: number;
  mediaDuration?: number;
  isRevoked?: boolean;
  replyToMessageId?: string;
  replyToContent?: string;
  readCount?: number;
  status?: number; // 1: 发送中, 2: 发送成功, 3: 发送失败
  updateTime?: string;
}

/**
 * 消息列表查询参数
 */
export interface GetMessageListParams {
  groupId: string;
  page?: number;
  size?: number;
  lastMessageId?: string; // 最后一条消息ID，用于分页
  messageType?: number; // 消息类型筛选
  keyword?: string; // 搜索关键词
  startTime?: string; // 开始时间
  endTime?: string; // 结束时间
}

/**
 * 更新消息记录参数
 */
export interface UpdateMessageParams {
  messageId: string;
  content?: string;
  status?: number;
  readCount?: number;
}

/**
 * 撤回消息参数
 */
export interface RevertMessageParams {
  messageId: string;
  groupId: string;
}

/**
 * 消息 API 接口类
 */
export class MessageApi {
  /**
   * 获取群聊消息记录列表
   * @param params 查询参数 { groupId: 群组ID, page?: 页码, size?: 每页数量, lastMessageId?: 最后消息ID, messageType?: 消息类型, keyword?: 搜索关键词, startTime?: 开始时间, endTime?: 结束时间 }
   * @returns Promise<ApiResponse<MessageInfo[]>> 消息列表
   */
  static async getMessageListByChatGroupId(params: GetMessageListParams): Promise<ApiResponse<MessageInfo[]>> {
    return post('imMessageGroup/getMessageListByChatGroupId', params);
  }

  /**
   * 更新服务器消息记录
   * @param params 更新参数 { messageId: 消息ID, content?: 消息内容, status?: 消息状态, readCount?: 已读人数 }
   * @returns Promise<ApiResponse<any>> 更新结果
   */
  static async updateServerMessageRecord(params: UpdateMessageParams): Promise<ApiResponse<any>> {
    return post('imMessageGroup/updateServerMessageRecord', params);
  }

  /**
   * 撤回消息
   * @param params 撤回参数 { messageId: 消息ID, groupId: 群组ID }
   * @returns Promise<ApiResponse<any>> 撤回结果
   */
  static async revertMsg(params: RevertMessageParams): Promise<ApiResponse<any>> {
    return post('imMessageGroup/revertMsg', params);
  }

  /**
   * 发送文本消息
   * @param params 发送参数 { groupId: 群组ID, content: 消息内容, replyToMessageId?: 回复的消息ID }
   * @returns Promise<ApiResponse<any>> 发送结果
   */
  static async sendTextMessage(params: { groupId: string; content: string; replyToMessageId?: string }): Promise<ApiResponse<any>> {
    return post('imMessageGroup/sendTextMessage', params);
  }

  /**
   * 发送图片消息
   * @param params 发送参数 { groupId: 群组ID, imageUrl: 图片URL, imageSize?: 图片大小 }
   * @returns Promise<ApiResponse<any>> 发送结果
   */
  static async sendImageMessage(params: { groupId: string; imageUrl: string; imageSize?: number }): Promise<ApiResponse<any>> {
    return post('imMessageGroup/sendImageMessage', params);
  }

  /**
   * 发送语音消息
   * @param params 发送参数 { groupId: 群组ID, audioUrl: 语音URL, duration: 语音时长（秒） }
   * @returns Promise<ApiResponse<any>> 发送结果
   */
  static async sendAudioMessage(params: { groupId: string; audioUrl: string; duration: number }): Promise<ApiResponse<any>> {
    return post('imMessageGroup/sendAudioMessage', params);
  }

  /**
   * 发送视频消息
   * @param params 发送参数 { groupId: 群组ID, videoUrl: 视频URL, duration: 视频时长（秒）, thumbnailUrl?: 缩略图URL }
   * @returns Promise<ApiResponse<any>> 发送结果
   */
  static async sendVideoMessage(params: { groupId: string; videoUrl: string; duration: number; thumbnailUrl?: string }): Promise<ApiResponse<any>> {
    return post('imMessageGroup/sendVideoMessage', params);
  }

  /**
   * 发送文件消息
   * @param params 发送参数 { groupId: 群组ID, fileUrl: 文件URL, fileName: 文件名, fileSize: 文件大小 }
   * @returns Promise<ApiResponse<any>> 发送结果
   */
  static async sendFileMessage(params: { groupId: string; fileUrl: string; fileName: string; fileSize: number }): Promise<ApiResponse<any>> {
    return post('imMessageGroup/sendFileMessage', params);
  }

  /**
   * 发送位置消息
   * @param params 发送参数 { groupId: 群组ID, latitude: 纬度, longitude: 经度, address: 地址描述 }
   * @returns Promise<ApiResponse<any>> 发送结果
   */
  static async sendLocationMessage(params: { groupId: string; latitude: number; longitude: number; address: string }): Promise<ApiResponse<any>> {
    return post('imMessageGroup/sendLocationMessage', params);
  }

  /**
   * 标记消息为已读
   * @param params 标记参数 { groupId: 群组ID, messageIds: 消息ID列表 }
   * @returns Promise<ApiResponse<any>> 标记结果
   */
  static async markMessagesAsRead(params: { groupId: string; messageIds: string[] }): Promise<ApiResponse<any>> {
    return post('imMessageGroup/markMessagesAsRead', params);
  }

  /**
   * 获取未读消息数量
   * @param params 查询参数 { groupId?: 群组ID }
   * @returns Promise<ApiResponse<{ total: number, groups: Array<{ groupId: string, count: number }> }>> 未读消息统计
   */
  static async getUnreadMessageCount(params: { groupId?: string } = {}): Promise<ApiResponse<{
    total: number;
    groups: Array<{ groupId: string; count: number }>;
  }>> {
    return post('imMessageGroup/getUnreadMessageCount', params);
  }

  /**
   * 搜索消息
   * @param params 搜索参数 { keyword: 搜索关键词, groupId?: 群组ID, messageType?: 消息类型, page?: 页码, size?: 每页数量 }
   * @returns Promise<ApiResponse<MessageInfo[]>> 搜索结果
   */
  static async searchMessages(params: {
    keyword: string;
    groupId?: string;
    messageType?: number;
    page?: number;
    size?: number;
  }): Promise<ApiResponse<MessageInfo[]>> {
    return post<MessageInfo[]>('imMessageGroup/searchMessages', params);
  }

  /**
   * 删除消息
   * @param params 删除参数 { messageIds: 消息ID列表, deleteForAll?: 是否为所有人删除 }
   * @returns Promise<ApiResponse<any>> 删除结果
   */
  static async deleteMessages(params: { messageIds: string[]; deleteForAll?: boolean }): Promise<ApiResponse<any>> {
    return post('imMessageGroup/deleteMessages', params);
  }

  /**
   * 转发消息
   * @param params 转发参数 { messageIds: 消息ID列表, targetGroupIds: 目标群组ID列表 }
   * @returns Promise<ApiResponse<any>> 转发结果
   */
  static async forwardMessages(params: { messageIds: string[]; targetGroupIds: string[] }): Promise<ApiResponse<any>> {
    return post('imMessageGroup/forwardMessages', params);
  }
}

/**
 * 消息类型枚举
 */
export enum MessageType {
  TEXT = 1, // 文本
  IMAGE = 2, // 图片
  AUDIO = 3, // 语音
  VIDEO = 4, // 视频
  FILE = 5, // 文件
  LOCATION = 6, // 位置
  RED_PACKET = 7, // 红包
  TRANSFER = 8, // 转账
  SYSTEM = 9 // 系统消息
}

/**
 * 消息状态枚举
 */
export enum MessageStatus {
  SENDING = 1, // 发送中
  SUCCESS = 2, // 发送成功
  FAILED = 3 // 发送失败
}

/**
 * 获取消息类型名称
 * @param type 消息类型
 * @returns 类型名称
 */
export function getMessageTypeName(type: number): string {
  const typeNames: Record<number, string> = {
    [MessageType.TEXT]: '文本',
    [MessageType.IMAGE]: '图片',
    [MessageType.AUDIO]: '语音',
    [MessageType.VIDEO]: '视频',
    [MessageType.FILE]: '文件',
    [MessageType.LOCATION]: '位置',
    [MessageType.RED_PACKET]: '红包',
    [MessageType.TRANSFER]: '转账',
    [MessageType.SYSTEM]: '系统消息'
  };
  return typeNames[type] || '未知';
}
