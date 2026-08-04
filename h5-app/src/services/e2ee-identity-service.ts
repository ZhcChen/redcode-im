import { requestJson } from '@/api/http';
import type { E2eeRootIdentity } from '@/e2ee/identity-trust';
import { requireToken } from './session';

interface RootIdentityResponse {
  user_id: string;
  root_public_key: string;
  root_fingerprint: string;
  protocol_version: number;
}

export const e2eeIdentityService = {
  async fetchRootIdentity(userId: string): Promise<E2eeRootIdentity> {
    const normalized = userId.trim();
    if (!normalized) throw new Error('E2EE 用户标识不能为空');
    const response = await requestJson<RootIdentityResponse>(
      `/e2ee/mls/identities/${encodeURIComponent(normalized)}`,
      {},
      requireToken(),
    );
    if (response.user_id !== normalized) throw new Error('E2EE 身份账号不匹配');
    return {
      userId: response.user_id,
      publicKey: decodeBase64(response.root_public_key),
      fingerprint: decodeBase64(response.root_fingerprint),
      protocolVersion: response.protocol_version,
    };
  },
};

const decodeBase64 = (value: string) => {
  if (!value || value.length % 4 !== 0 || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value)) {
    throw new Error('E2EE 根身份 Base64 格式无效');
  }
  return Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
};
