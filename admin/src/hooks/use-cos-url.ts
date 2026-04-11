import { ref, watch, onMounted } from 'vue';
import { testCosDownloadUrl } from '@/services/storage-providers';

/**
 * 全局缓存，用于在不同组件实例间复用已签署的 URL
 * key: objectKey
 * value: { url: string, expireAt: number }
 */
const globalUrlCache = new Map<string, { url: string; expireAt: number }>();

/**
 * 检查 URL 是否过期或需要刷新
 * @param targetUrl 待检查的 URL
 * @returns true 表示已过期或不可用
 */
export function isCosUrlExpired(targetUrl: string | null | undefined): boolean {
  if (!targetUrl) return true;
  // 仅针对包含腾讯云签名特征的 URL 进行过期判定
  if (!targetUrl.includes('q-sign-time=')) return false;

  try {
    const match = targetUrl.match(/q-sign-time=(\d+);(\d+)/);
    if (match) {
      const endTimestamp = parseInt(match[2], 10) * 1000;
      // 距离过期不到 10 分钟时，认为需要刷新
      return Date.now() > endTimestamp - 10 * 60 * 1000;
    }
  } catch (e) {
    return true;
  }
  return false;
}

/**
 * useCosUrl Hook
 * 用于管理腾讯 COS 私有资源的临时访问地址，支持自动刷新和全局缓存。
 *
 * @param objectKey COS 对象键
 * @param initialUrl 初始 URL（可能来自后端 API 返回的已过期地址）
 * @param providerId 存储提供商 ID（可选，如不传则使用默认存储提供商）
 */
export default function useCosUrl(
  objectKey: string | null | undefined,
  initialUrl?: string | null,
  providerId?: string | null
) {
  const url = ref(initialUrl || '');
  const loading = ref(false);

  const fetchNewUrl = async (key: string) => {
    // 1. 尝试从全局缓存获取
    const cached = globalUrlCache.get(key);
    if (cached && !isCosUrlExpired(cached.url)) {
      url.value = cached.url;
      return;
    }

    // 2. 请求后端生成新签名
    loading.value = true;
    try {
      const { data } = await testCosDownloadUrl({
        key,
        provider_id: providerId || undefined,
        expires_in_seconds: 3600 * 12, // 默认申请 12 小时有效期
      });

      if (data.success && data.url) {
        url.value = data.url;
        // 更新全局缓存
        globalUrlCache.set(key, {
          url: data.url,
          expireAt: Date.now() + 11.5 * 3600 * 1000, // 设为 11.5 小时后过期
        });
      }
    } catch (err) {
      console.error(`[useCosUrl] Failed to fetch URL for key: ${key}`, err);
    } finally {
      loading.value = false;
    }
  };

  const checkAndRefresh = () => {
    if (!objectKey) {
      url.value = '';
      return;
    }

    if (isCosUrlExpired(url.value)) {
      fetchNewUrl(objectKey);
    }
  };

  onMounted(checkAndRefresh);

  watch(
    () => objectKey,
    (newKey) => {
      if (newKey) {
        checkAndRefresh();
      } else {
        url.value = '';
      }
    }
  );

  return {
    url,
    loading,
    refresh: checkAndRefresh,
  };
}
