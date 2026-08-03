export interface StickerItem {
  id: string;
  packId: string;
  imageUrl: string | null;
  imageObjectKey: string | null;
  name: string | null;
}

export interface StickerPack {
  id: string;
  name: string;
  iconUrl: string | null;
  iconObjectKey: string | null;
  description: string | null;
  packType: 'single' | 'suite';
  items: StickerItem[];
}
