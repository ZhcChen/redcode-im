use redis::{AsyncCommands, Client, RedisResult};
use serde_json;
use tracing::{error, info, warn};
use uuid::Uuid;

use crate::database::models::{Room, User};
use crate::redis::models::{CacheKeys, RoomMemberCache, UserOnlineStatus};

/// Redis 缓存管理器
#[allow(dead_code)]
pub struct CacheManager {
    client: Client,
    default_ttl: u64, // 默认过期时间（秒）
}

#[allow(dead_code)]
impl CacheManager {
    /// 创建新的缓存管理器
    pub fn new(client: Client) -> Self {
        Self {
            client,
            default_ttl: 3600, // 默认1小时过期
        }
    }

    /// 设置默认 TTL
    pub fn set_default_ttl(&mut self, ttl_seconds: u64) {
        self.default_ttl = ttl_seconds;
    }

    /// 缓存用户信息
    pub async fn cache_user(&self, user: &User) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = CacheKeys::user_cache(&user.id);

        let user_json = serde_json::to_string(user).map_err(|e| {
            redis::RedisError::from((redis::ErrorKind::TypeError, "JSON序列化失败", e.to_string()))
        })?;

        conn.set_ex::<_, _, ()>(&key, &user_json, self.default_ttl)
            .await?;

        info!("缓存用户信息: {}", user.username);
        Ok(())
    }

    /// 获取缓存的用户信息
    pub async fn get_cached_user(&self, user_id: &Uuid) -> RedisResult<Option<User>> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = CacheKeys::user_cache(user_id);

        let user_json: Option<String> = conn.get(&key).await?;

        match user_json {
            Some(json) => match serde_json::from_str::<User>(&json) {
                Ok(user) => {
                    info!("命中用户缓存: {}", user.username);
                    Ok(Some(user))
                }
                Err(e) => {
                    error!("解析缓存用户数据失败: {:?}", e);
                    Ok(None)
                }
            },
            None => {
                info!("用户缓存未命中: {}", user_id);
                Ok(None)
            }
        }
    }

    /// 删除用户缓存
    pub async fn delete_user_cache(&self, user_id: &Uuid) -> RedisResult<bool> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = CacheKeys::user_cache(user_id);

        let deleted: i32 = conn.del(&key).await?;
        let result = deleted > 0;

        if result {
            info!("删除用户缓存: {}", user_id);
        }

        Ok(result)
    }

    /// 缓存房间信息
    pub async fn cache_room(&self, room: &Room) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = CacheKeys::room_cache(&room.id);

        let room_json = serde_json::to_string(room).map_err(|e| {
            redis::RedisError::from((redis::ErrorKind::TypeError, "JSON序列化失败", e.to_string()))
        })?;

        conn.set_ex::<_, _, ()>(&key, &room_json, self.default_ttl)
            .await?;

        info!("缓存房间信息: {}", room.name);
        Ok(())
    }

    /// 获取缓存的房间信息
    pub async fn get_cached_room(&self, room_id: &Uuid) -> RedisResult<Option<Room>> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = CacheKeys::room_cache(room_id);

        let room_json: Option<String> = conn.get(&key).await?;

        match room_json {
            Some(json) => match serde_json::from_str::<Room>(&json) {
                Ok(room) => {
                    info!("命中房间缓存: {}", room.name);
                    Ok(Some(room))
                }
                Err(e) => {
                    error!("解析缓存房间数据失败: {:?}", e);
                    Ok(None)
                }
            },
            None => {
                info!("房间缓存未命中: {}", room_id);
                Ok(None)
            }
        }
    }

    /// 缓存房间成员列表
    pub async fn cache_room_members(
        &self,
        room_id: &Uuid,
        members: &[RoomMemberCache],
    ) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = CacheKeys::room_members(room_id);

        // 先清除现有的成员列表
        conn.del::<_, ()>(&key).await?;

        // 批量添加成员信息
        for member in members {
            let member_json = serde_json::to_string(member).map_err(|e| {
                redis::RedisError::from((
                    redis::ErrorKind::TypeError,
                    "JSON序列化失败",
                    e.to_string(),
                ))
            })?;

            conn.sadd::<_, _, ()>(&key, &member_json).await?;
        }

        // 设置过期时间
        conn.expire::<_, ()>(&key, self.default_ttl.try_into().unwrap())
            .await?;

        info!("缓存房间成员列表: {} -> {} 个成员", room_id, members.len());
        Ok(())
    }

    /// 获取缓存的房间成员列表
    pub async fn get_cached_room_members(
        &self,
        room_id: &Uuid,
    ) -> RedisResult<Vec<RoomMemberCache>> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = CacheKeys::room_members(room_id);

        let members_json: Vec<String> = conn.smembers(&key).await?;

        let mut members = Vec::new();
        for member_json in members_json {
            if let Ok(member) = serde_json::from_str::<RoomMemberCache>(&member_json) {
                members.push(member);
            }
        }

        info!("命中房间成员缓存: {} -> {} 个成员", room_id, members.len());
        Ok(members)
    }

    /// 添加房间成员到缓存
    pub async fn add_room_member_to_cache(
        &self,
        room_id: &Uuid,
        member: &RoomMemberCache,
    ) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = CacheKeys::room_members(room_id);

        let member_json = serde_json::to_string(member).map_err(|e| {
            redis::RedisError::from((redis::ErrorKind::TypeError, "JSON序列化失败", e.to_string()))
        })?;

        conn.sadd::<_, _, ()>(&key, &member_json).await?;
        conn.expire::<_, ()>(&key, self.default_ttl.try_into().unwrap())
            .await?;

        info!("添加房间成员到缓存: {} -> {}", room_id, member.username);
        Ok(())
    }

    /// 从缓存中移除房间成员
    pub async fn remove_room_member_from_cache(
        &self,
        room_id: &Uuid,
        user_id: &Uuid,
    ) -> RedisResult<bool> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = CacheKeys::room_members(room_id);

        // 获取当前成员列表
        let members_json: Vec<String> = conn.smembers(&key).await?;

        for member_json in members_json {
            if let Ok(member) = serde_json::from_str::<RoomMemberCache>(&member_json) {
                if member.user_id == *user_id {
                    conn.srem::<_, _, ()>(&key, &member_json).await?;
                    info!("从房间成员缓存中移除: {} -> {}", room_id, user_id);
                    return Ok(true);
                }
            }
        }

        Ok(false)
    }

    /// 缓存用户在线状态
    pub async fn cache_user_online_status(&self, status: &UserOnlineStatus) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = CacheKeys::user_online_status(&status.user_id);

        let status_json = serde_json::to_string(status).map_err(|e| {
            redis::RedisError::from((redis::ErrorKind::TypeError, "JSON序列化失败", e.to_string()))
        })?;

        conn.set_ex::<_, _, ()>(&key, &status_json, self.default_ttl)
            .await?;

        info!(
            "缓存用户在线状态: {} -> {}",
            status.username, status.is_online
        );
        Ok(())
    }

    /// 获取用户在线状态
    pub async fn get_user_online_status(
        &self,
        user_id: &Uuid,
    ) -> RedisResult<Option<UserOnlineStatus>> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = CacheKeys::user_online_status(user_id);

        let status_json: Option<String> = conn.get(&key).await?;

        match status_json {
            Some(json) => match serde_json::from_str::<UserOnlineStatus>(&json) {
                Ok(status) => {
                    info!(
                        "命中用户在线状态缓存: {} -> {}",
                        status.username, status.is_online
                    );
                    Ok(Some(status))
                }
                Err(e) => {
                    error!("解析用户在线状态缓存失败: {:?}", e);
                    Ok(None)
                }
            },
            None => {
                info!("用户在线状态缓存未命中: {}", user_id);
                Ok(None)
            }
        }
    }

    /// 设置用户离线状态
    pub async fn set_user_offline(&self, user_id: &Uuid) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let key = CacheKeys::user_online_status(user_id);

        conn.del::<_, ()>(&key).await?;

        info!("设置用户离线: {}", user_id);
        Ok(())
    }

    /// 通用缓存设置
    pub async fn set<T: serde::Serialize>(
        &self,
        key: &str,
        value: &T,
        ttl_seconds: Option<u64>,
    ) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;

        let value_json = serde_json::to_string(value).map_err(|e| {
            redis::RedisError::from((redis::ErrorKind::TypeError, "JSON序列化失败", e.to_string()))
        })?;

        let ttl = ttl_seconds.unwrap_or(self.default_ttl);
        conn.set_ex::<_, _, ()>(key, &value_json, ttl).await?;

        Ok(())
    }

    /// 通用缓存获取
    pub async fn get<T: serde::de::DeserializeOwned>(&self, key: &str) -> RedisResult<Option<T>> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;

        let value_json: Option<String> = conn.get(key).await?;

        match value_json {
            Some(json) => match serde_json::from_str::<T>(&json) {
                Ok(value) => Ok(Some(value)),
                Err(e) => {
                    error!("解析缓存数据失败 [{}]: {:?}", key, e);
                    Ok(None)
                }
            },
            None => Ok(None),
        }
    }

    /// 删除缓存
    pub async fn delete(&self, key: &str) -> RedisResult<bool> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let deleted: i32 = conn.del(key).await?;
        Ok(deleted > 0)
    }

    /// 检查缓存是否存在
    pub async fn exists(&self, key: &str) -> RedisResult<bool> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let exists: bool = conn.exists(key).await?;
        Ok(exists)
    }

    /// 设置缓存过期时间
    pub async fn expire(&self, key: &str, ttl_seconds: u64) -> RedisResult<bool> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let result: bool = conn.expire(key, ttl_seconds.try_into().unwrap()).await?;
        Ok(result)
    }

    /// 获取缓存剩余过期时间
    pub async fn ttl(&self, key: &str) -> RedisResult<i64> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let ttl: i64 = conn.ttl(key).await?;
        Ok(ttl)
    }

    /// 批量删除缓存
    pub async fn delete_multiple(&self, keys: &[&str]) -> RedisResult<i32> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let deleted: i32 = conn.del(keys).await?;
        Ok(deleted)
    }

    /// 清空所有缓存（危险操作）
    pub async fn flush_all(&self) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let _: () = redis::cmd("FLUSHALL").query_async(&mut conn).await?;
        warn!("清空所有 Redis 缓存");
        Ok(())
    }

    /// 缓存下载URL
    /// ttl_seconds: 缓存过期时间，建议设置为URL有效期的90%
    pub async fn cache_download_url(
        &self,
        cache_key: &str,
        download_url: &str,
        ttl_seconds: u64,
    ) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        conn.set_ex::<_, _, ()>(cache_key, download_url, ttl_seconds).await?;
        Ok(())
    }

    /// 获取缓存的下载URL
    pub async fn get_cached_download_url(&self, cache_key: &str) -> RedisResult<Option<String>> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let url: Option<String> = conn.get(cache_key).await?;
        Ok(url)
    }
}
