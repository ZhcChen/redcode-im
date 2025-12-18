import { post } from './http';
import type { ApiResponse } from './http';
import type { DirectUploadSignatureInfo } from './message';

export type ReportTargetType = 'room' | 'user';

export interface ReportAttachmentSignatureResult {
  key: string;
  signature: DirectUploadSignatureInfo | null;
  message?: string;
}

export interface CreateReportResult {
  reportId: string;
}

export class ReportApi {
  static async requestAttachmentSignature(params: {
    filename?: string;
    contentType: string;
    fileSize: number;
    hashValue?: string;
    hashAlg?: number;
  }): Promise<ApiResponse<ReportAttachmentSignatureResult>> {
    const payload: Record<string, unknown> = {
      content_type: params.contentType,
      file_size: params.fileSize,
    };

    if (params.filename) {
      payload.filename = params.filename;
    }
    if (params.hashValue) {
      payload.hash_value = params.hashValue;
    }
    if (typeof params.hashAlg === 'number') {
      payload.hash_alg = params.hashAlg;
    }

    const response = await post<Record<string, unknown>>(
      '/reports/attachments/signature',
      payload
    );

    if (!response.success || !response.data) {
      return { ...response, data: null };
    }

    const rawData: any = response.data;
    const successFlag =
      typeof rawData?.success === 'boolean' ? rawData.success : response.success;

    if (!successFlag) {
      return {
        code: response.code,
        success: false,
        message:
          typeof rawData?.message === 'string'
            ? rawData.message
            : response.message || '获取截图上传签名失败',
        data: null,
      };
    }

    const rawSignature = rawData?.signature ?? null;
    const key = rawData?.key ?? rawSignature?.key ?? null;

    if (!key || typeof key !== 'string') {
      return {
        code: response.code,
        success: false,
        message: '上传签名响应不包含有效的 key',
        data: null,
      };
    }

    let signature: DirectUploadSignatureInfo | null = null;
    if (
      rawSignature &&
      typeof rawSignature === 'object' &&
      typeof rawSignature.url === 'string' &&
      rawSignature.url.length > 0
    ) {
      const headers: Record<string, string> = {};
      if (rawSignature.headers && typeof rawSignature.headers === 'object') {
        Object.entries(rawSignature.headers).forEach(([headerKey, headerValue]) => {
          if (typeof headerKey === 'string' && typeof headerValue === 'string') {
            headers[headerKey] = headerValue;
          }
        });
      }

      const methodRaw =
        typeof rawSignature.method === 'string'
          ? rawSignature.method.trim().toUpperCase()
          : 'PUT';

      signature = {
        url: rawSignature.url,
        method: methodRaw || 'PUT',
        headers,
        key: rawSignature.key ?? key,
      };
    }

    return {
      code: response.code,
      success: true,
      message:
        typeof rawData?.message === 'string' ? rawData.message : response.message || '',
      data: {
        key,
        signature,
        message: typeof rawData?.message === 'string' ? rawData.message : undefined,
      },
    };
  }

  static async commitAttachmentUpload(params: {
    key: string;
    hashValue?: string;
    hashAlg?: number;
    fileSize?: number;
  }): Promise<ApiResponse<null>> {
    const payload: Record<string, unknown> = {
      key: params.key,
    };
    if (params.hashValue) {
      payload.hash_value = params.hashValue;
    }
    if (typeof params.hashAlg === 'number') {
      payload.hash_alg = params.hashAlg;
    }
    if (typeof params.fileSize === 'number') {
      payload.file_size = params.fileSize;
    }

    const response = await post<Record<string, unknown>>(
      '/reports/attachments/commit',
      payload
    );

    if (!response.success || !response.data) {
      return { ...response, data: null };
    }

    const rawData: any = response.data;
    const successFlag =
      typeof rawData?.success === 'boolean' ? rawData.success : response.success;

    return {
      code: response.code,
      success: successFlag,
      message:
        typeof rawData?.message === 'string'
          ? rawData.message
          : response.message || '',
      data: null,
    };
  }

  static async createReport(params: {
    targetType: ReportTargetType;
    targetId: string;
    content: string;
    attachmentKeys: string[];
  }): Promise<ApiResponse<CreateReportResult>> {
    const response = await post<Record<string, unknown>>('/reports', {
      target_type: params.targetType,
      target_id: params.targetId,
      content: params.content,
      attachment_keys: params.attachmentKeys,
    });

    if (!response.success || !response.data) {
      return { ...response, data: null };
    }

    const rawData: any = response.data;
    const successFlag =
      typeof rawData?.success === 'boolean' ? rawData.success : response.success;

    if (!successFlag) {
      return {
        code: response.code,
        success: false,
        message:
          typeof rawData?.message === 'string'
            ? rawData.message
            : response.message || '举报提交失败',
        data: null,
      };
    }

    return {
      code: response.code,
      success: true,
      message:
        typeof rawData?.message === 'string' ? rawData.message : response.message || '',
      data: {
        reportId: typeof rawData?.report_id === 'string' ? rawData.report_id : '',
      },
    };
  }
}

