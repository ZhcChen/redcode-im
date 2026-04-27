use redis::{AsyncCommands, Client, RedisResult};

/// Redis 缓存管理器
pub struct CacheManager {
    client: Client,
}

impl CacheManager {
    /// 创建新的缓存管理器
    pub fn new(client: Client) -> Self {
        Self { client }
    }

    /// 缓存下载 URL。
    pub async fn cache_download_url(
        &self,
        cache_key: &str,
        download_url: &str,
        ttl_seconds: u64,
    ) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        conn.set_ex::<_, _, ()>(cache_key, download_url, ttl_seconds)
            .await?;
        Ok(())
    }

    /// 获取缓存的下载 URL。
    pub async fn get_cached_download_url(&self, cache_key: &str) -> RedisResult<Option<String>> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let url: Option<String> = conn.get(cache_key).await?;
        Ok(url)
    }
}
