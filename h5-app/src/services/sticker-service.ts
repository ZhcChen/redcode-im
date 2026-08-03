import { requestJson, withQuery } from '@/api/http';
import type { StickerItem, StickerPack } from '@/types/sticker';

import { requireToken } from './session';

export const stickerService = {
  async listMine(): Promise<StickerPack[]> {
    const rows = await requestJson<Record<string, unknown>[]>('/emoji-packs/my', {}, requireToken());
    return rows.map(mapPackWithItems);
  },

  async listAvailable(keyword = ''): Promise<StickerPack[]> {
    const path = keyword.trim()
      ? withQuery('/emoji-packs/search', { keyword: keyword.trim() })
      : '/emoji-packs/available';
    const rows = await requestJson<Record<string, unknown>[]>(path, {}, requireToken());
    return rows.map((row) => mapPack(row));
  },

  async findAvailable(packId: string): Promise<StickerPack | null> {
    return (await this.listAvailable()).find((pack) => pack.id === packId) ?? null;
  },

  async listSuiteItems(suiteId: string): Promise<StickerPack[]> {
    const rows = await requestJson<Record<string, unknown>[]>(`/emoji-packs/suites/${suiteId}/packs`, {}, requireToken());
    return rows.map(mapPackWithItems);
  },

  async add(pack: StickerPack): Promise<number> {
    const response = await requestJson<Record<string, unknown>>(
      pack.packType === 'suite' ? `/emoji-packs/suites/${pack.id}/add` : `/emoji-packs/${pack.id}/add`,
      { method: 'POST' },
      requireToken(),
    );
    return Number(response.count ?? 1);
  },

  async remove(packId: string): Promise<void> {
    await requestJson(`/emoji-packs/${packId}/remove`, { method: 'DELETE' }, requireToken());
  },
};

const mapPackWithItems = (row: Record<string, unknown>): StickerPack => {
  const pack = row.pack && typeof row.pack === 'object' ? row.pack as Record<string, unknown> : row;
  const items = Array.isArray(row.items) ? row.items : [];
  return mapPack(pack, items.map((item) => mapItem(item as Record<string, unknown>)));
};

const mapPack = (row: Record<string, unknown>, items: StickerItem[] = []): StickerPack => ({
  id: String(row.id ?? ''),
  name: String(row.name ?? '贴纸'),
  iconUrl: row.icon_url == null ? null : String(row.icon_url),
  iconObjectKey: row.icon_object_key == null ? null : String(row.icon_object_key),
  description: row.description == null ? null : String(row.description),
  packType: Number(row.pack_type ?? 0) === 1 ? 'suite' : 'single',
  items,
});

const mapItem = (row: Record<string, unknown>): StickerItem => ({
  id: String(row.id ?? ''),
  packId: String(row.pack_id ?? ''),
  imageUrl: row.image_url == null ? null : String(row.image_url),
  imageObjectKey: row.image_object_key == null ? null : String(row.image_object_key),
  name: row.name == null ? null : String(row.name),
});
