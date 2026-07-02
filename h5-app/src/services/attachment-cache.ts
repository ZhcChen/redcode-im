import { requestJson, withQuery } from '@/api/http';
import { BlobCache, type CachedBlobEntry } from '@/storage/blob-cache';

import { requireToken } from './session';

const attachmentBlobCache = new BlobCache({ namespace: 'redcode-h5-attachment-cache' });

export const attachmentCacheService = {
  async loadAttachment(params: { roomId: string; objectKey: string }): Promise<CachedBlobEntry | null> {
    if (!params.roomId || !params.objectKey) return null;
    const cacheKey = `message:${params.objectKey}`;
    const cached = await attachmentBlobCache.resolve(cacheKey, params.objectKey);
    if (cached) return cached;

    const downloadUrl = await fetchAttachmentDownloadUrl(params.roomId, params.objectKey);
    if (typeof downloadUrl !== 'string' || !downloadUrl) return null;

    return attachmentBlobCache.fetchAndCache({
      cacheKey,
      objectKey: params.objectKey,
      url: downloadUrl,
    });
  },

  revoke(entry: Pick<CachedBlobEntry, 'objectUrl'> | null | undefined) {
    attachmentBlobCache.revoke(entry);
  },

  clearAll() {
    return attachmentBlobCache.clearAll();
  },
};

const fetchAttachmentDownloadUrl = async (roomId: string, objectKey: string) => {
  try {
    const response = await requestJson<Record<string, unknown>>(
      withQuery(`/rooms/${roomId}/messages/attachments/download`, {
        key: objectKey,
        expires_in_seconds: 600,
      }),
      {},
      requireToken(),
    );
    if (response.success === false) return null;
    const downloadUrl = response.download_url;
    return typeof downloadUrl === 'string' && downloadUrl ? downloadUrl : null;
  } catch {
    return null;
  }
};
