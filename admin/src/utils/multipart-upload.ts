import {
  abortAdminMultipartUpload,
  commitAdminMultipartPart,
  completeAdminMultipartUpload,
  generateAdminMultipartPartSignature,
  type MultipartCompletedPart,
} from '@/services/multipart-upload';
import { uploadWithSignature } from '@/utils/direct-upload';

const normalizeEtag = (etag: string) => etag.trim().replace(/"/g, '');

export interface MultipartUploadOptions {
  file: File;
  sessionId: string;
  partSize: number;
  totalParts: number;
  onProgress?: (uploadedParts: number, totalParts: number) => void;
  autoAbortOnError?: boolean;
}

export async function uploadFileByMultipartAndComplete(
  options: MultipartUploadOptions
): Promise<{ parts: MultipartCompletedPart[] }> {
  const parts: MultipartCompletedPart[] = [];

  try {
    /* eslint-disable no-await-in-loop */
    for (
      let partNumber = 1;
      partNumber <= options.totalParts;
      partNumber += 1
    ) {
      const start = (partNumber - 1) * options.partSize;
      const end = Math.min(options.file.size, partNumber * options.partSize);
      const chunk = options.file.slice(start, end);

      const { data: signatureData } = await generateAdminMultipartPartSignature(
        options.sessionId,
        partNumber
      );
      if (!signatureData.success || !signatureData.signature) {
        throw new Error(signatureData.message || '获取分片上传签名失败');
      }

      const response = await uploadWithSignature(
        chunk,
        signatureData.signature
      );
      if (!response.ok) {
        const text = await response.text();
        throw new Error(text || `上传分片失败（part ${partNumber}）`);
      }

      // 注意：浏览器侧必须能读取 ETag，否则无法完成分片合并。
      const rawEtag =
        response.headers.get('etag') || response.headers.get('ETag');
      if (!rawEtag) {
        throw new Error(
          '上传分片成功但未读取到 ETag，请检查对象存储返回头是否允许浏览器读取 ETag'
        );
      }
      const etag = normalizeEtag(rawEtag);

      const { data: commitData } = await commitAdminMultipartPart(
        options.sessionId,
        partNumber,
        etag
      );
      if (!commitData.success) {
        throw new Error(
          commitData.message || `提交分片进度失败（part ${partNumber}）`
        );
      }

      parts.push({ part_number: partNumber, etag });
      if (options.onProgress) {
        options.onProgress(partNumber, options.totalParts);
      }
    }
    /* eslint-enable no-await-in-loop */

    const { data: completeData } = await completeAdminMultipartUpload(
      options.sessionId,
      parts
    );
    if (!completeData.success) {
      throw new Error(completeData.message || '完成分片上传失败');
    }

    return { parts };
  } catch (error) {
    if (options.autoAbortOnError !== false) {
      try {
        await abortAdminMultipartUpload(options.sessionId);
      } catch {
        // ignore
      }
    }
    throw error;
  }
}
