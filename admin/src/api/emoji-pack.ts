import axios from 'axios';

// ========== 表情包相关类型 ==========

export interface EmojiPack {
  id: string;
  name: string;
  icon_url?: string | null;
  // COS 对象键，用于生成临时下载地址
  icon_object_key?: string | null;
  description?: string | null;
  is_active: boolean;
  pack_type: number; // 0=单个, 1=套件
  parent_id?: string | null;
  created_at: string;
  updated_at: string;
}

export interface EmojiItem {
  id: string;
  pack_id: string;
  image_url: string;
  // COS 对象键，用于生成临时下载地址
  image_object_key?: string | null;
  name?: string | null;
  sort_order: number;
  created_at: string;
}

export interface EmojiPackWithItems extends EmojiPack {
  items: EmojiItem[];
}

export interface CreateEmojiPackPayload {
  name: string;
  icon_url?: string;
  icon_object_key?: string;
  description?: string;
  is_active?: boolean;
  pack_type?: number; // 0=单个, 1=套件
  parent_id?: string; // 套件下的表情包需要指定父套件ID
}

export interface UpdateEmojiPackPayload {
  name?: string;
  icon_url?: string;
  icon_object_key?: string;
  description?: string;
  is_active?: boolean;
  pack_type?: number;
  parent_id?: string;
}

export interface CreateEmojiItemPayload {
  pack_id: string;
  image_url: string;
  image_object_key?: string;
  name?: string;
  sort_order?: number;
}

export interface UpdateEmojiItemPayload {
  image_url?: string;
  image_object_key?: string;
  name?: string;
  sort_order?: number;
}

// ========== 表情包管理 API ==========

export function listAllEmojiPacks(keyword?: string) {
  const params = keyword ? { keyword } : {};
  return axios.get<EmojiPack[]>('/api/admin/emoji-packs', { params });
}

export function createEmojiPack(payload: CreateEmojiPackPayload) {
  return axios.post<EmojiPack>('/api/admin/emoji-packs', payload);
}

export function getEmojiPack(packId: string) {
  return axios.get<EmojiPackWithItems>(`/api/admin/emoji-packs/${packId}`);
}

export function updateEmojiPack(
  packId: string,
  payload: UpdateEmojiPackPayload
) {
  return axios.patch<EmojiPack>(`/api/admin/emoji-packs/${packId}`, payload);
}

export function deleteEmojiPack(packId: string) {
  return axios.delete(`/api/admin/emoji-packs/${packId}`);
}

// ========== 表情项管理 API ==========

export function createEmojiItem(payload: CreateEmojiItemPayload) {
  return axios.post<EmojiItem>('/api/admin/emoji-items', payload);
}

export function getEmojiItem(itemId: string) {
  return axios.get<EmojiItem>(`/api/admin/emoji-items/${itemId}`);
}

export function updateEmojiItem(
  itemId: string,
  payload: UpdateEmojiItemPayload
) {
  return axios.patch<EmojiItem>(`/api/admin/emoji-items/${itemId}`, payload);
}

export function deleteEmojiItem(itemId: string) {
  return axios.delete(`/api/admin/emoji-items/${itemId}`);
}

// ========== 套件相关 API ==========

export function getSuitePacks(suiteId: string) {
  return axios.get<EmojiPack[]>(`/api/admin/emoji-packs?parent_id=${suiteId}`);
}
