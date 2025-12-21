use async_trait::async_trait;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::AppError;

/// 日志条目
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogEntry {
    pub id: Option<Uuid>,
    pub level: String,
    pub target: String,
    pub message: String,
    pub fields: Option<serde_json::Value>,
    pub span_id: Option<String>,
    pub node_id: String,
    pub created_at: DateTime<Utc>,
}

impl LogEntry {
    pub fn new(
        level: String,
        target: String,
        message: String,
        fields: Option<serde_json::Value>,
        span_id: Option<String>,
        node_id: String,
    ) -> Self {
        Self {
            id: None,
            level,
            target,
            message,
            fields,
            span_id,
            node_id,
            created_at: Utc::now(),
        }
    }
}

/// 日志查询参数
#[derive(Debug, Clone, Default, Deserialize)]
pub struct LogQueryParams {
    pub level: Option<String>,
    pub target: Option<String>,
    pub keyword: Option<String>,
    pub start_time: Option<DateTime<Utc>>,
    pub end_time: Option<DateTime<Utc>>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// 日志查询结果
#[derive(Debug, Clone, Serialize)]
pub struct LogQueryResult {
    pub logs: Vec<LogEntry>,
    pub total: i64,
    pub limit: i64,
    pub offset: i64,
}

/// 日志存储 trait（可扩展，便于后续切换到 ELK 等系统）
#[async_trait]
pub trait LogStore: Send + Sync {
    /// 批量写入日志
    async fn write_batch(&self, entries: Vec<LogEntry>) -> Result<usize, AppError>;

    /// 删除过期日志
    async fn cleanup(&self, retention_days: i64) -> Result<u64, AppError>;

    /// 查询日志
    async fn query(&self, params: &LogQueryParams) -> Result<LogQueryResult, AppError>;

    /// 获取日志统计信息
    async fn stats(&self) -> Result<LogStats, AppError>;
}

/// 日志统计信息
#[derive(Debug, Clone, Serialize)]
pub struct LogStats {
    pub total_count: i64,
    pub debug_count: i64,
    pub info_count: i64,
    pub warn_count: i64,
    pub error_count: i64,
    pub oldest_log: Option<DateTime<Utc>>,
    pub newest_log: Option<DateTime<Utc>>,
}

/// PostgreSQL 日志存储实现
pub struct PostgresLogStore {
    pool: PgPool,
}

impl PostgresLogStore {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl LogStore for PostgresLogStore {
    async fn write_batch(&self, entries: Vec<LogEntry>) -> Result<usize, AppError> {
        if entries.is_empty() {
            return Ok(0);
        }

        let count = entries.len();

        // 使用批量 INSERT
        let mut query_builder = sqlx::QueryBuilder::new(
            "INSERT INTO system_logs (level, target, message, fields, span_id, node_id, created_at) ",
        );

        query_builder.push_values(entries.iter(), |mut b, entry| {
            b.push_bind(&entry.level)
                .push_bind(&entry.target)
                .push_bind(&entry.message)
                .push_bind(&entry.fields)
                .push_bind(&entry.span_id)
                .push_bind(&entry.node_id)
                .push_bind(entry.created_at);
        });

        query_builder
            .build()
            .execute(&self.pool)
            .await
            .map_err(AppError::DatabaseError)?;

        Ok(count)
    }

    async fn cleanup(&self, retention_days: i64) -> Result<u64, AppError> {
        let result = sqlx::query(
            r#"
            DELETE FROM system_logs
            WHERE created_at < NOW() - make_interval(days => $1)
            "#,
        )
        .bind(retention_days as i32)
        .execute(&self.pool)
        .await
        .map_err(AppError::DatabaseError)?;

        Ok(result.rows_affected())
    }

    async fn query(&self, params: &LogQueryParams) -> Result<LogQueryResult, AppError> {
        let limit = params.limit.unwrap_or(50).min(500);
        let offset = params.offset.unwrap_or(0);

        // 构建查询条件
        let mut conditions = vec!["1=1".to_string()];
        let mut bind_idx = 1;

        if params.level.is_some() {
            conditions.push(format!("level = ${}", bind_idx));
            bind_idx += 1;
        }

        if params.target.is_some() {
            conditions.push(format!("target ILIKE ${}", bind_idx));
            bind_idx += 1;
        }

        if params.keyword.is_some() {
            conditions.push(format!("message ILIKE ${}", bind_idx));
            bind_idx += 1;
        }

        if params.start_time.is_some() {
            conditions.push(format!("created_at >= ${}", bind_idx));
            bind_idx += 1;
        }

        if params.end_time.is_some() {
            conditions.push(format!("created_at <= ${}", bind_idx));
            bind_idx += 1;
        }

        let where_clause = conditions.join(" AND ");

        // 查询总数
        let count_query = format!(
            "SELECT COUNT(*) as count FROM system_logs WHERE {}",
            where_clause
        );

        let mut count_builder = sqlx::query_scalar::<_, i64>(&count_query);

        if let Some(ref level) = params.level {
            count_builder = count_builder.bind(level);
        }
        if let Some(ref target) = params.target {
            count_builder = count_builder.bind(format!("%{}%", target));
        }
        if let Some(ref keyword) = params.keyword {
            count_builder = count_builder.bind(format!("%{}%", keyword));
        }
        if let Some(start_time) = params.start_time {
            count_builder = count_builder.bind(start_time);
        }
        if let Some(end_time) = params.end_time {
            count_builder = count_builder.bind(end_time);
        }

        let total = count_builder
            .fetch_one(&self.pool)
            .await
            .map_err(AppError::DatabaseError)?;

        // 查询日志数据
        let data_query = format!(
            r#"
            SELECT id, level, target, message, fields, span_id, node_id, created_at
            FROM system_logs
            WHERE {}
            ORDER BY created_at DESC
            LIMIT ${} OFFSET ${}
            "#,
            where_clause, bind_idx, bind_idx + 1
        );

        let mut data_builder = sqlx::query_as::<_, (Uuid, String, String, String, Option<serde_json::Value>, Option<String>, String, DateTime<Utc>)>(&data_query);

        if let Some(ref level) = params.level {
            data_builder = data_builder.bind(level);
        }
        if let Some(ref target) = params.target {
            data_builder = data_builder.bind(format!("%{}%", target));
        }
        if let Some(ref keyword) = params.keyword {
            data_builder = data_builder.bind(format!("%{}%", keyword));
        }
        if let Some(start_time) = params.start_time {
            data_builder = data_builder.bind(start_time);
        }
        if let Some(end_time) = params.end_time {
            data_builder = data_builder.bind(end_time);
        }

        let rows = data_builder
            .bind(limit)
            .bind(offset)
            .fetch_all(&self.pool)
            .await
            .map_err(AppError::DatabaseError)?;

        let logs = rows
            .into_iter()
            .map(|(id, level, target, message, fields, span_id, node_id, created_at)| LogEntry {
                id: Some(id),
                level,
                target,
                message,
                fields,
                span_id,
                node_id,
                created_at,
            })
            .collect();

        Ok(LogQueryResult {
            logs,
            total,
            limit,
            offset,
        })
    }

    async fn stats(&self) -> Result<LogStats, AppError> {
        let row = sqlx::query_as::<_, (i64, i64, i64, i64, i64, Option<DateTime<Utc>>, Option<DateTime<Utc>>)>(
            r#"
            SELECT
                COUNT(*) as total_count,
                COUNT(*) FILTER (WHERE level = 'DEBUG') as debug_count,
                COUNT(*) FILTER (WHERE level = 'INFO') as info_count,
                COUNT(*) FILTER (WHERE level = 'WARN') as warn_count,
                COUNT(*) FILTER (WHERE level = 'ERROR') as error_count,
                MIN(created_at) as oldest_log,
                MAX(created_at) as newest_log
            FROM system_logs
            "#,
        )
        .fetch_one(&self.pool)
        .await
        .map_err(AppError::DatabaseError)?;

        Ok(LogStats {
            total_count: row.0,
            debug_count: row.1,
            info_count: row.2,
            warn_count: row.3,
            error_count: row.4,
            oldest_log: row.5,
            newest_log: row.6,
        })
    }
}
