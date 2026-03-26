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

export interface AttachmentPreviewImageLike {
  src: string;
  onload: (() => void) | null;
  onerror: (() => void) | null;
}

export interface AttachmentPreviewImagePreloadStoreDependencies {
  createImage?: () => AttachmentPreviewImageLike | null;
}

const INLINE_PREVIEW_PART_TYPES = new Set<ChatMessagePart["partType"] | Exclude<ChatMessagePartInput["type"], "text">>([
  "image",
  "video",
  "audio"
]);
const BROWSER_IMAGE_PRELOAD_PART_TYPES = new Set<ChatMessagePart["partType"]>([
  "image",
  "video",
]);

const buildCacheKey = (request: AttachmentPreviewRequest) => `${request.roomId}:${request.key}`;

export const shouldInlinePreviewAttachment = (partType: ChatMessagePart["partType"]) =>
  INLINE_PREVIEW_PART_TYPES.has(partType);

export const shouldPreloadAttachmentPreviewImage = (partType: ChatMessagePart["partType"]) =>
  BROWSER_IMAGE_PRELOAD_PART_TYPES.has(partType);

export const getInlinePreviewAssetKey = (part: Pick<ChatMessagePart, "partType" | "attachment">) => {
  if (!part.attachment?.key) {
    return null;
  }
  if (part.partType === "video" && part.attachment.thumbnailKey) {
    return part.attachment.thumbnailKey;
  }
  return part.attachment.key;
};

export const createAttachmentPreviewImagePreloadStore = (
  dependencies: AttachmentPreviewImagePreloadStoreDependencies = {},
) => {
  const createImage =
    dependencies.createImage ??
    (() => (typeof Image === "undefined" ? null : (new Image() as AttachmentPreviewImageLike)));
  const resolvedCache = new Map<string, AttachmentPreviewImageLike>();
  const inflightCache = new Map<string, Promise<void>>();

  return {
    has(url: string) {
      return resolvedCache.has(url.trim());
    },
    clear(url?: string) {
      if (typeof url === "string") {
        const normalizedUrl = url.trim();
        resolvedCache.delete(normalizedUrl);
        inflightCache.delete(normalizedUrl);
        return;
      }

      resolvedCache.clear();
      inflightCache.clear();
    },
    async preload(url: string): Promise<void> {
      const normalizedUrl = url.trim();
      if (!normalizedUrl) {
        return;
      }

      if (resolvedCache.has(normalizedUrl)) {
        return;
      }

      const inflight = inflightCache.get(normalizedUrl);
      if (inflight) {
        return inflight;
      }

      const image = createImage();
      if (!image) {
        return;
      }

      const nextPromise = new Promise<void>((resolve, reject) => {
        image.onload = () => {
          resolvedCache.set(normalizedUrl, image);
          inflightCache.delete(normalizedUrl);
          resolve();
        };
        image.onerror = () => {
          inflightCache.delete(normalizedUrl);
          reject(new Error("图片预加载失败"));
        };
        image.src = normalizedUrl;
      });

      inflightCache.set(normalizedUrl, nextPromise);
      return nextPromise;
    },
  };
};

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
