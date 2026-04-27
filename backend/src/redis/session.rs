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

    /// 创建用户会话
    pub async fn create_session(
        &self,
        user_id: Uuid,
        socket_id: String,
        client_ip: std::net::IpAddr,
        rooms: Vec<Uuid>,
    ) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;

        let session_info = SessionInfo {
            user_id,
            node_id: self.node_id.clone(),
            socket_id: socket_id.clone(),
            rooms,
            last_heartbeat: Utc::now(),
            client_ip,
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

    /// 更新会话心跳和 IP。
    pub async fn update_session_heartbeat_with_ip(
        &self,
        user_id: &Uuid,
        client_ip: std::net::IpAddr,
    ) -> RedisResult<bool> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let session_key = CacheKeys::user_session(user_id);

        // 获取现有会话信息
        if let Some(mut session) = self.get_user_session(user_id).await? {
            session.last_heartbeat = Utc::now();
            session.client_ip = client_ip;

            let session_json = serde_json::to_string(&session).map_err(|e| {
                redis::RedisError::from((
                    redis::ErrorKind::TypeError,
                    "JSON序列化失败",
                    e.to_string(),
                ))
            })?;

            conn.set_ex::<_, _, ()>(&session_key, &session_json, self.session_ttl)
                .await?;
            info!("更新会话心跳和IP: {} ({})", user_id, client_ip);
            Ok(true)
        } else {
            warn!("尝试更新不存在的会话: {}", user_id);
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
        cpu_usage: f64,
        memory_usage: f64,
        disk_usage: f64,
        cpu_count: u32,
        total_memory: u64,
    ) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;

        let heartbeat = NodeHeartbeat {
            node_id: self.node_id.clone(),
            address,
            status: crate::redis::models::NodeStatus::Active,
            connected_users,
            active_rooms,
            cpu_usage,
            memory_usage,
            disk_usage,
            cpu_count,
            total_memory,
            last_heartbeat: Utc::now(),
            started_at: Utc::now(), // 这里应该从实际启动时间获取
        };

        let heartbeat_key = CacheKeys::node_heartbeat(&self.node_id);
        let heartbeat_json = serde_json::to_string(&heartbeat).map_err(|e| {
            redis::RedisError::from((redis::ErrorKind::TypeError, "JSON序列化失败", e.to_string()))
        })?;

        conn.set_ex::<_, _, ()>(&heartbeat_key, &heartbeat_json, 15)
            .await?; // 15s过期

        // 添加到活跃节点列表
        let active_nodes_key = CacheKeys::active_nodes();
        conn.sadd::<_, _, ()>(&active_nodes_key, &self.node_id)
            .await?;
        conn.expire::<_, ()>(&active_nodes_key, 15).await?;

        info!(
            "注册节点心跳: {} (用户: {}, 房间: {})",
            self.node_id, connected_users, active_rooms
        );
        Ok(())
    }

    /// 获取所有活跃节点。
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
            } else {
                // 节点已下线，从集合中移除
                let _: () = conn.srem(&active_nodes_key, &node_id).await?;
            }
        }

        Ok(nodes)
    }

    /// 记录 API 性能指标
    pub async fn record_api_metric(
        &self,
        method: &str,
        path: &str,
        duration_ms: u64,
        _status: u16,
    ) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let field = format!("{}:{}", method, path);

        // 1. 增加命中次数
        let hits_key = CacheKeys::api_metrics_hits();
        redis::pipe()
            .hincr(&hits_key, &field, 1)
            // 2. 增加总耗时
            .hincr(&CacheKeys::api_metrics_duration(), &field, duration_ms)
            // 3. 更新慢日志排行 (ZSet 记录最大耗时)
            .zadd(&CacheKeys::api_metrics_slow_log(), &field, duration_ms)
            .query_async::<()>(&mut conn)
            .await?;

        // 限制慢日志数量为 Top 100
        conn.zremrangebyrank::<_, ()>(&CacheKeys::api_metrics_slow_log(), 0, -101)
            .await?;

        Ok(())
    }

    /// 获取 API 性能统计（分页）
    pub async fn get_api_performance_stats_paginated(
        &self,
        page: usize,
        page_size: usize,
    ) -> RedisResult<(Vec<serde_json::Value>, usize)> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;

        let hits_key = CacheKeys::api_metrics_hits();
        let duration_key = CacheKeys::api_metrics_duration();
        let slow_key = CacheKeys::api_metrics_slow_log();

        let hits: HashMap<String, u64> = conn.hgetall(&hits_key).await?;
        let durations: HashMap<String, u64> = conn.hgetall(&duration_key).await?;
        // 慢日志排行仍然取 Top 10 来辅助显示 Max Duration
        let slow_logs: Vec<(String, u64)> = conn.zrevrange_withscores(&slow_key, 0, 99).await?;

        let mut all_results = Vec::new();
        for (field, count) in hits {
            let total_dur = durations.get(&field).cloned().unwrap_or(0);
            let avg_dur = if count > 0 { total_dur / count } else { 0 };

            let parts: Vec<&str> = field.splitn(2, ':').collect();
            let (method, path) = if parts.len() == 2 {
                (parts[0], parts[1])
            } else {
                ("UNKNOWN", field.as_str())
            };

            all_results.push(serde_json::json!({
                "method": method,
                "path": path,
                "count": count,
                "avg_duration": avg_dur,
                "max_duration": slow_logs.iter().find(|(f, _)| f == &field).map(|(_, s)| *s).unwrap_or(0)
            }));
        }

        // 按调用次数排序
        all_results.sort_by(|a, b| b["count"].as_u64().cmp(&a["count"].as_u64()));

        let total = all_results.len();
        let start = (page - 1) * page_size;
        let end = (start + page_size).min(total);

        let paginated_results = if start < total {
            all_results[start..end].to_vec()
        } else {
            Vec::new()
        };

        Ok((paginated_results, total))
    }

    /// 获取 API 性能统计（原始版本，用于图表）
    pub async fn get_api_performance_stats(&self) -> RedisResult<Vec<serde_json::Value>> {
        let (data, _) = self.get_api_performance_stats_paginated(1, 1000).await?;
        Ok(data)
    }
}
