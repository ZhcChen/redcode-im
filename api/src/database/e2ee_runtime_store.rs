use chrono::{DateTime, Utc};
use serde_json::Value as JsonValue;
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use crate::error::AppError;

#[derive(Debug, Clone, FromRow)]
pub struct E2eeRuntimeGateRecord {
    pub state: String,
    pub readiness_revision: i64,
    pub readiness_computed_at: Option<DateTime<Utc>>,
    pub min_client_versions: JsonValue,
    pub required_coverage_percent: i16,
    pub key_package_low_watermark: i32,
    pub security_review_approved: bool,
    pub updated_at: DateTime<Utc>,
    pub updated_by: Option<Uuid>,
}

#[derive(Debug, Clone, FromRow)]
pub struct DeviceCapabilityRecord {
    pub id: Uuid,
    pub user_id: Uuid,
    pub status: String,
    pub client_platform: Option<String>,
    pub client_version: Option<String>,
    pub client_build: Option<String>,
}

#[derive(Debug, Clone, FromRow)]
pub struct DeviceInventoryRecord {
    pub device_id: Uuid,
    pub available: i64,
}

pub struct E2eeRuntimeStore<'a> {
    pool: &'a PgPool,
}

impl<'a> E2eeRuntimeStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    pub async fn read_gate(&self) -> Result<E2eeRuntimeGateRecord, AppError> {
        sqlx::query_as::<_, E2eeRuntimeGateRecord>(
            "SELECT state, readiness_revision, readiness_computed_at,
                    min_client_versions, required_coverage_percent,
                    key_package_low_watermark, security_review_approved,
                    updated_at, updated_by
             FROM e2ee_runtime_gate
             WHERE id = 1",
        )
        .fetch_one(self.pool)
        .await
        .map_err(AppError::DatabaseError)
    }

    /// 原子写入门禁状态与 readiness revision；state 与 content_audit_mode
    /// 的一致性由调用方在同一事务外保证，这里只维护门禁单行。
    pub async fn update_gate(
        &self,
        state: &str,
        readiness_revision: i64,
        readiness_computed_at: Option<DateTime<Utc>>,
        updated_by: Option<Uuid>,
    ) -> Result<(), AppError> {
        sqlx::query(
            "UPDATE e2ee_runtime_gate
             SET state = $1, readiness_revision = $2, readiness_computed_at = $3,
                 updated_at = NOW(), updated_by = $4
             WHERE id = 1",
        )
        .bind(state)
        .bind(readiness_revision)
        .bind(readiness_computed_at)
        .bind(updated_by)
        .execute(self.pool)
        .await
        .map_err(AppError::DatabaseError)?;
        Ok(())
    }

    /// active 设备能力清单：无能力字段的存量设备也计入，readiness 判为不达标。
    pub async fn list_active_device_capabilities(
        &self,
    ) -> Result<Vec<DeviceCapabilityRecord>, AppError> {
        sqlx::query_as::<_, DeviceCapabilityRecord>(
            "SELECT id, user_id, status, client_platform, client_version, client_build
             FROM e2ee_devices
             WHERE status = 'active'
             ORDER BY created_at",
        )
        .fetch_all(self.pool)
        .await
        .map_err(AppError::DatabaseError)
    }

    pub async fn count_pending_approval_devices(&self) -> Result<i64, AppError> {
        sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM e2ee_devices WHERE status = 'pending_approval'",
        )
        .fetch_one(self.pool)
        .await
        .map_err(AppError::DatabaseError)
    }

    /// 每台 active 设备当前可用（未消费、未过期）KeyPackage 库存。
    pub async fn list_active_device_inventory(
        &self,
        low_watermark: i32,
    ) -> Result<Vec<DeviceInventoryRecord>, AppError> {
        sqlx::query_as::<_, DeviceInventoryRecord>(
            "SELECT device.id AS device_id,
                    COUNT(package.id) FILTER (
                        WHERE package.consumed_at IS NULL AND package.expires_at > NOW()
                    ) AS available
             FROM e2ee_devices AS device
             LEFT JOIN e2ee_key_packages AS package ON package.device_id = device.id
             WHERE device.status = 'active'
             GROUP BY device.id
             HAVING COUNT(package.id) FILTER (
                        WHERE package.consumed_at IS NULL AND package.expires_at > NOW()
                    ) < $1
             ORDER BY device.created_at",
        )
        .bind(low_watermark)
        .fetch_all(self.pool)
        .await
        .map_err(AppError::DatabaseError)
    }

    /// 记录一次 security review 批准（U7 前仅测试/审查流程显式调用，不提供
    /// 普通 Admin 自批端点）。
    pub async fn mark_security_review(
        &self,
        approved: bool,
        updated_by: Option<Uuid>,
    ) -> Result<(), AppError> {
        sqlx::query(
            "UPDATE e2ee_runtime_gate
             SET security_review_approved = $1, updated_at = NOW(), updated_by = $2
             WHERE id = 1",
        )
        .bind(approved)
        .bind(updated_by)
        .execute(self.pool)
        .await
        .map_err(AppError::DatabaseError)?;
        Ok(())
    }
}
