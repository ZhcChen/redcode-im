use chrono::Utc;
use redis::{AsyncCommands, Client, RedisResult};
use serde_json;
use std::collections::HashMap;
use tracing::{error, info, warn};
use uuid::Uuid;

use crate::redis::models::{CacheKeys, NodeHeartbeat, SessionInfo};

/// Redis 会话管理器
pub struct SessionManager {
    client: Client,
    node_id: String,
    #[allow(dead_code)]
    session_ttl: u64, // 会话过期时间（秒）
}

impl SessionManager {
    /// 创建新的会话管理器
    pub fn new(client: Client, node_id: String) -> Self {
        Self {
            client,
            node_id,
            session_ttl: 86400, // 默认24小时过期
        }
    }

    /// 设置会话过期时间
    #[allow(dead_code)]
    pub fn set_session_ttl(&mut self, ttl_seconds: u64) {
        self.session_ttl = ttl_seconds;
    }

    /// 创建用户会话
    #[allow(dead_code)] // 保留用于将来可能的功能
    pub async fn create_session(
        &self,
        user_id: Uuid,
        socket_id: String,
        rooms: Vec<Uuid>,
    ) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;

        let session_info = SessionInfo {
            user_id,
            node_id: self.node_id.clone(),
            socket_id: socket_id.clone(),
            rooms,
            last_heartbeat: Utc::now(),
            created_at: Utc::now(),
        };

        // 缓存用户会话信息
        let session_key = CacheKeys::user_session(&user_id);
        let session_json = serde_json::to_string(&session_info).map_err(|e| {
            redis::RedisError::from((redis::ErrorKind::TypeError, "JSON序列化失败", e.to_string()))
        })?;

        conn.set_ex::<_, _, ()>(&session_key, &session_json, self.session_ttl)
            .await?;

        // 添加到节点会话列表
        let node_sessions_key = CacheKeys::node_sessions(&self.node_id);
        conn.sadd::<_, _, ()>(&node_sessions_key, &user_id.to_string())
            .await?;
        conn.expire::<_, ()>(&node_sessions_key, self.session_ttl.try_into().unwrap())
            .await?;

        info!(
            "创建用户会话: {} -> {}@{}",
            user_id, self.node_id, socket_id
        );
        Ok(())
    }

    /// 获取用户会话信息
    pub async fn get_user_session(&self, user_id: &Uuid) -> RedisResult<Option<SessionInfo>> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let session_key = CacheKeys::user_session(user_id);

        let session_json: Option<String> = conn.get(&session_key).await?;

        match session_json {
            Some(json) => match serde_json::from_str::<SessionInfo>(&json) {
                Ok(session) => {
                    info!(
                        "获取用户会话: {} -> {}@{}",
                        user_id, session.node_id, session.socket_id
                    );
                    Ok(Some(session))
                }
                Err(e) => {
                    error!("解析用户会话失败: {:?}", e);
                    Ok(None)
                }
            },
            None => {
                info!("用户会话不存在: {}", user_id);
                Ok(None)
            }
        }
    }

    /// 更新会话心跳
    #[allow(dead_code)]
    pub async fn update_session_heartbeat(&self, user_id: &Uuid) -> RedisResult<bool> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let session_key = CacheKeys::user_session(user_id);

        // 获取现有会话信息
        if let Some(mut session) = self.get_user_session(user_id).await? {
            session.last_heartbeat = Utc::now();

            let session_json = serde_json::to_string(&session).map_err(|e| {
                redis::RedisError::from((
                    redis::ErrorKind::TypeError,
                    "JSON序列化失败",
                    e.to_string(),
                ))
            })?;

            conn.set_ex::<_, _, ()>(&session_key, &session_json, self.session_ttl)
                .await?;
            info!("更新会话心跳: {}", user_id);
            Ok(true)
        } else {
            warn!("尝试更新不存在的会话: {}", user_id);
            Ok(false)
        }
    }

    /// 更新用户房间列表
    #[allow(dead_code)]
    pub async fn update_user_rooms(&self, user_id: &Uuid, rooms: Vec<Uuid>) -> RedisResult<bool> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let session_key = CacheKeys::user_session(user_id);

        // 获取现有会话信息
        if let Some(mut session) = self.get_user_session(user_id).await? {
            session.rooms = rooms;

            let session_json = serde_json::to_string(&session).map_err(|e| {
                redis::RedisError::from((
                    redis::ErrorKind::TypeError,
                    "JSON序列化失败",
                    e.to_string(),
                ))
            })?;

            conn.set_ex::<_, _, ()>(&session_key, &session_json, self.session_ttl)
                .await?;
            info!("更新用户房间列表: {}", user_id);
            Ok(true)
        } else {
            warn!("尝试更新不存在会话的房间列表: {}", user_id);
            Ok(false)
        }
    }

    /// 删除用户会话
    pub async fn delete_user_session(&self, user_id: &Uuid) -> RedisResult<bool> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;

        // 获取会话信息（用于确定节点ID）
        let session_info = self.get_user_session(user_id).await?;

        // 删除用户会话缓存
        let session_key = CacheKeys::user_session(user_id);
        let deleted: i32 = conn.del(&session_key).await?;

        if deleted > 0 {
            // 从原节点会话列表中移除
            if let Some(session) = session_info {
                let node_sessions_key = CacheKeys::node_sessions(&session.node_id);
                conn.srem::<_, _, ()>(&node_sessions_key, &user_id.to_string())
                    .await?;
            }

            info!("删除用户会话: {}", user_id);
            Ok(true)
        } else {
            info!("用户会话不存在，无需删除: {}", user_id);
            Ok(false)
        }
    }

    /// 获取节点的所有会话
    pub async fn get_node_sessions(&self, node_id: &str) -> RedisResult<Vec<Uuid>> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let node_sessions_key = CacheKeys::node_sessions(node_id);

        let user_ids: Vec<String> = conn.smembers(&node_sessions_key).await?;

        let mut sessions = Vec::new();
        for user_id_str in user_ids {
            if let Ok(user_id) = Uuid::parse_str(&user_id_str) {
                sessions.push(user_id);
            }
        }

        info!("获取节点会话: {} -> {} 个会话", node_id, sessions.len());
        Ok(sessions)
    }

    /// 获取当前节点的会话
    pub async fn get_current_node_sessions(&self) -> RedisResult<Vec<SessionInfo>> {
        let user_ids = self.get_node_sessions(&self.node_id).await?;

        let mut sessions = Vec::new();
        for user_id in user_ids {
            if let Some(session) = self.get_user_session(&user_id).await? {
                sessions.push(session);
            }
        }

        info!(
            "获取当前节点会话: {} -> {} 个会话",
            self.node_id,
            sessions.len()
        );
        Ok(sessions)
    }

    /// 清理过期的会话
    pub async fn cleanup_expired_sessions(&self) -> RedisResult<usize> {
        let sessions = self.get_current_node_sessions().await?;
        let mut cleaned_count = 0;

        for session in sessions {
            let now = Utc::now();
            let heartbeat_age = now.signed_duration_since(session.last_heartbeat);

            // 如果超过5分钟没有心跳，删除会话
            if heartbeat_age.num_minutes() > 5 {
                warn!(
                    "清理过期会话: {} (最后心跳: {:?})",
                    session.user_id, session.last_heartbeat
                );
                self.delete_user_session(&session.user_id).await?;
                cleaned_count += 1;
            }
        }

        if cleaned_count > 0 {
            info!("清理过期会话完成: {} 个会话被清理", cleaned_count);
        }

        Ok(cleaned_count)
    }

    /// 注册节点心跳
    pub async fn register_node_heartbeat(
        &self,
        address: String,
        connected_users: usize,
        active_rooms: usize,
    ) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;

        let heartbeat = NodeHeartbeat {
            node_id: self.node_id.clone(),
            address,
            status: crate::redis::models::NodeStatus::Active,
            connected_users,
            active_rooms,
            last_heartbeat: Utc::now(),
            started_at: Utc::now(), // 这里应该从实际启动时间获取
        };

        let heartbeat_key = CacheKeys::node_heartbeat(&self.node_id);
        let heartbeat_json = serde_json::to_string(&heartbeat).map_err(|e| {
            redis::RedisError::from((redis::ErrorKind::TypeError, "JSON序列化失败", e.to_string()))
        })?;

        conn.set_ex::<_, _, ()>(&heartbeat_key, &heartbeat_json, 300)
            .await?; // 5分钟过期

        // 添加到活跃节点列表
        let active_nodes_key = CacheKeys::active_nodes();
        conn.sadd::<_, _, ()>(&active_nodes_key, &self.node_id)
            .await?;
        conn.expire::<_, ()>(&active_nodes_key, 300).await?;

        info!(
            "注册节点心跳: {} (用户: {}, 房间: {})",
            self.node_id, connected_users, active_rooms
        );
        Ok(())
    }

    /// 获取所有活跃节点
    #[allow(dead_code)]
    pub async fn get_active_nodes(&self) -> RedisResult<Vec<NodeHeartbeat>> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let active_nodes_key = CacheKeys::active_nodes();

        let node_ids: Vec<String> = conn.smembers(&active_nodes_key).await?;

        let mut nodes = Vec::new();
        for node_id in node_ids {
            let heartbeat_key = CacheKeys::node_heartbeat(&node_id);
            if let Some(heartbeat_json) = conn.get::<_, Option<String>>(&heartbeat_key).await? {
                if let Ok(heartbeat) = serde_json::from_str::<NodeHeartbeat>(&heartbeat_json) {
                    nodes.push(heartbeat);
                }
            }
        }

        Ok(nodes)
    }

    /// 检查节点是否活跃
    #[allow(dead_code)]
    pub async fn is_node_active(&self, node_id: &str) -> RedisResult<bool> {
        let heartbeat_key = CacheKeys::node_heartbeat(node_id);
        let mut conn = self.client.get_multiplexed_async_connection().await?;

        let exists: bool = conn.exists(&heartbeat_key).await?;
        Ok(exists)
    }

    /// 迁移用户会话到新节点
    #[allow(dead_code)]
    pub async fn migrate_user_session(
        &self,
        user_id: &Uuid,
        new_node_id: &str,
        new_socket_id: String,
    ) -> RedisResult<bool> {
        if let Some(mut session) = self.get_user_session(user_id).await? {
            // 更新节点信息
            session.node_id = new_node_id.to_string();
            session.socket_id = new_socket_id;
            session.last_heartbeat = Utc::now();

            // 保存更新的会话信息
            let mut conn = self.client.get_multiplexed_async_connection().await?;
            let session_key = CacheKeys::user_session(user_id);
            let session_json = serde_json::to_string(&session).map_err(|e| {
                redis::RedisError::from((
                    redis::ErrorKind::TypeError,
                    "JSON序列化失败",
                    e.to_string(),
                ))
            })?;

            conn.set_ex::<_, _, ()>(&session_key, &session_json, self.session_ttl)
                .await?;

            // 从旧节点会话列表移除
            let old_node_sessions_key = CacheKeys::node_sessions(&self.node_id);
            conn.srem::<_, _, ()>(&old_node_sessions_key, &user_id.to_string())
                .await?;

            // 添加到新节点会话列表
            let new_node_sessions_key = CacheKeys::node_sessions(new_node_id);
            conn.sadd::<_, _, ()>(&new_node_sessions_key, &user_id.to_string())
                .await?;
            conn.expire::<_, ()>(&new_node_sessions_key, self.session_ttl.try_into().unwrap())
                .await?;

            info!(
                "迁移用户会话: {} -> {}@{}",
                user_id, new_node_id, session.socket_id
            );
            Ok(true)
        } else {
            warn!("尝试迁移不存在的会话: {}", user_id);
            Ok(false)
        }
    }

    /// 获取会话统计信息
    #[allow(dead_code)]
    pub async fn get_session_stats(&self) -> RedisResult<HashMap<String, usize>> {
        let mut stats = HashMap::new();

        // 当前节点会话数
        let current_sessions = self.get_current_node_sessions().await?;
        stats.insert("current_node_sessions".to_string(), current_sessions.len());

        // 活跃节点数
        let active_nodes = self.get_active_nodes().await?;
        stats.insert("active_nodes".to_string(), active_nodes.len());

        // 总连接用户数
        let total_users: usize = active_nodes.iter().map(|n| n.connected_users).sum();
        stats.insert("total_connected_users".to_string(), total_users);

        // 总活跃房间数
        let total_rooms: usize = active_nodes.iter().map(|n| n.active_rooms).sum();
        stats.insert("total_active_rooms".to_string(), total_rooms);

        Ok(stats)
    }
}
