import type {
  ChatMessagePartInput,
  DirectUploadSignatureInfo,
  MultipartCompletedPart
} from "@/api/chat";

export type UploadAttachmentPartType = Exclude<ChatMessagePartInput["type"], "text">;

export interface AttachmentMeta {
  partType: UploadAttachmentPartType;
  mime: string | null;
  width: number | null;
  height: number | null;
  durationMs: number | null;
  thumbnailKey: string | null;
}

export interface MultipartUploadCallbacks {
  generatePartSignature(partNumber: number): Promise<DirectUploadSignatureInfo>;
  commitPart(partNumber: number, etag: string): Promise<void>;
  completeUpload(parts: MultipartCompletedPart[]): Promise<void>;
  abortUpload(): Promise<void>;
}

const forbiddenDirectUploadHeaders = new Set(["host", "content-length", "origin", "referer"]);

export const MULTIPART_THRESHOLD_BYTES = 5 * 1024 * 1024;

export const inferAttachmentPartType = (file: { type?: string; name?: string }): UploadAttachmentPartType => {
  const mime = (file.type || "").toLowerCase();
  if (mime.startsWith("image/")) {
    return "image";
  }
  if (mime.startsWith("video/")) {
    return "video";
  }
  if (mime.startsWith("audio/")) {
    return "audio";
  }

  const extension = (file.name || "").split(".").pop()?.toLowerCase() ?? "";
  if (["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"].includes(extension)) {
    return "image";
  }
  if (["mp4", "mov", "m4v", "webm", "avi", "mkv"].includes(extension)) {
    return "video";
  }
  if (["mp3", "wav", "m4a", "aac", "ogg", "flac"].includes(extension)) {
    return "audio";
  }
  return "file";
};

const readImageDimensions = async (file: File): Promise<{ width: number | null; height: number | null }> => {
  const objectURL = URL.createObjectURL(file);
  try {
    const dimensions = await new Promise<{ width: number; height: number }>((resolve, reject) => {
      const image = new Image();
      image.onload = () => resolve({ width: image.naturalWidth, height: image.naturalHeight });
      image.onerror = () => reject(new Error("image metadata load failed"));
      image.src = objectURL;
    });
    return dimensions;
  } catch (error) {
    console.warn("[desktop-el-renderer] read image dimensions failed", error);
    return { width: null, height: null };
  } finally {
    URL.revokeObjectURL(objectURL);
  }
};

export const determineAttachmentMeta = async (file: File): Promise<AttachmentMeta> => {
  const partType = inferAttachmentPartType(file);
  const mime = file.type || null;
  const durationOverride =
    partType === "audio" &&
    typeof (file as File & { durationMs?: number }).durationMs === "number"
      ? Math.max(
          0,
          Math.round((file as File & { durationMs?: number }).durationMs ?? 0),
        )
      : null;

  if (partType === "image") {
    const dimensions = await readImageDimensions(file);
    return {
      partType,
      mime,
      width: dimensions.width,
      height: dimensions.height,
      durationMs: null,
      thumbnailKey: null
    };
  }

  return {
    partType,
    mime,
    width: null,
    height: null,
    durationMs: durationOverride,
    thumbnailKey: null
  };
};

export const buildAttachmentPartInput = (
  meta: AttachmentMeta,
  key: string,
  file: File
): ChatMessagePartInput => {
  const payload: ChatMessagePartInput = {
    type: meta.partType,
    key,
    name: file.name,
    mime: meta.mime ?? file.type ?? null,
    size: file.size
  };

  if (typeof meta.width === "number") {
    payload.width = meta.width;
  }
  if (typeof meta.height === "number") {
    payload.height = meta.height;
  }
  if (typeof meta.durationMs === "number") {
    payload.durationMs = meta.durationMs;
  }
  if (meta.thumbnailKey) {
    payload.thumbnailKey = meta.thumbnailKey;
  }

  return payload;
};

export const buildDirectUploadHeaders = (signatureHeaders: Record<string, string> | undefined, file: Blob) => {
  const normalizedHeaders: Record<string, string> = {};
  let hasContentTypeHeader = false;

  if (signatureHeaders && typeof signatureHeaders === "object") {
    Object.entries(signatureHeaders).forEach(([rawKey, rawValue]) => {
      const headerKey = typeof rawKey === "string" ? rawKey.trim() : "";
      if (!headerKey || typeof rawValue !== "string") {
        return;
      }
      const lowerKey = headerKey.toLowerCase();
      if (forbiddenDirectUploadHeaders.has(lowerKey)) {
        return;
      }
      if (lowerKey === "content-type") {
        hasContentTypeHeader = true;
      }
      normalizedHeaders[headerKey] = rawValue;
    });
  }

  if (!hasContentTypeHeader && file.type) {
    normalizedHeaders["Content-Type"] = file.type;
  }

  return normalizedHeaders;
};

const normalizeEtag = (etag: string) => etag.trim().replace(/"/g, "");

const uploadBlobByXHR = (
  url: string,
  method: string,
  headers: Record<string, string>,
  body: Blob,
  onProgress?: (progress: number) => void
) =>
  new Promise<XMLHttpRequest>((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open(method, url, true);

    Object.entries(headers).forEach(([headerKey, headerValue]) => {
      xhr.setRequestHeader(headerKey, headerValue);
    });

    xhr.upload.onprogress = (event) => {
      if (!onProgress || !event.lengthComputable || event.total <= 0) {
        return;
      }
      onProgress(Math.max(0, Math.min(1, event.loaded / event.total)));
    };

    xhr.onerror = () => reject(new Error("upload failed"));
    xhr.onabort = () => reject(new Error("upload aborted"));
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        onProgress?.(1);
        resolve(xhr);
        return;
      }
      reject(new Error(`upload failed with status ${xhr.status}`));
    };

    xhr.send(body);
  });

export const uploadWithSignature = async (
  signature: DirectUploadSignatureInfo,
  file: Blob,
  onProgress?: (progress: number) => void
) => {
  const headers = buildDirectUploadHeaders(signature.headers, file);
  const method = (signature.method || "PUT").toUpperCase();
  await uploadBlobByXHR(signature.url, method, headers, file, onProgress);
};

export const uploadMultipartWithSession = async ({
  file,
  partSize,
  totalParts,
  callbacks,
  onProgress
}: {
  file: Blob;
  partSize: number;
  totalParts: number;
  callbacks: MultipartUploadCallbacks;
  onProgress?: (progress: number) => void;
}) => {
  const uploadedParts: MultipartCompletedPart[] = [];
  let uploadedBytes = 0;

  try {
    for (let partNumber = 1; partNumber <= totalParts; partNumber += 1) {
      const start = (partNumber - 1) * partSize;
      const end = Math.min(file.size, partNumber * partSize);
      const chunk = file.slice(start, end);

      const signature = await callbacks.generatePartSignature(partNumber);
      const headers = buildDirectUploadHeaders(signature.headers, chunk);
      const method = (signature.method || "PUT").toUpperCase();
      const xhr = await uploadBlobByXHR(signature.url, method, headers, chunk, (chunkProgress) => {
        if (!onProgress || file.size <= 0) {
          return;
        }
        const loaded = uploadedBytes + chunk.size * chunkProgress;
        onProgress(Math.max(0, Math.min(1, loaded / file.size)));
      });

      const rawETag = xhr.getResponseHeader("ETag");
      if (!rawETag) {
        throw new Error(`part ${partNumber} uploaded without etag`);
      }
      const etag = normalizeEtag(rawETag);
      await callbacks.commitPart(partNumber, etag);
      uploadedParts.push({ partNumber, etag });
      uploadedBytes += chunk.size;
      onProgress?.(file.size > 0 ? Math.max(0, Math.min(1, uploadedBytes / file.size)) : 1);
    }

    await callbacks.completeUpload(uploadedParts);
  } catch (error) {
    try {
      await callbacks.abortUpload();
    } catch (abortError) {
      console.warn("[desktop-el-renderer] abort multipart upload failed", abortError);
    }
    throw error;
  }
};
