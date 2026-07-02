import { requestJson, withQuery } from '@/api/http';
import { BlobCache, type CachedBlobEntry } from '@/storage/blob-cache';

import { requireToken } from './session';

const emojiBlobCache = new BlobCache({ namespace: 'redcode-h5-emoji-cache' });

export const emojiCacheService = {
  async loadEmoji(params: { objectKey?: string | null; imageUrl?: string | null }): Promise<CachedBlobEntry | null> {
    const objectKey = params.objectKey || params.imageUrl;
    if (!objectKey) return null;
    const cacheKey = `emoji:${objectKey}`;
    const cached = await emojiBlobCache.resolve(cacheKey, objectKey);
    if (cached) return cached;

    const downloadUrl = params.objectKey
      ? await fetchEmojiDownloadUrl(params.objectKey)
      : params.imageUrl;
    if (!downloadUrl) return null;

    return emojiBlobCache.fetchAndCache({
      cacheKey,
      objectKey,
      url: downloadUrl,
    });
  },

  revoke(entry: Pick<CachedBlobEntry, 'objectUrl'> | null | undefined) {
    emojiBlobCache.revoke(entry);
  },

  clearAll() {
    return emojiBlobCache.clearAll();
  },
};

const fetchEmojiDownloadUrl = async (objectKey: string) => {
  try {
    const response = await requestJson<Record<string, unknown>>(
      withQuery('/emoji-packs/download-url', {
        object_key: objectKey,
        expires_in_seconds: 3600,
      }),
      {},
      requireToken(),
    );
    if (response.success === false) return null;
    const url = response.download_url;
    return typeof url === 'string' && url ? url : null;
  } catch {
    return null;
  }
};
