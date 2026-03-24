import type { ChatMessagePart, ChatMessagePartInput } from "@/api/chat";
import { ChatApi } from "@/api/chat";

export interface AttachmentPreviewRequest {
  roomId: string;
  key: string;
  expiresInSeconds?: number;
}

export interface AttachmentPreviewUrlStoreDependencies {
  getAttachmentDownloadUrl?: typeof ChatApi.getAttachmentDownloadUrl;
}

const INLINE_PREVIEW_PART_TYPES = new Set<ChatMessagePart["partType"] | Exclude<ChatMessagePartInput["type"], "text">>([
  "image",
  "video",
  "audio"
]);

const buildCacheKey = (request: AttachmentPreviewRequest) => `${request.roomId}:${request.key}`;

export const shouldInlinePreviewAttachment = (partType: ChatMessagePart["partType"]) =>
  INLINE_PREVIEW_PART_TYPES.has(partType);

export const createAttachmentPreviewUrlStore = (dependencies: AttachmentPreviewUrlStoreDependencies = {}) => {
  const getAttachmentDownloadUrl = dependencies.getAttachmentDownloadUrl ?? ChatApi.getAttachmentDownloadUrl;
  const resolvedCache = new Map<string, string>();
  const inflightCache = new Map<string, Promise<string>>();

  return {
    getCached(request: AttachmentPreviewRequest): string | null {
      return resolvedCache.get(buildCacheKey(request)) ?? null;
    },
    clear(request: AttachmentPreviewRequest) {
      resolvedCache.delete(buildCacheKey(request));
      inflightCache.delete(buildCacheKey(request));
    },
    async resolve(request: AttachmentPreviewRequest): Promise<string> {
      const cacheKey = buildCacheKey(request);
      const cached = resolvedCache.get(cacheKey);
      if (cached) {
        return cached;
      }

      const inflight = inflightCache.get(cacheKey);
      if (inflight) {
        return inflight;
      }

      const nextPromise = (async () => {
        const response = await getAttachmentDownloadUrl({
          roomId: request.roomId,
          key: request.key,
          expiresInSeconds: request.expiresInSeconds
        });
        if (!response.success || !response.data?.downloadUrl) {
          throw new Error(response.message || "获取附件预览链接失败");
        }

        resolvedCache.set(cacheKey, response.data.downloadUrl);
        return response.data.downloadUrl;
      })();

      inflightCache.set(cacheKey, nextPromise);

      try {
        return await nextPromise;
      } finally {
        inflightCache.delete(cacheKey);
      }
    }
  };
};
