import { requestJson, withQuery } from '@/api/http';
import {
  attachmentAad,
  decryptAttachment,
  type E2eeAttachmentPart,
} from '@/e2ee/attachment-crypto';
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

  /**
   * E2EE 附件：只下载密文并在受控内存中解密为 objectURL，不写入明文缓存。
   */
  async loadEncryptedAttachment(params: {
    roomId: string;
    part: E2eeAttachmentPart;
  }): Promise<CachedBlobEntry | null> {
    const { roomId, part } = params;
    if (!roomId || !part.objectKey) return null;
    const downloadUrl = await fetchAttachmentDownloadUrl(roomId, part.objectKey);
    if (!downloadUrl) return null;
    try {
      const response = await fetch(downloadUrl);
      if (!response.ok) return null;
      const ciphertext = new Uint8Array(await response.arrayBuffer());
      const aad = attachmentAad({
        roomId,
        partKey: part.partKey,
        partPosition: part.partPosition,
        objectKey: part.objectKey,
      });
      const plaintext = await decryptAttachment(ciphertext, aad, part.nonce, part.dek);
      const buffer = new ArrayBuffer(plaintext.byteLength);
      new Uint8Array(buffer).set(plaintext);
      const blob = new Blob([buffer], { type: part.mimeType || 'application/octet-stream' });
      return {
        cacheKey: `message:${part.objectKey}`,
        objectKey: part.objectKey,
        objectUrl: URL.createObjectURL(blob),
        mimeType: blob.type,
        size: part.size,
        cachedAt: Date.now(),
      };
    } catch {
      return null;
    }
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
