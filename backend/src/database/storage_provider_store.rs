use crate::database::models::{StorageProvider, StorageProviderType};
use crate::database::Database;
use sqlx::{query_as, Error};
use uuid::Uuid;

#[derive(Clone)]
pub struct StorageProviderStore {
    database: Database,
}

impl StorageProviderStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    /// 获取所有提供商配置
    pub async fn list_providers(&self) -> Result<Vec<StorageProvider>, Error> {
        let providers = query_as::<_, StorageProvider>(
            r#"
            SELECT id, provider_type, name, secret_id, secret_key, region, endpoint,
                   bucket_name, is_active, is_default, description, created_at, updated_at, updated_by
            FROM storage_providers
            ORDER BY created_at DESC
            "#,
        )
        .fetch_all(&self.database.pool)
        .await?;

        Ok(providers)
    }

    /// 根据ID获取提供商配置
    pub async fn get_provider_by_id(&self, id: &Uuid) -> Result<Option<StorageProvider>, Error> {
        let provider = query_as::<_, StorageProvider>(
            r#"
            SELECT id, provider_type, name, secret_id, secret_key, region, endpoint,
                   bucket_name, is_active, is_default, description, created_at, updated_at, updated_by
            FROM storage_providers
            WHERE id = $1
            "#,
        )
        .bind(id)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(provider)
    }

    /// 获取默认提供商配置
    pub async fn get_default_provider(&self) -> Result<Option<StorageProvider>, Error> {
        let provider = query_as::<_, StorageProvider>(
            r#"
            SELECT id, provider_type, name, secret_id, secret_key, region, endpoint,
                   bucket_name, is_active, is_default, description, created_at, updated_at, updated_by
            FROM storage_providers
            WHERE is_default = TRUE AND is_active = TRUE
            LIMIT 1
            "#,
        )
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(provider)
    }

    /// 创建提供商配置
    pub async fn create_provider(
        &self,
        provider_type: StorageProviderType,
        name: &str,
        secret_id: &str,
        secret_key: &str,
        region: &str,
        endpoint: &str,
        bucket_name: Option<&str>,
        is_active: bool,
        is_default: bool,
        description: Option<&str>,
        updated_by: Option<Uuid>,
    ) -> Result<StorageProvider, Error> {
        // 如果设置为默认，需要先取消其他默认提供商
        if is_default {
            let _: () = sqlx::query(
                "UPDATE storage_providers SET is_default = FALSE WHERE is_default = TRUE",
            )
            .execute(&self.database.pool)
            .await?;
        }

        let provider = query_as::<_, StorageProvider>(
            r#"
            INSERT INTO storage_providers (
                provider_type, name, secret_id, secret_key, region, endpoint,
                bucket_name, is_active, is_default, description, updated_at, updated_by
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW(), $11)
            RETURNING id, provider_type, name, secret_id, secret_key, region, endpoint,
                      bucket_name, is_active, is_default, description, created_at, updated_at, updated_by
            "#,
        )
        .bind(provider_type)
        .bind(name)
        .bind(secret_id)
        .bind(secret_key)
        .bind(region)
        .bind(endpoint)
        .bind(bucket_name)
        .bind(is_active)
        .bind(is_default)
        .bind(description)
        .bind(updated_by)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(provider)
    }

    /// 更新提供商配置
    pub async fn update_provider(
        &self,
        id: &Uuid,
        provider_type: Option<StorageProviderType>,
        name: Option<&str>,
        secret_id: Option<&str>,
        secret_key: Option<&str>,
        region: Option<&str>,
        endpoint: Option<&str>,
        bucket_name: Option<Option<&str>>,
        is_active: Option<bool>,
        is_default: Option<bool>,
        description: Option<Option<&str>>,
        updated_by: Option<Uuid>,
    ) -> Result<Option<StorageProvider>, Error> {
        // 如果设置为默认，需要先取消其他默认提供商
        if let Some(true) = is_default {
            let _: () = sqlx::query(
                "UPDATE storage_providers SET is_default = FALSE WHERE is_default = TRUE AND id != $1",
            )
            .bind(id)
            .execute(&self.database.pool)
            .await?;
        }

        let provider = query_as::<_, StorageProvider>(
            r#"
            UPDATE storage_providers SET
                provider_type = COALESCE($2, provider_type),
                name = COALESCE($3, name),
                secret_id = COALESCE($4, secret_id),
                secret_key = COALESCE($5, secret_key),
                region = COALESCE($6, region),
                endpoint = COALESCE($7, endpoint),
                bucket_name = COALESCE($8, bucket_name),
                is_active = COALESCE($9, is_active),
                is_default = COALESCE($10, is_default),
                description = COALESCE($11, description),
                updated_at = NOW(),
                updated_by = $12
            WHERE id = $1
            RETURNING id, provider_type, name, secret_id, secret_key, region, endpoint,
                      bucket_name, is_active, is_default, description, created_at, updated_at, updated_by
            "#,
        )
        .bind(id)
        .bind(provider_type)
        .bind(name)
        .bind(secret_id)
        .bind(secret_key)
        .bind(region)
        .bind(endpoint)
        .bind(bucket_name)
        .bind(is_active)
        .bind(is_default)
        .bind(description)
        .bind(updated_by)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(provider)
    }

    /// 删除提供商配置
    pub async fn delete_provider(&self, id: &Uuid) -> Result<bool, Error> {
        let result = sqlx::query("DELETE FROM storage_providers WHERE id = $1")
            .bind(id)
            .execute(&self.database.pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }
}
