use chrono::{DateTime, Utc};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use crate::error::AppError;

#[derive(Debug, Clone)]
pub struct RegisterDeviceInput {
    pub device_id: Uuid,
    pub device_label: String,
    pub root_public_key: Vec<u8>,
    pub root_fingerprint: Vec<u8>,
    pub credential: Vec<u8>,
    pub credential_fingerprint: Vec<u8>,
    pub protocol_version: i16,
}

#[derive(Debug, Clone, FromRow)]
pub struct E2eeDeviceRecord {
    pub id: Uuid,
    pub user_id: Uuid,
    pub device_label: String,
    pub protocol_version: i16,
    pub status: String,
    pub approved_by_device_id: Option<Uuid>,
    pub approved_at: Option<DateTime<Utc>>,
    pub revoked_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone)]
pub struct NewKeyPackage {
    pub id: Uuid,
    pub package_ref: Vec<u8>,
    pub key_package: Vec<u8>,
    pub protocol_version: i16,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Clone, FromRow)]
pub struct ClaimedKeyPackage {
    pub id: Uuid,
    pub device_id: Uuid,
    pub package_ref: Vec<u8>,
    pub key_package: Vec<u8>,
    pub protocol_version: i16,
    pub expires_at: DateTime<Utc>,
    pub consumed_at: DateTime<Utc>,
    pub consumed_by_device_id: Uuid,
}

pub struct E2eeMlsStore<'a> {
    pool: &'a PgPool,
}

impl<'a> E2eeMlsStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    pub async fn register_device(
        &self,
        user_id: Uuid,
        input: RegisterDeviceInput,
    ) -> Result<E2eeDeviceRecord, AppError> {
        let mut tx = self.pool.begin().await.map_err(AppError::DatabaseError)?;
        sqlx::query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))")
            .bind(user_id.to_string())
            .execute(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)?;

        let identity = sqlx::query_as::<_, (Vec<u8>, Vec<u8>, i16)>(
            "SELECT root_public_key, root_fingerprint, protocol_version
             FROM e2ee_account_identities
             WHERE user_id = $1",
        )
        .bind(user_id)
        .fetch_optional(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;

        let first_device = identity.is_none();
        if let Some((root_public_key, root_fingerprint, protocol_version)) = identity {
            if root_public_key != input.root_public_key
                || root_fingerprint != input.root_fingerprint
                || protocol_version != input.protocol_version
            {
                return Err(AppError::MessageRuntimeConflict(
                    "账号根身份与已登记身份不一致".to_string(),
                ));
            }
        } else {
            sqlx::query(
                "INSERT INTO e2ee_account_identities (
                    user_id, root_public_key, root_fingerprint, protocol_version
                 ) VALUES ($1, $2, $3, $4)",
            )
            .bind(user_id)
            .bind(&input.root_public_key)
            .bind(&input.root_fingerprint)
            .bind(input.protocol_version)
            .execute(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)?;
        }

        let existing = sqlx::query_as::<_, (Uuid, String, Vec<u8>, Vec<u8>, i16)>(
            "SELECT user_id, device_label, credential, credential_fingerprint, protocol_version
             FROM e2ee_devices WHERE id = $1",
        )
        .bind(input.device_id)
        .fetch_optional(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;
        if let Some((owner_id, label, credential, fingerprint, protocol_version)) = existing {
            if owner_id != user_id {
                return Err(AppError::AlreadyExists(
                    "device_id 已被其他账号使用".to_string(),
                ));
            }
            if label != input.device_label
                || credential != input.credential
                || fingerprint != input.credential_fingerprint
                || protocol_version != input.protocol_version
            {
                return Err(AppError::MessageRuntimeConflict(
                    "device_id 已存在但设备凭据不一致".to_string(),
                ));
            }
            let existing = sqlx::query_as::<_, E2eeDeviceRecord>(
                "SELECT id, user_id, device_label, protocol_version, status,
                        approved_by_device_id, approved_at, revoked_at, created_at, updated_at
                 FROM e2ee_devices WHERE id = $1",
            )
            .bind(input.device_id)
            .fetch_one(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)?;
            tx.commit().await.map_err(AppError::DatabaseError)?;
            return Ok(existing);
        }

        let status = if first_device {
            "active"
        } else {
            "pending_approval"
        };
        let device = sqlx::query_as::<_, E2eeDeviceRecord>(
            "INSERT INTO e2ee_devices (
                id, user_id, device_label, credential, credential_fingerprint,
                protocol_version, status, approved_at
             ) VALUES ($1, $2, $3, $4, $5, $6, $7,
                CASE WHEN $7 = 'active' THEN NOW() ELSE NULL END)
             RETURNING id, user_id, device_label, protocol_version, status,
                       approved_by_device_id, approved_at, revoked_at, created_at, updated_at",
        )
        .bind(input.device_id)
        .bind(user_id)
        .bind(input.device_label)
        .bind(input.credential)
        .bind(input.credential_fingerprint)
        .bind(input.protocol_version)
        .bind(status)
        .fetch_one(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;

        tx.commit().await.map_err(AppError::DatabaseError)?;
        Ok(device)
    }

    pub async fn approve_device(
        &self,
        user_id: Uuid,
        approver_device_id: Uuid,
        target_device_id: Uuid,
    ) -> Result<E2eeDeviceRecord, AppError> {
        if approver_device_id == target_device_id {
            return Err(AppError::ValidationError("设备不能批准自身".to_string()));
        }
        let mut tx = self.pool.begin().await.map_err(AppError::DatabaseError)?;
        let approver_status = sqlx::query_scalar::<_, String>(
            "SELECT status FROM e2ee_devices
             WHERE id = $1 AND user_id = $2
             FOR UPDATE",
        )
        .bind(approver_device_id)
        .bind(user_id)
        .fetch_optional(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?
        .ok_or_else(|| AppError::NotFound("批准设备不存在".to_string()))?;
        if approver_status != "active" {
            return Err(AppError::Forbidden(
                "只有可信设备可以批准新设备".to_string(),
            ));
        }

        let target_status = sqlx::query_scalar::<_, String>(
            "SELECT status FROM e2ee_devices
             WHERE id = $1 AND user_id = $2
             FOR UPDATE",
        )
        .bind(target_device_id)
        .bind(user_id)
        .fetch_optional(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?
        .ok_or_else(|| AppError::NotFound("待批准设备不存在".to_string()))?;
        if target_status != "pending_approval" {
            return Err(AppError::MessageRuntimeConflict(
                "目标设备不处于待批准状态".to_string(),
            ));
        }

        let device = sqlx::query_as::<_, E2eeDeviceRecord>(
            "UPDATE e2ee_devices
             SET status = 'active', approved_by_device_id = $1,
                 approved_at = NOW(), updated_at = NOW()
             WHERE id = $2
             RETURNING id, user_id, device_label, protocol_version, status,
                       approved_by_device_id, approved_at, revoked_at, created_at, updated_at",
        )
        .bind(approver_device_id)
        .bind(target_device_id)
        .fetch_one(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;
        tx.commit().await.map_err(AppError::DatabaseError)?;
        Ok(device)
    }

    pub async fn revoke_device(
        &self,
        user_id: Uuid,
        device_id: Uuid,
    ) -> Result<E2eeDeviceRecord, AppError> {
        let mut tx = self.pool.begin().await.map_err(AppError::DatabaseError)?;
        let device = sqlx::query_as::<_, E2eeDeviceRecord>(
            "UPDATE e2ee_devices
             SET status = 'revoked', revoked_at = COALESCE(revoked_at, NOW()), updated_at = NOW()
             WHERE id = $1 AND user_id = $2 AND status <> 'revoked'
             RETURNING id, user_id, device_label, protocol_version, status,
                       approved_by_device_id, approved_at, revoked_at, created_at, updated_at",
        )
        .bind(device_id)
        .bind(user_id)
        .fetch_optional(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?
        .ok_or_else(|| AppError::NotFound("可撤销设备不存在".to_string()))?;

        sqlx::query(
            "UPDATE e2ee_room_epochs AS epoch
             SET status = 'rekey_required', updated_at = NOW()
             FROM room_members AS member
             WHERE member.room_id = epoch.room_id
               AND member.user_id = $1
               AND member.deleted_at IS NULL",
        )
        .bind(user_id)
        .execute(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;

        tx.commit().await.map_err(AppError::DatabaseError)?;
        Ok(device)
    }

    pub async fn ensure_active_device(
        &self,
        user_id: Uuid,
        device_id: Uuid,
    ) -> Result<(), AppError> {
        let active = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS (
                SELECT 1 FROM e2ee_devices
                WHERE id = $1 AND user_id = $2 AND status = 'active'
             )",
        )
        .bind(device_id)
        .bind(user_id)
        .fetch_one(self.pool)
        .await
        .map_err(AppError::DatabaseError)?;
        if active {
            Ok(())
        } else {
            Err(AppError::Forbidden(
                "发送设备不存在、未批准或已撤销".to_string(),
            ))
        }
    }

    pub async fn publish_key_packages(
        &self,
        user_id: Uuid,
        device_id: Uuid,
        packages: &[NewKeyPackage],
    ) -> Result<usize, AppError> {
        self.ensure_active_device(user_id, device_id).await?;
        let mut tx = self.pool.begin().await.map_err(AppError::DatabaseError)?;
        let mut inserted = 0;
        for package in packages {
            let result = sqlx::query(
                "INSERT INTO e2ee_key_packages (
                    id, device_id, package_ref, key_package, protocol_version, expires_at
                 ) VALUES ($1, $2, $3, $4, $5, $6)
                 ON CONFLICT (package_ref) DO NOTHING",
            )
            .bind(package.id)
            .bind(device_id)
            .bind(&package.package_ref)
            .bind(&package.key_package)
            .bind(package.protocol_version)
            .bind(package.expires_at)
            .execute(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)?;
            inserted += result.rows_affected() as usize;
        }
        tx.commit().await.map_err(AppError::DatabaseError)?;
        Ok(inserted)
    }

    pub async fn take_key_package(
        &self,
        target_device_id: Uuid,
        consumer_device_id: Uuid,
    ) -> Result<Option<ClaimedKeyPackage>, AppError> {
        sqlx::query_as::<_, ClaimedKeyPackage>(
            "UPDATE e2ee_key_packages
             SET consumed_at = NOW(), consumed_by_device_id = $2
             WHERE id = (
                SELECT package.id
                FROM e2ee_key_packages AS package
                JOIN e2ee_devices AS target ON target.id = package.device_id
                WHERE package.device_id = $1
                  AND package.consumed_at IS NULL
                  AND package.expires_at > NOW()
                  AND target.status = 'active'
                  AND EXISTS (
                    SELECT 1 FROM e2ee_devices AS consumer
                    WHERE consumer.id = $2 AND consumer.status = 'active'
                  )
                ORDER BY package.created_at, package.id
                LIMIT 1
                FOR UPDATE OF package SKIP LOCKED
             )
             RETURNING id, device_id, package_ref, key_package, protocol_version,
                       expires_at, consumed_at, consumed_by_device_id",
        )
        .bind(target_device_id)
        .bind(consumer_device_id)
        .fetch_optional(self.pool)
        .await
        .map_err(AppError::DatabaseError)
    }
}
