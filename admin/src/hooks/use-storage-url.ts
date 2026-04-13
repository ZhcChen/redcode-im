import { ref, watch, onMounted } from 'vue';
import { testStorageDownloadUrl } from '@/services/storage-providers';

const globalUrlCache = new Map<string, { url: string; expireAt: number }>();

function resolveSignedUrlExpireAt(targetUrl: string): number | null {
  try {
    const parsed = new URL(targetUrl);
    const expires = parsed.searchParams.get('X-Amz-Expires');
    const timestamp = parsed.searchParams.get('X-Amz-Date');
    if (expires && timestamp) {
      const base = Date.UTC(
        Number(timestamp.slice(0, 4)),
        Number(timestamp.slice(4, 6)) - 1,
        Number(timestamp.slice(6, 8)),
        Number(timestamp.slice(9, 11)),
        Number(timestamp.slice(11, 13)),
        Number(timestamp.slice(13, 15))
      );
      if (!Number.isNaN(base)) {
        return base + Number(expires) * 1000;
      }
    }
  } catch {
    return null;
  }

  return null;
}

export function isStorageUrlExpired(
  targetUrl: string | null | undefined
): boolean {
  if (!targetUrl) return true;

  const expireAt = resolveSignedUrlExpireAt(targetUrl);
  if (!expireAt) return false;

  return Date.now() > expireAt - 10 * 60 * 1000;
}

export default function useStorageUrl(
  objectKey: string | null | undefined,
  initialUrl?: string | null,
  providerId?: string | null
) {
  const url = ref(initialUrl || '');
  const loading = ref(false);

  const fetchNewUrl = async (key: string) => {
    const cached = globalUrlCache.get(key);
    if (cached && Date.now() < cached.expireAt) {
      url.value = cached.url;
      return;
    }

    loading.value = true;
    try {
      const { data } = await testStorageDownloadUrl({
        key,
        provider_id: providerId || undefined,
        expires_in_seconds: 3600 * 12,
      });

      if (data.success && data.url) {
        url.value = data.url;
        const expireAt =
          resolveSignedUrlExpireAt(data.url) ?? Date.now() + 11.5 * 3600 * 1000;
        globalUrlCache.set(key, { url: data.url, expireAt });
      }
    } catch (err) {
      console.error(`[useStorageUrl] Failed to fetch URL for key: ${key}`, err);
    } finally {
      loading.value = false;
    }
  };

  const checkAndRefresh = () => {
    if (!objectKey) {
      url.value = '';
      return;
    }

    if (isStorageUrlExpired(url.value)) {
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
