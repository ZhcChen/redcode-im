import { get, post, type ApiResponse } from "./http";
import type { DirectUploadSignatureInfo } from "./chat";
import type { LegacyUserInfo } from "./system";
import { computeFileHash } from "../utils/fileHash";
import { uploadWithSignature } from "../utils/chat-attachment-upload";

interface BackendUserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatar_url?: string | null;
  avatar_object_key?: string | null;
  status: "active" | "inactive" | "banned";
}

export interface SearchUserInfo {
  id: string;
  username: string;
  email: string | null;
  nickname: string | null;
  avatarUrl: string | null;
  avatarObjectKey: string | null;
  status: "active" | "inactive" | "banned" | null;
}

interface AvatarDirectUploadPayload {
  success?: boolean;
  message?: string;
  key?: string | null;
  signature?: DirectUploadSignatureInfo | null;
}

interface AvatarCommitPayload {
  success?: boolean;
  message?: string;
  download_url?: string | null;
}

interface PasswordUpdatePayload {
  success?: boolean;
  message?: string;
}

const mapBackendToLegacy = (user: BackendUserInfo): LegacyUserInfo => ({
  id: user.id,
  username: user.username,
  nickname: user.nickname || user.username,
  avatar: user.avatar_url || "",
  avatarObjectKey: user.avatar_object_key || null,
  avatarLocalPath: null,
  mobile: user.username,
  email: user.email || "",
  isLoggedIn: true,
  realName: user.nickname || user.username,
  chatNumber: user.username,
  address: "",
  createTime: null,
  lastLoginTime: null,
  activeStatus: user.status === "active" ? 1 : user.status === "inactive" ? 0 : -1,
  delFlag: null,
  level: null,
  userDeviceId: null,
  userSign: null,
  trcSdkAppId: null,
  powerList: null
});

const mapBackendToSearchUser = (user: BackendUserInfo): SearchUserInfo => ({
  id: user.id,
  username: user.username,
  email: user.email || null,
  nickname: user.nickname || null,
  avatarUrl: user.avatar_url || null,
  avatarObjectKey: user.avatar_object_key || null,
  status: user.status || null
});

const normalizeDirectUploadSignature = (
  signature: DirectUploadSignatureInfo | null | undefined,
  key: string
): DirectUploadSignatureInfo | null => {
  if (!signature) {
    return null;
  }

  return {
    ...signature,
    key: signature.key || key
  };
};

const requireDesktopRuntime = () => {
  if (!window.desktopEl) {
    throw new Error("desktop-el runtime is not available");
  }
  return window.desktopEl;
};

export class UserApi {
  static async searchUsers(params: { keyword: string; limit?: number }): Promise<ApiResponse<SearchUserInfo[]>> {
    const keyword = params.keyword.trim();
    if (!keyword) {
      return {
        code: 400,
        success: false,
        message: "请输入搜索关键词",
        data: []
      };
    }

    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendUserInfo[]>>("user.search", {
      keyword,
      limit: params.limit
    });
    return {
      ...response,
      data: response.data ? response.data.map(mapBackendToSearchUser) : []
    };
  }

  static async getUserAccountInfo(params: { userId?: string } = {}): Promise<ApiResponse<LegacyUserInfo>> {
    const path = params.userId && params.userId !== "me" ? `/users/${params.userId}` : "/auth/me";
    const response = await get<BackendUserInfo>(path);
    return {
      ...response,
      data: response.data ? mapBackendToLegacy(response.data) : null
    };
  }

  static async updateMe(params: { nickname?: string; avatarUrl?: string }): Promise<ApiResponse<LegacyUserInfo>> {
    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendUserInfo>>("user.me.update", {
      nickname: params.nickname,
      avatar_url: params.avatarUrl
    });
    return {
      ...response,
      data: response.data ? mapBackendToLegacy(response.data) : null
    };
  }

  static async uploadAvatar(file: File): Promise<ApiResponse<LegacyUserInfo>> {
    const contentType = file.type || "application/octet-stream";
    const { hashValue, hashAlg } = await computeFileHash(file);
    const directUploadBody: Record<string, unknown> = {
      content_type: contentType,
      file_size: file.size
    };

    if (hashValue) {
      directUploadBody.hash_value = hashValue;
    }
    if (typeof hashAlg === "number") {
      directUploadBody.hash_alg = hashAlg;
    }

    const directResponse = await post<AvatarDirectUploadPayload>("/users/me/avatar/direct-upload", directUploadBody);
    if (!directResponse.success || !directResponse.data) {
      return {
        ...directResponse,
        data: null
      };
    }

    const directPayload = directResponse.data;
    const directSuccess = typeof directPayload.success === "boolean" ? directPayload.success : directResponse.success;
    const key = directPayload.key ?? directPayload.signature?.key ?? null;
    const directMessage = directPayload.message || directResponse.message || "";

    if (!directSuccess || !key) {
      return {
        code: directResponse.code,
        success: false,
        message: directMessage || "获取头像上传签名失败",
        data: null
      };
    }

    const signature = normalizeDirectUploadSignature(directPayload.signature, key);
    if (signature) {
      await uploadWithSignature(signature, file);
    }

    const commitResponse = await post<AvatarCommitPayload>("/users/me/avatar/commit", {
      key,
      delete_previous: true,
      expires_in_seconds: 600
    });

    if (!commitResponse.success || !commitResponse.data) {
      return {
        ...commitResponse,
        data: null
      };
    }

    const commitPayload = commitResponse.data;
    const commitSuccess = typeof commitPayload.success === "boolean" ? commitPayload.success : commitResponse.success;
    const commitMessage = commitPayload.message || commitResponse.message || "";
    if (!commitSuccess) {
      return {
        code: commitResponse.code,
        success: false,
        message: commitMessage || "头像更新失败",
        data: null
      };
    }

    const profileResponse = await UserApi.getUserAccountInfo();
    if (!profileResponse.success || !profileResponse.data) {
      return {
        code: profileResponse.code,
        success: false,
        message: profileResponse.message || commitMessage || "头像更新后刷新资料失败",
        data: null
      };
    }

    return {
      code: profileResponse.code,
      success: true,
      message: commitMessage || "头像更新成功",
      data: profileResponse.data
    };
  }

  static async updateUserPassword(params: {
    oldPwd: string;
    newPwd: string;
  }): Promise<ApiResponse<{ success: boolean; message?: string }>> {
    const response = await post<PasswordUpdatePayload>("/users/me/password", {
      old_password: params.oldPwd,
      new_password: params.newPwd
    });
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null
      };
    }

    return {
      ...response,
      data: {
        success: typeof response.data.success === "boolean" ? response.data.success : response.success,
        message: response.data.message
      }
    };
  }
}
