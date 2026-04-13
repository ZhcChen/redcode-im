import { httpClient } from './http';

export interface EmojiPack {
  id: string;
  name: string;
  icon_url?: string | null;
  icon_object_key?: string | null;  // 对象键，用于获取临时下载地址
  description?: string | null;
  is_active: boolean;
  pack_type: number; // 0=单个, 1=贴纸包
  parent_id?: string | null;
  created_at: string;
  updated_at: string;
  items?: EmojiItem[];
}

export interface EmojiItem {
  id: string;
  pack_id: string;
  image_url: string;
  image_object_key?: string | null;  // 对象键，用于获取临时下载地址
  name?: string | null;
  sort_order: number;
  created_at: string;
}

/**
 * 贴纸相关 API
 */
export class EmojiPackApi {
  /**
   * 获取用户的贴纸列表（包含表情项）
   */
  static async getUserPacks(): Promise<Array<{ pack: EmojiPack; items: EmojiItem[] }>> {
    const response = await httpClient.get<Array<{ pack: EmojiPack; items: EmojiItem[] }>>('/emoji-packs/my');
    return response.data || [];
  }

  /**
   * 获取所有可用的贴纸（用于用户选择添加）
   */
  static async getAvailablePacks(): Promise<EmojiPack[]> {
    const response = await httpClient.get<EmojiPack[]>('/emoji-packs/available');
    return response.data || [];
  }

  /**
   * 获取贴纸详情（包含表情项）- 用户 API
   * 注意：用户只能获取自己已添加的贴纸详情
   */
  static async getPack(packId: string): Promise<EmojiPack & { items: EmojiItem[] }> {
    // 从用户贴纸列表中查找
    const userPacks = await this.getUserPacks()
    const packData = userPacks.find(p => p.pack.id === packId)
    if (!packData) {
      throw new Error('贴纸不存在或未添加')
    }
    // 返回贴纸和表情项
    return {
      ...packData.pack,
      items: packData.items || []
    }
  }

  /**
   * 添加用户贴纸
   */
  static async addUserPack(packId: string): Promise<void> {
    await httpClient.post(`/emoji-packs/${packId}/add`);
  }

  /**
   * 删除用户贴纸
   */
  static async removeUserPack(packId: string): Promise<void> {
    await httpClient.delete(`/emoji-packs/${packId}/remove`);
  }

  /**
   * 搜索贴纸和贴纸包
   */
  static async searchPacks(keyword: string): Promise<EmojiPack[]> {
    const response = await httpClient.get<EmojiPack[]>(
      `/emoji-packs/search?keyword=${encodeURIComponent(keyword)}`
    );
    return response.data || [];
  }

  /**
   * 添加贴纸包（添加贴纸包下的所有贴纸）
   */
  static async addUserSuite(suiteId: string): Promise<{ count: number }> {
    const response = await httpClient.post<{ success: boolean; message: string; count: number }>(
      `/emoji-packs/suites/${suiteId}/add`
    );
    return { count: response.data?.count || 0 };
  }

  /**
   * 获取贴纸包下的贴纸列表（包含表情项）
   * 只返回用户已添加的贴纸
   */
  static async getSuitePacks(suiteId: string): Promise<Array<{ pack: EmojiPack; items: EmojiItem[] }>> {
    const response = await httpClient.get<Array<{ pack: EmojiPack; items: EmojiItem[] }>>(
      `/emoji-packs/suites/${suiteId}/packs`
    );
    return response.data || [];
  }

  /**
   * 获取表情图片临时下载地址
   * @param objectKey 对象键
   * @param expiresInSeconds 有效期（秒），默认 3600
   * @returns 临时下载 URL
   */
  static async getEmojiDownloadUrl(objectKey: string, expiresInSeconds = 3600): Promise<string | null> {
    try {
      const response = await httpClient.get<{ success?: boolean; download_url?: string }>(
        '/emoji-packs/download-url',
        {
          object_key: objectKey,
          expires_in_seconds: expiresInSeconds
        }
      );

      if (response.success && response.data?.download_url) {
        return response.data.download_url;
      }

      console.warn('获取表情下载地址失败:', response.message);
      return null;
    } catch (error) {
      console.error('获取表情下载地址异常:', error);
      return null;
    }
  }
}
