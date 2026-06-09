use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::database::models::{E2eeOneTimePreKey, E2eeSignedPreKey};

#[derive(Debug, Clone)]
pub struct SignedPreKeyInsert {
    pub key_id: i32,
    pub public_key: Vec<u8>,
    pub signature: Vec<u8>,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Clone)]
pub struct OneTimePreKeyInsert {
    pub key_id: i32,
    pub public_key: Vec<u8>,
}

pub struct E2eeKeyStore<'a> {
    pub pool: &'a PgPool,
}

impl<'a> E2eeKeyStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    /// 保存/更新某个设备的 E2EE 公钥与预密钥包。
    ///
    /// 说明：
    /// - 身份公钥：按 (user_id, device_id) upsert；
    /// - 签名预密钥：按 (user_id, device_id, key_id) upsert；
    /// - 一次性预密钥：按 (user_id, device_id, key_id) 去重插入（重复上传不报错）。
    pub async fn save_key_bundle(
        &self,
        user_id: Uuid,
        device_id: &str,
        identity_key: Vec<u8>,
        signed_pre_key: SignedPreKeyInsert,
        one_time_pre_keys: Vec<OneTimePreKeyInsert>,
    ) -> Result<(), sqlx::Error> {
        let mut tx = self.pool.begin().await?;

        sqlx::query(
            r#"
            INSERT INTO e2ee_identity_keys (user_id, device_id, public_key, created_at, updated_at)
            VALUES ($1, $2, $3, NOW(), NOW())
            ON CONFLICT (user_id, device_id) DO UPDATE
            SET public_key = EXCLUDED.public_key,
                updated_at = NOW()
            "#,
        )
        .bind(user_id)
        .bind(device_id)
        .bind(identity_key)
        .execute(&mut *tx)
        .await?;

        sqlx::query(
            r#"
            INSERT INTO e2ee_signed_pre_keys (
                id, user_id, device_id, key_id, public_key, signature, expires_at, created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
            ON CONFLICT (user_id, device_id, key_id) DO UPDATE
            SET public_key = EXCLUDED.public_key,
                signature = EXCLUDED.signature,
                expires_at = EXCLUDED.expires_at,
                created_at = NOW()
            "#,
        )
        .bind(crate::id::generate())
        .bind(user_id)
        .bind(device_id)
        .bind(signed_pre_key.key_id)
        .bind(signed_pre_key.public_key)
        .bind(signed_pre_key.signature)
        .bind(signed_pre_key.expires_at)
        .execute(&mut *tx)
        .await?;

        for item in one_time_pre_keys {
            sqlx::query(
                r#"
                INSERT INTO e2ee_one_time_pre_keys (
                    id, user_id, device_id, key_id, public_key, is_used, used_at, created_at
                )
                VALUES ($1, $2, $3, $4, $5, FALSE, NULL, NOW())
                ON CONFLICT (user_id, device_id, key_id) DO NOTHING
                "#,
            )
            .bind(crate::id::generate())
            .bind(user_id)
            .bind(device_id)
            .bind(item.key_id)
            .bind(item.public_key)
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    pub async fn list_device_ids(&self, user_id: Uuid) -> Result<Vec<String>, sqlx::Error> {
        sqlx::query_scalar::<_, String>(
            r#"
            SELECT device_id
            FROM e2ee_identity_keys
            WHERE user_id = $1
            ORDER BY updated_at DESC
            "#,
        )
        .bind(user_id)
        .fetch_all(self.pool)
        .await
    }

    pub async fn get_identity_key(
        &self,
        user_id: Uuid,
        device_id: &str,
    ) -> Result<Option<Vec<u8>>, sqlx::Error> {
        sqlx::query_scalar::<_, Vec<u8>>(
            r#"
            SELECT public_key
            FROM e2ee_identity_keys
            WHERE user_id = $1 AND device_id = $2
            "#,
        )
        .bind(user_id)
        .bind(device_id)
        .fetch_optional(self.pool)
        .await
    }

    pub async fn get_latest_active_signed_pre_key(
        &self,
        user_id: Uuid,
        device_id: &str,
    ) -> Result<Option<E2eeSignedPreKey>, sqlx::Error> {
        sqlx::query_as::<_, E2eeSignedPreKey>(
            r#"
            SELECT id, user_id, device_id, key_id, public_key, signature, expires_at, created_at
            FROM e2ee_signed_pre_keys
            WHERE user_id = $1 AND device_id = $2 AND expires_at > NOW()
            ORDER BY created_at DESC
            LIMIT 1
            "#,
        )
        .bind(user_id)
        .bind(device_id)
        .fetch_optional(self.pool)
        .await
    }

    /// 原子取用一个未使用的一次性预密钥。
    pub async fn take_one_time_pre_key(
        &self,
        user_id: Uuid,
        device_id: &str,
    ) -> Result<Option<E2eeOneTimePreKey>, sqlx::Error> {
        sqlx::query_as::<_, E2eeOneTimePreKey>(
            r#"
            UPDATE e2ee_one_time_pre_keys
            SET is_used = TRUE,
                used_at = NOW()
            WHERE id = (
                SELECT id
                FROM e2ee_one_time_pre_keys
                WHERE user_id = $1 AND device_id = $2 AND is_used IS FALSE
                ORDER BY created_at
                LIMIT 1
                FOR UPDATE SKIP LOCKED
            )
            RETURNING id, user_id, device_id, key_id, public_key, is_used, used_at, created_at
            "#,
        )
        .bind(user_id)
        .bind(device_id)
        .fetch_optional(self.pool)
        .await
    }

    pub async fn count_unused_one_time_pre_keys(
        &self,
        user_id: Uuid,
        device_id: &str,
    ) -> Result<i64, sqlx::Error> {
        let row: (i64,) = sqlx::query_as(
            r#"
            SELECT COUNT(1) AS total
            FROM e2ee_one_time_pre_keys
            WHERE user_id = $1 AND device_id = $2 AND is_used IS FALSE
            "#,
        )
        .bind(user_id)
        .bind(device_id)
        .fetch_one(self.pool)
        .await?;

        Ok(row.0)
    }
}
