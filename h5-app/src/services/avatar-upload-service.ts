import { requestJson } from '@/api/http';

import { requireToken } from './session';

const AVATAR_MAX_SIZE_BYTES = 5 * 1024 * 1024;

interface DirectUploadSignature {
  url: string;
  method?: string;
  headers?: Record<string, string>;
  key?: string;
}

interface DirectUploadResponse {
  success?: boolean;
  message?: string;
  key?: string | null;
  signature?: DirectUploadSignature | null;
}

interface UserAvatarCommitResponse {
  success?: boolean;
  message?: string;
  download_url?: string | null;
}

interface RoomAvatarCommitResponse {
  success?: boolean;
  message?: string;
  avatar_url?: string | null;
}

export interface AvatarUploadResult {
  objectKey: string;
  downloadUrl?: string | null;
}

export const avatarUploadService = {
  async uploadUserAvatar(file: File): Promise<AvatarUploadResult> {
    validateAvatarFile(file);
    const descriptor = await requestUploadDescriptor('/users/me/avatar/direct-upload', file);
    await uploadToSignedUrl(descriptor, file);
    const response = await requestJson<UserAvatarCommitResponse>('/users/me/avatar/commit', {
      method: 'POST',
      body: JSON.stringify({
        key: descriptor.objectKey,
        delete_previous: true,
        expires_in_seconds: 3600,
      }),
    }, requireToken());
    assertSuccess(response, '头像提交失败');
    return {
      objectKey: descriptor.objectKey,
      downloadUrl: response.download_url ?? null,
    };
  },

  async uploadRoomAvatar(roomId: string, file: File): Promise<AvatarUploadResult> {
    if (!roomId) throw new Error('群聊不存在');
    validateAvatarFile(file);
    const descriptor = await requestUploadDescriptor(`/rooms/${roomId}/avatar/direct-upload`, file);
    await uploadToSignedUrl(descriptor, file);
    const response = await requestJson<RoomAvatarCommitResponse>(`/rooms/${roomId}/avatar/commit`, {
      method: 'POST',
      body: JSON.stringify({ key: descriptor.objectKey }),
    }, requireToken());
    assertSuccess(response, '群头像提交失败');
    return {
      objectKey: descriptor.objectKey,
      downloadUrl: response.avatar_url ?? null,
    };
  },
};

const requestUploadDescriptor = async (path: string, file: File) => {
  const response = await requestJson<DirectUploadResponse>(path, {
    method: 'POST',
    body: JSON.stringify({
      filename: file.name || 'avatar.png',
      content_type: file.type || 'application/octet-stream',
      file_size: file.size,
    }),
  }, requireToken());
  assertSuccess(response, '头像直传签名生成失败');
  const objectKey = response.key ?? response.signature?.key ?? '';
  if (!objectKey) throw new Error('头像直传签名缺少 object key');
  return {
    objectKey,
    signature: response.signature ?? null,
  };
};

const uploadToSignedUrl = async (
  descriptor: { objectKey: string; signature: DirectUploadSignature | null },
  file: File,
) => {
  if (!descriptor.signature) return;
  if (!descriptor.signature.url) {
    throw new Error('头像直传签名缺少上传地址');
  }
  const response = await fetch(descriptor.signature.url, {
    method: descriptor.signature.method || 'PUT',
    headers: descriptor.signature.headers,
    body: file,
  });
  if (!response.ok) {
    throw new Error(`头像上传失败 (${response.status})`);
  }
};

export const validateAvatarFile = (file: File) => {
  if (!file) throw new Error('请选择头像文件');
  if (!file.type.startsWith('image/')) {
    throw new Error('头像仅支持图片文件');
  }
  if (file.size > AVATAR_MAX_SIZE_BYTES) {
    throw new Error('头像文件不能超过 5MB');
  }
};

const assertSuccess = (response: { success?: boolean; message?: string }, fallback: string) => {
  if (response.success === false) {
    throw new Error(response.message || fallback);
  }
};
