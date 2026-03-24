import { ChatApi, type ChatMessagePartInput, type DirectUploadSignatureInfo } from "@/api/chat";
import {
  MULTIPART_THRESHOLD_BYTES,
  buildAttachmentPartInput,
  determineAttachmentMeta,
  type MultipartUploadCallbacks,
  uploadMultipartWithSession,
  uploadWithSignature
} from "./chat-attachment-upload";
import { computeFileHash, type FileHashResult } from "./fileHash";

interface AttachmentUploadBaseParams {
  roomId: string;
  partType: Exclude<ChatMessagePartInput["type"], "text">;
  fileName?: string;
  contentType?: string;
  fileSize: number;
  hashValue?: string;
  hashAlg?: number;
}

export interface UploadAttachmentAndBuildPartOptions {
  roomId: string;
  file: File;
  multipartThresholdBytes?: number;
  onProgress?: (progress: number) => void;
}

export interface UploadAttachmentAndBuildPartDependencies {
  determineAttachmentMeta?: typeof determineAttachmentMeta;
  computeFileHash?: (file: Blob) => Promise<FileHashResult>;
  requestAttachmentSignature?: typeof ChatApi.requestAttachmentSignature;
  initiateAttachmentMultipartUpload?: typeof ChatApi.initiateAttachmentMultipartUpload;
  generateMultipartPartSignature?: typeof ChatApi.generateMultipartPartSignature;
  commitMultipartPart?: typeof ChatApi.commitMultipartPart;
  completeMultipartUpload?: typeof ChatApi.completeMultipartUpload;
  abortMultipartUpload?: typeof ChatApi.abortMultipartUpload;
  uploadWithSignature?: typeof uploadWithSignature;
  uploadMultipartWithSession?: typeof uploadMultipartWithSession;
  commitAttachmentUpload?: typeof ChatApi.commitAttachmentUpload;
}

const buildUploadParams = (
  options: UploadAttachmentAndBuildPartOptions,
  meta: Awaited<ReturnType<typeof determineAttachmentMeta>>,
  hashResult: FileHashResult
): AttachmentUploadBaseParams => ({
  roomId: options.roomId,
  partType: meta.partType,
  fileName: options.file.name,
  contentType: meta.mime ?? undefined,
  fileSize: options.file.size,
  hashValue: hashResult.hashValue ?? undefined,
  hashAlg: hashResult.hashAlg ?? undefined
});

const ensureSuccess = <T>(
  response: { success: boolean; data: T | null; message: string },
  fallbackMessage: string
): T => {
  if (!response.success || !response.data) {
    throw new Error(response.message || fallbackMessage);
  }
  return response.data;
};

const ensureSimpleSuccess = (response: { success: boolean; message: string }, fallbackMessage: string) => {
  if (!response.success) {
    throw new Error(response.message || fallbackMessage);
  }
};

const createMultipartCallbacks = (
  sessionId: string,
  dependencies: Required<Pick<
    UploadAttachmentAndBuildPartDependencies,
    "generateMultipartPartSignature" | "commitMultipartPart" | "completeMultipartUpload" | "abortMultipartUpload"
  >>
): MultipartUploadCallbacks => ({
  generatePartSignature: async (partNumber: number): Promise<DirectUploadSignatureInfo> => {
    const response = await dependencies.generateMultipartPartSignature({ sessionId, partNumber });
    return ensureSuccess(response, `获取第 ${partNumber} 个分片上传签名失败`).signature;
  },
  commitPart: async (partNumber: number, etag: string) => {
    const response = await dependencies.commitMultipartPart({ sessionId, partNumber, etag });
    ensureSimpleSuccess(response, `提交第 ${partNumber} 个分片失败`);
  },
  completeUpload: async (parts) => {
    const response = await dependencies.completeMultipartUpload({ sessionId, parts });
    ensureSimpleSuccess(response, "完成分片上传失败");
  },
  abortUpload: async () => {
    const response = await dependencies.abortMultipartUpload({ sessionId });
    ensureSimpleSuccess(response, "中止分片上传失败");
  }
});

export async function uploadAttachmentAndBuildPart(
  options: UploadAttachmentAndBuildPartOptions,
  overrides: UploadAttachmentAndBuildPartDependencies = {}
): Promise<ChatMessagePartInput> {
  const dependencies = {
    determineAttachmentMeta,
    computeFileHash,
    requestAttachmentSignature: ChatApi.requestAttachmentSignature,
    initiateAttachmentMultipartUpload: ChatApi.initiateAttachmentMultipartUpload,
    generateMultipartPartSignature: ChatApi.generateMultipartPartSignature,
    commitMultipartPart: ChatApi.commitMultipartPart,
    completeMultipartUpload: ChatApi.completeMultipartUpload,
    abortMultipartUpload: ChatApi.abortMultipartUpload,
    uploadWithSignature,
    uploadMultipartWithSession,
    commitAttachmentUpload: ChatApi.commitAttachmentUpload,
    ...overrides
  };

  const meta = await dependencies.determineAttachmentMeta(options.file);
  const hashResult = await dependencies.computeFileHash(options.file);
  const uploadParams = buildUploadParams(options, meta, hashResult);

  let key = "";
  let hasUploadedFileBody = false;

  if (options.file.size > (options.multipartThresholdBytes ?? MULTIPART_THRESHOLD_BYTES)) {
    const multipartInit = ensureSuccess(
      await dependencies.initiateAttachmentMultipartUpload(uploadParams),
      "初始化分片上传失败"
    );

    key = multipartInit.key;

    if (multipartInit.sessionId) {
      if (!multipartInit.partSize || !multipartInit.totalParts) {
        throw new Error("分片上传会话缺少 partSize 或 totalParts");
      }

      await dependencies.uploadMultipartWithSession({
        file: options.file,
        partSize: multipartInit.partSize,
        totalParts: multipartInit.totalParts,
        callbacks: createMultipartCallbacks(multipartInit.sessionId, dependencies),
        onProgress: options.onProgress
      });
      hasUploadedFileBody = true;
    }
  } else {
    const directUpload = ensureSuccess(
      await dependencies.requestAttachmentSignature(uploadParams),
      "获取附件上传签名失败"
    );

    key = directUpload.key;

    if (directUpload.signature) {
      await dependencies.uploadWithSignature(directUpload.signature, options.file, options.onProgress);
      hasUploadedFileBody = true;
    }
  }

  if (!key) {
    throw new Error("附件上传流程未返回对象 key");
  }

  if (hasUploadedFileBody) {
    const commitResponse = await dependencies.commitAttachmentUpload({
      roomId: options.roomId,
      key,
      fileSize: options.file.size,
      hashValue: hashResult.hashValue ?? undefined,
      hashAlg: hashResult.hashAlg ?? undefined
    });
    ensureSimpleSuccess(commitResponse, "确认附件上传失败");
  }

  return buildAttachmentPartInput(meta, key, options.file);
}
