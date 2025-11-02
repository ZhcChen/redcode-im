/**
 * AI 聊天相关 API 接口
 * 包含 ChatGPT 对话、图像生成等功能
 */

import { post, get } from './http';
import type { ApiResponse } from './http';

/**
 * ChatGPT 对话消息接口
 */
export interface ChatGptMessage {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: number;
  tokens?: number; // 消息使用的token数量
}

/**
 * ChatGPT 对话会话接口
 */
export interface ChatGptSession {
  id: string;
  title: string;
  messages: ChatGptMessage[];
  totalTokens: number;
  createTime: string;
  updateTime: string;
}

/**
 * ChatGPT 对话参数
 */
export interface ChatGptParams {
  message: string;
  sessionId?: string; // 会话ID，用于保持上下文
  model?: string; // 模型名称，如 gpt-3.5-turbo, gpt-4
  temperature?: number; // 温度参数，控制回复的随机性
  maxTokens?: number; // 最大token数量
  systemPrompt?: string; // 系统提示词
}

/**
 * 问题模板接口
 */
export interface QuestionTemplate {
  id: string;
  title: string;
  content: string;
  category: string;
  tags: string[];
  useCount: number;
  isRecommended: boolean;
  createTime: string;
}

/**
 * 图像生成参数
 */
export interface ChatToImageParams {
  prompt: string; // 图像描述提示词
  size?: '256x256' | '512x512' | '1024x1024'; // 图像尺寸
  quality?: 'standard' | 'hd'; // 图像质量
  style?: 'vivid' | 'natural'; // 图像风格
  n?: number; // 生成图像数量
}

/**
 * 图像生成结果接口
 */
export interface ImageGenerationResult {
  id: string;
  url: string;
  prompt: string;
  size: string;
  quality: string;
  style: string;
  createTime: string;
}

/**
 * AI 聊天 API 接口类
 */
export class ChatGptApi {
  /**
   * ChatGPT 对话
   * @param params 对话参数 { message: 消息内容, sessionId?: 会话ID, model?: 模型名称, temperature?: 温度, maxTokens?: 最大token, systemPrompt?: 系统提示 }
   * @returns Promise<ApiResponse<{ reply: string, sessionId: string, tokens: number }>> 对话结果
   */
  static async chatGpt(params: ChatGptParams): Promise<ApiResponse<{
    reply: string;
    sessionId: string;
    tokens: number;
    model: string;
  }>> {
    return post('/chatGpt/chat', params);
  }

  /**
   * 清空 ChatGPT 对话记录
   * @param params 清空参数 { sessionId?: 会话ID }
   * @returns Promise<ApiResponse<any>> 清空结果
   */
  static async clearChatGpt(params: { sessionId?: string } = {}): Promise<ApiResponse<any>> {
    return get('/chatGpt/clearChatGpt', params);
  }

  /**
   * 启动 WebSocket 聊天（SSE 流式响应）
   * @param params 启动参数 { sessionId?: 会话ID, model?: 模型名称 }
   * @returns Promise<ApiResponse<{ wsUrl: string, sessionId: string }>> WebSocket 连接信息
   */
  static async startWSChatWithSSE(params: { sessionId?: string; model?: string } = {}): Promise<ApiResponse<{
    wsUrl: string;
    sessionId: string;
  }>> {
    return get('/chatGpt/startWSChatWithSSE', params);
  }

  /**
   * 重新加载问题模板列表
   * @param params 查询参数 { category?: 分类, keyword?: 搜索关键词, page?: 页码, size?: 每页数量 }
   * @returns Promise<ApiResponse<QuestionTemplate[]>> 问题模板列表
   */
  static async reloadExampleList(params: {
    category?: string;
    keyword?: string;
    page?: number;
    size?: number;
  } = {}): Promise<ApiResponse<QuestionTemplate[]>> {
    return post('/chatGpt/quesTemplateList', params);
  }

  /**
   * 文字转图片（AI 图像生成）
   * @param params 生成参数 { prompt: 描述提示词, size?: 图像尺寸, quality?: 图像质量, style?: 图像风格, n?: 生成数量 }
   * @returns Promise<ApiResponse<ImageGenerationResult[]>> 生成的图像列表
   */
  static async chatToImage(params: ChatToImageParams): Promise<ApiResponse<ImageGenerationResult[]>> {
    return post('/chatGpt/chatToImage', params);
  }

  /**
   * 获取 ChatGPT 会话列表
   * @param params 查询参数 { page?: 页码, size?: 每页数量, keyword?: 搜索关键词 }
   * @returns Promise<ApiResponse<ChatGptSession[]>> 会话列表
   */
  static async getChatSessions(params: { page?: number; size?: number; keyword?: string } = {}): Promise<ApiResponse<ChatGptSession[]>> {
    return post('/chatGpt/getChatSessions', params);
  }

  /**
   * 获取 ChatGPT 会话详情
   * @param params 查询参数 { sessionId: 会话ID }
   * @returns Promise<ApiResponse<ChatGptSession>> 会话详情
   */
  static async getChatSessionDetail(params: { sessionId: string }): Promise<ApiResponse<ChatGptSession>> {
    return post('/chatGpt/getChatSessionDetail', params);
  }

  /**
   * 删除 ChatGPT 会话
   * @param params 删除参数 { sessionId: 会话ID }
   * @returns Promise<ApiResponse<any>> 删除结果
   */
  static async deleteChatSession(params: { sessionId: string }): Promise<ApiResponse<any>> {
    return post('/chatGpt/deleteChatSession', params);
  }

  /**
   * 重命名 ChatGPT 会话
   * @param params 重命名参数 { sessionId: 会话ID, title: 新标题 }
   * @returns Promise<ApiResponse<any>> 重命名结果
   */
  static async renameChatSession(params: { sessionId: string; title: string }): Promise<ApiResponse<any>> {
    return post('/chatGpt/renameChatSession', params);
  }

  /**
   * 导出 ChatGPT 会话
   * @param params 导出参数 { sessionId: 会话ID, format?: 导出格式 }
   * @returns Promise<ApiResponse<any>> 导出结果
   */
  static async exportChatSession(params: { sessionId: string; format?: 'txt' | 'json' | 'markdown' }): Promise<ApiResponse<any>> {
    return post('/chatGpt/exportChatSession', params);
  }

  /**
   * 获取 AI 模型列表
   * @param params 查询参数
   * @returns Promise<ApiResponse<any[]>> 模型列表
   */
  static async getAvailableModels(params: Record<string, any> = {}): Promise<ApiResponse<Array<{
    id: string;
    name: string;
    description: string;
    maxTokens: number;
    pricing: {
      input: number;
      output: number;
    };
    capabilities: string[];
  }>>> {
    return post('/chatGpt/getAvailableModels', params);
  }

  /**
   * 获取用户 AI 使用统计
   * @param params 查询参数 { startDate?: 开始日期, endDate?: 结束日期 }
   * @returns Promise<ApiResponse<any>> 使用统计
   */
  static async getUsageStatistics(params: { startDate?: string; endDate?: string } = {}): Promise<ApiResponse<{
    totalTokens: number;
    totalSessions: number;
    totalMessages: number;
    totalImages: number;
    dailyUsage: Array<{
      date: string;
      tokens: number;
      sessions: number;
      messages: number;
      images: number;
    }>;
  }>> {
    return post('/chatGpt/getUsageStatistics', params);
  }
}

/**
 * AI 模型枚举
 */
export enum AIModel {
  GPT_3_5_TURBO = 'gpt-3.5-turbo',
  GPT_4 = 'gpt-4',
  GPT_4_TURBO = 'gpt-4-turbo',
  GPT_4_VISION = 'gpt-4-vision-preview',
  DALL_E_2 = 'dall-e-2',
  DALL_E_3 = 'dall-e-3'
}

/**
 * 图像尺寸枚举
 */
export enum ImageSize {
  SMALL = '256x256',
  MEDIUM = '512x512',
  LARGE = '1024x1024'
}

/**
 * 图像质量枚举
 */
export enum ImageQuality {
  STANDARD = 'standard',
  HD = 'hd'
}

/**
 * 图像风格枚举
 */
export enum ImageStyle {
  VIVID = 'vivid',
  NATURAL = 'natural'
}

/**
 * 获取模型显示名称
 * @param model 模型ID
 * @returns 模型显示名称
 */
export function getModelDisplayName(model: string): string {
  const modelNames: Record<string, string> = {
    [AIModel.GPT_3_5_TURBO]: 'GPT-3.5 Turbo',
    [AIModel.GPT_4]: 'GPT-4',
    [AIModel.GPT_4_TURBO]: 'GPT-4 Turbo',
    [AIModel.GPT_4_VISION]: 'GPT-4 Vision',
    [AIModel.DALL_E_2]: 'DALL-E 2',
    [AIModel.DALL_E_3]: 'DALL-E 3'
  };
  return modelNames[model] || model;
}
