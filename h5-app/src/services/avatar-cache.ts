import { requestJson, withQuery } from '@/api/http';
import { BlobCache, type CachedBlobEntry } from '@/storage/blob-cache';

import { requireToken } from './session';

type AvatarKind = 'user' | 'room';

const avatarBlobCache = new BlobCache({ namespace: 'redcode-h5-avatar-cache' });

export const avatarCacheService = {
  async loadUserAvatar(params: { userId: string; objectKey?: string | null }): Promise<CachedBlobEntry | null> {
    return loadAvatar({
      kind: 'user',
      entityId: params.userId,
      objectKey: params.objectKey,
      downloadPath: `/users/${params.userId}/avatar/url`,
    });
  },

  async loadRoomAvatar(params: { roomId: string; objectKey?: string | null }): Promise<CachedBlobEntry | null> {
    return loadAvatar({
      kind: 'room',
      entityId: params.roomId,
      objectKey: params.objectKey,
      downloadPath: `/rooms/${params.roomId}/avatar/url`,
    });
  },

  revoke(entry: Pick<CachedBlobEntry, 'objectUrl'> | null | undefined) {
    avatarBlobCache.revoke(entry);
  },

  clearAll() {
    return avatarBlobCache.clearAll();
  },
};

const loadAvatar = async (params: {
  kind: AvatarKind;
  entityId: string;
  objectKey?: string | null;
  downloadPath: string;
}) => {
  if (!params.entityId || !params.objectKey) return null;
  const cacheKey = `${params.kind}:${params.entityId}`;
  const cached = await avatarBlobCache.resolve(cacheKey, params.objectKey);
  if (cached) return cached;

  const downloadUrl = await fetchDownloadUrl(params.downloadPath);
  if (!downloadUrl) return null;

  return avatarBlobCache.fetchAndCache({
    cacheKey,
    objectKey: params.objectKey,
    url: downloadUrl,
  });
};

const fetchDownloadUrl = async (path: string) => {
  try {
    const response = await requestJson<Record<string, unknown>>(
      withQuery(path, { expires_in_seconds: 3600 }),
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
