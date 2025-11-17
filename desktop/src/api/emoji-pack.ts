import { httpClient } from './http';

export interface EmojiPack {
  id: string;
  name: string;
  icon_url?: string | null;
  description?: string | null;
  is_active: boolean;
  pack_type: number; // 0=单个, 1=套件
  parent_id?: string | null;
  created_at: string;
  updated_at: string;
  items?: EmojiItem[];
}

export interface EmojiItem {
  id: string;
  pack_id: string;
  image_url: string;
  name?: string | null;
  sort_order: number;
  created_at: string;
}

/**
 * 表情包相关 API
 */
export class EmojiPackApi {
  /**
   * 获取用户的表情包列表（包含表情项）
   */
  static async getUserPacks(): Promise<Array<{ pack: EmojiPack; items: EmojiItem[] }>> {
    const response = await httpClient.get<Array<{ pack: EmojiPack; items: EmojiItem[] }>>('/emoji-packs/my');
    return response.data || [];
  }

  /**
   * 获取所有可用的表情包（用于用户选择添加）
   */
  static async getAvailablePacks(): Promise<EmojiPack[]> {
    const response = await httpClient.get<EmojiPack[]>('/emoji-packs/available');
    return response.data || [];
  }

  /**
   * 获取表情包详情（包含表情项）- 用户 API
   * 注意：用户只能获取自己已添加的表情包详情
   */
  static async getPack(packId: string): Promise<EmojiPack & { items: EmojiItem[] }> {
    // 从用户表情包列表中查找
    const userPacks = await this.getUserPacks()
    const pack = userPacks.find(p => p.id === packId)
    if (!pack) {
      throw new Error('表情包不存在或未添加')
    }
    // 如果已经有 items，直接返回
    if (pack.items) {
      return pack as EmojiPack & { items: EmojiItem[] }
    }
    // 否则返回空 items
    return { ...pack, items: [] }
  }

  /**
   * 添加用户表情包
   */
  static async addUserPack(packId: string): Promise<void> {
    await httpClient.post(`/emoji-packs/${packId}/add`);
  }

  /**
   * 删除用户表情包
   */
  static async removeUserPack(packId: string): Promise<void> {
    await httpClient.delete(`/emoji-packs/${packId}/remove`);
  }

  /**
   * 搜索表情包和套件
   */
  static async searchPacks(keyword: string): Promise<EmojiPack[]> {
    const response = await httpClient.get<EmojiPack[]>(
      `/emoji-packs/search?keyword=${encodeURIComponent(keyword)}`
    );
    return response.data || [];
  }

  /**
   * 添加表情包套件（添加套件下的所有表情包）
   */
  static async addUserSuite(suiteId: string): Promise<{ count: number }> {
    const response = await httpClient.post<{ success: boolean; message: string; count: number }>(
      `/emoji-packs/suites/${suiteId}/add`
    );
    return { count: response.data?.count || 0 };
  }
}

