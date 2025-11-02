/**
 * 朋友圈相关 API 接口
 * 包含朋友圈发布、点赞、评论等功能
 */

import { post } from './http';
import type { ApiResponse } from './http';

/**
 * 朋友圈信息接口
 */
export interface FriendCircleInfo {
  id: string;
  userId: string;
  username: string;
  nickname: string;
  avatar: string;
  content: string;
  images: string[]; // 图片URL列表
  location?: string; // 位置信息
  isPublic: boolean; // 是否公开
  likeCount: number; // 点赞数
  commentCount: number; // 评论数
  isLiked: boolean; // 当前用户是否已点赞
  status: number; // 状态：1-正常, 2-已删除
  createTime: string;
  updateTime: string;
}

/**
 * 朋友圈评论信息接口
 */
export interface FriendCircleComment {
  id: string;
  circleId: string;
  userId: string;
  username: string;
  nickname: string;
  avatar: string;
  content: string;
  replyToUserId?: string; // 回复的用户ID
  replyToUserName?: string; // 回复的用户名
  replyToContent?: string; // 回复的内容
  likeCount: number;
  isLiked: boolean;
  createTime: string;
}

/**
 * 发布朋友圈参数
 */
export interface ReleaseFriendCircleParams {
  content: string;
  images?: string[]; // 图片URL列表
  location?: string; // 位置信息
  isPublic?: boolean; // 是否公开，默认true
  visibleUserIds?: string[]; // 可见用户ID列表（私密时使用）
}

/**
 * 获取朋友圈列表参数
 */
export interface GetCircleDataListParams {
  page?: number;
  size?: number;
  userId?: string; // 指定用户ID，获取该用户的朋友圈
  lastCircleId?: string; // 最后一条朋友圈ID，用于分页
  keyword?: string; // 搜索关键词
}

/**
 * 朋友圈 API 接口类
 */
export class FriendCircleApi {
  /**
   * 发布朋友圈
   * @param params 发布参数 { content: 内容, images?: 图片列表, location?: 位置, isPublic?: 是否公开, visibleUserIds?: 可见用户列表 }
   * @returns Promise<ApiResponse<any>> 发布结果
   */
  static async releaseFriendCircle(params: ReleaseFriendCircleParams): Promise<ApiResponse<any>> {
    return post('imFriendCircle/releaseNewCircle', params);
  }

  /**
   * 获取朋友圈数据列表
   * @param params 查询参数 { page?: 页码, size?: 每页数量, userId?: 用户ID, lastCircleId?: 最后朋友圈ID, keyword?: 搜索关键词 }
   * @returns Promise<ApiResponse<{ list: FriendCircleInfo[], hasMore: boolean, lastCircleId: string }>> 朋友圈列表
   */
  static async getCircleDataList(params: GetCircleDataListParams = {}): Promise<ApiResponse<{
    list: FriendCircleInfo[];
    hasMore: boolean;
    lastCircleId: string;
    total: number;
  }>> {
    return post('imFriendCircle/getCircleDataList', params);
  }

  /**
   * 获取朋友圈数据列表（方式2）
   * @param params 查询参数
   * @returns Promise<ApiResponse<FriendCircleInfo[]>> 朋友圈列表
   */
  static async getCircleDataList2(params: GetCircleDataListParams = {}): Promise<ApiResponse<FriendCircleInfo[]>> {
    return post<FriendCircleInfo[]>('imFriendCircle/getCircleDataList2', params);
  }

  /**
   * 删除朋友圈
   * @param params 删除参数 { circleId: 朋友圈ID }
   * @returns Promise<ApiResponse<any>> 删除结果
   */
  static async deleteCircle(params: { circleId: string }): Promise<ApiResponse<any>> {
    return post('imFriendCircle/deleteCircle', params);
  }

  /**
   * 点赞/取消点赞朋友圈
   * @param params 点赞参数 { circleId: 朋友圈ID, isLike: 是否点赞 }
   * @returns Promise<ApiResponse<any>> 点赞结果
   */
  static async clickThumb(params: { circleId: string; isLike: boolean }): Promise<ApiResponse<any>> {
    return post('imFriendCircle/clickThumb', params);
  }

  /**
   * 检查朋友圈更新
   * @param params 检查参数 { lastUpdateTime?: 最后更新时间 }
   * @returns Promise<ApiResponse<any>> 更新信息
   */
  static async checkFriendCircleUpdate(params: { lastUpdateTime?: string } = {}): Promise<ApiResponse<any>> {
    return post('imFriendCircle/checkFriendCircleUpdate', params);
  }

  /**
   * 获取朋友圈详情
   * @param params 查询参数 { circleId: 朋友圈ID }
   * @returns Promise<ApiResponse<FriendCircleInfo>> 朋友圈详情
   */
  static async getCircleDetail(params: { circleId: string }): Promise<ApiResponse<FriendCircleInfo>> {
    return post<FriendCircleInfo>('imFriendCircle/getCircleDetail', params);
  }

  /**
   * 获取朋友圈点赞列表
   * @param params 查询参数 { circleId: 朋友圈ID, page?: 页码, size?: 每页数量 }
   * @returns Promise<ApiResponse<any[]>> 点赞用户列表
   */
  static async getCircleLikeList(params: { circleId: string; page?: number; size?: number }): Promise<ApiResponse<any[]>> {
    return post('imFriendCircle/getCircleLikeList', params);
  }

  /**
   * 举报朋友圈
   * @param params 举报参数 { circleId: 朋友圈ID, reason: 举报原因, description?: 详细描述 }
   * @returns Promise<ApiResponse<any>> 举报结果
   */
  static async reportCircle(params: { circleId: string; reason: string; description?: string }): Promise<ApiResponse<any>> {
    return post('imFriendCircle/reportCircle', params);
  }

  /**
   * 屏蔽用户朋友圈
   * @param params 屏蔽参数 { userId: 用户ID, isBlocked: 是否屏蔽 }
   * @returns Promise<ApiResponse<any>> 屏蔽结果
   */
  static async blockUserCircle(params: { userId: string; isBlocked: boolean }): Promise<ApiResponse<any>> {
    return post('imFriendCircle/blockUserCircle', params);
  }
}

/**
 * 朋友圈评论 API 接口类
 */
export class FriendCircleCommentApi {
  /**
   * 处理评论（添加/回复评论）
   * @param params 评论参数 { circleId: 朋友圈ID, content: 评论内容, replyToUserId?: 回复用户ID, replyToCommentId?: 回复评论ID }
   * @returns Promise<ApiResponse<any>> 评论结果
   */
  static async handleComment(params: {
    circleId: string;
    content: string;
    replyToUserId?: string;
    replyToCommentId?: string;
  }): Promise<ApiResponse<any>> {
    return post('imFriendCircleComment/handleComment', params);
  }

  /**
   * 获取朋友圈评论列表
   * @param params 查询参数 { circleId: 朋友圈ID, page?: 页码, size?: 每页数量 }
   * @returns Promise<ApiResponse<{ list: FriendCircleComment[], total: number }>> 评论列表
   */
  static async getCommentList(params: { circleId: string; page?: number; size?: number }): Promise<ApiResponse<{
    list: FriendCircleComment[];
    total: number;
    page: number;
    size: number;
  }>> {
    return post('imFriendCircleComment/getCommentList', params);
  }

  /**
   * 删除评论
   * @param params 删除参数 { commentId: 评论ID }
   * @returns Promise<ApiResponse<any>> 删除结果
   */
  static async deleteComment(params: { commentId: string }): Promise<ApiResponse<any>> {
    return post('imFriendCircleComment/deleteComment', params);
  }

  /**
   * 点赞/取消点赞评论
   * @param params 点赞参数 { commentId: 评论ID, isLike: 是否点赞 }
   * @returns Promise<ApiResponse<any>> 点赞结果
   */
  static async likeComment(params: { commentId: string; isLike: boolean }): Promise<ApiResponse<any>> {
    return post('imFriendCircleComment/likeComment', params);
  }

  /**
   * 举报评论
   * @param params 举报参数 { commentId: 评论ID, reason: 举报原因, description?: 详细描述 }
   * @returns Promise<ApiResponse<any>> 举报结果
   */
  static async reportComment(params: { commentId: string; reason: string; description?: string }): Promise<ApiResponse<any>> {
    return post('imFriendCircleComment/reportComment', params);
  }
}

/**
 * 朋友圈可见性枚举
 */
export enum CircleVisibility {
  PUBLIC = 1, // 公开
  FRIENDS_ONLY = 2, // 仅好友可见
  PRIVATE = 3, // 私密（指定用户可见）
  SELF_ONLY = 4 // 仅自己可见
}

/**
 * 获取可见性名称
 * @param visibility 可见性类型
 * @returns 可见性名称
 */
export function getVisibilityName(visibility: number): string {
  const visibilityNames: Record<number, string> = {
    [CircleVisibility.PUBLIC]: '公开',
    [CircleVisibility.FRIENDS_ONLY]: '仅好友可见',
    [CircleVisibility.PRIVATE]: '部分可见',
    [CircleVisibility.SELF_ONLY]: '仅自己可见'
  };
  return visibilityNames[visibility] || '未知';
}
