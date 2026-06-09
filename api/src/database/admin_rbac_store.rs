use std::collections::BTreeMap;

use chrono::{DateTime, Utc};
use sqlx::FromRow;
use uuid::Uuid;

use crate::database::models::{Permission, Role};
use crate::database::Database;
use crate::error::AppError;

#[derive(Debug, Clone)]
pub struct AdminAccessSnapshot {
    pub role_codes: Vec<String>,
    pub permission_keys: Vec<String>,
    pub is_super_admin: bool,
}

pub struct AdminRbacStore {
    pool: sqlx::PgPool,
}

impl AdminRbacStore {
    pub fn new(database: Database) -> Self {
        Self {
            pool: database.pool,
        }
    }

    pub async fn get_admin_access_snapshot(
        &self,
        admin_user_id: &Uuid,
    ) -> Result<AdminAccessSnapshot, AppError> {
        let role_codes = sqlx::query_scalar::<_, String>(
            r#"
            SELECT DISTINCT r.code
            FROM roles r
            INNER JOIN admin_user_roles aur ON aur.role_id = r.id
            WHERE aur.admin_user_id = $1
            ORDER BY r.code
            "#,
        )
        .bind(admin_user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(AppError::DatabaseError)?;

        let permission_keys = sqlx::query_scalar::<_, String>(
            r#"
            SELECT DISTINCT p.code
            FROM permissions p
            INNER JOIN role_permissions rp ON rp.permission_id = p.id
            INNER JOIN admin_user_roles aur ON aur.role_id = rp.role_id
            WHERE aur.admin_user_id = $1
            ORDER BY p.code
            "#,
        )
        .bind(admin_user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(AppError::DatabaseError)?;

        let is_super_admin = role_codes.iter().any(|code| code == "super_admin");

        Ok(AdminAccessSnapshot {
            role_codes,
            permission_keys,
            is_super_admin,
        })
    }

    pub async fn list_permissions(&self) -> Result<Vec<Permission>, AppError> {
        sqlx::query_as::<_, Permission>(
            r#"
            SELECT id, name, code, description, created_at, updated_at
            FROM permissions
            ORDER BY code ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await
        .map_err(AppError::DatabaseError)
    }

    pub async fn list_roles_with_permissions(
        &self,
    ) -> Result<Vec<(Role, Vec<Permission>)>, AppError> {
        let rows = sqlx::query_as::<_, RoleWithPermissionRow>(
            r#"
            SELECT
                r.id AS role_id,
                r.name AS role_name,
                r.code AS role_code,
                r.description AS role_description,
                r.is_system AS role_is_system,
                r.created_at AS role_created_at,
                r.updated_at AS role_updated_at,
                p.id AS permission_id,
                p.name AS permission_name,
                p.code AS permission_code,
                p.description AS permission_description,
                p.created_at AS permission_created_at,
                p.updated_at AS permission_updated_at
            FROM roles r
            LEFT JOIN role_permissions rp ON rp.role_id = r.id
            LEFT JOIN permissions p ON p.id = rp.permission_id
            ORDER BY r.code ASC, p.code ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await
        .map_err(AppError::DatabaseError)?;

        let mut roles = BTreeMap::<Uuid, (Role, Vec<Permission>)>::new();

        for row in rows {
            let entry = roles.entry(row.role_id).or_insert_with(|| {
                (
                    Role {
                        id: row.role_id,
                        name: row.role_name.clone(),
                        code: row.role_code.clone(),
                        description: row.role_description.clone(),
                        is_system: row.role_is_system,
                        created_at: row.role_created_at,
                        updated_at: row.role_updated_at,
                    },
                    Vec::new(),
                )
            });

            if let Some(permission_id) = row.permission_id {
                entry.1.push(Permission {
                    id: permission_id,
                    name: row.permission_name.unwrap_or_default(),
                    code: row.permission_code.unwrap_or_default(),
                    description: row.permission_description,
                    created_at: row.permission_created_at.unwrap_or(row.role_created_at),
                    updated_at: row.permission_updated_at.unwrap_or(row.role_updated_at),
                });
            }
        }

        Ok(roles.into_values().collect())
    }

    pub async fn create_role(
        &self,
        name: &str,
        code: &str,
        description: Option<&str>,
        permission_ids: &[Uuid],
    ) -> Result<(Role, Vec<Permission>), AppError> {
        let mut tx = self.pool.begin().await.map_err(AppError::DatabaseError)?;

        let role = sqlx::query_as::<_, Role>(
            r#"
            INSERT INTO roles (name, code, description, is_system)
            VALUES ($1, $2, $3, FALSE)
            RETURNING id, name, code, description, is_system, created_at, updated_at
            "#,
        )
        .bind(name)
        .bind(code)
        .bind(description)
        .fetch_one(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;

        let permissions = self
            .replace_role_permissions_tx(&mut tx, &role.id, permission_ids)
            .await?;

        tx.commit().await.map_err(AppError::DatabaseError)?;

        Ok((role, permissions))
    }

    pub async fn update_role(
        &self,
        role_id: &Uuid,
        name: Option<&str>,
        description: Option<Option<&str>>,
        permission_ids: Option<Vec<Uuid>>,
    ) -> Result<(Role, Vec<Permission>), AppError> {
        let mut tx = self.pool.begin().await.map_err(AppError::DatabaseError)?;

        let existing = sqlx::query_as::<_, Role>(
            r#"
            SELECT id, name, code, description, is_system, created_at, updated_at
            FROM roles
            WHERE id = $1
            "#,
        )
        .bind(role_id)
        .fetch_optional(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?
        .ok_or_else(|| AppError::NotFound("角色不存在".to_string()))?;

        let role = sqlx::query_as::<_, Role>(
            r#"
            UPDATE roles
            SET name = COALESCE($2, name),
                description = CASE WHEN $3 THEN $4 ELSE description END,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $1
            RETURNING id, name, code, description, is_system, created_at, updated_at
            "#,
        )
        .bind(role_id)
        .bind(name)
        .bind(description.is_some())
        .bind(description.flatten())
        .fetch_one(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;

        let permissions = if let Some(permission_ids) = permission_ids {
            self.replace_role_permissions_tx(&mut tx, role_id, &permission_ids)
                .await?
        } else {
            self.list_role_permissions_tx(&mut tx, role_id).await?
        };

        if existing.is_system && role.code != existing.code {
            // 这里只是占位防御；当前 SQL 不允许更新 code，本轮也不开放 code 编辑。
        }

        tx.commit().await.map_err(AppError::DatabaseError)?;

        Ok((role, permissions))
    }

    pub async fn delete_role(&self, role_id: &Uuid) -> Result<bool, AppError> {
        let role = sqlx::query_as::<_, Role>(
            r#"
            SELECT id, name, code, description, is_system, created_at, updated_at
            FROM roles
            WHERE id = $1
            "#,
        )
        .bind(role_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(AppError::DatabaseError)?
        .ok_or_else(|| AppError::NotFound("角色不存在".to_string()))?;

        if role.is_system {
            return Err(AppError::ValidationError("系统角色不允许删除".to_string()));
        }

        let result = sqlx::query("DELETE FROM roles WHERE id = $1")
            .bind(role_id)
            .execute(&self.pool)
            .await
            .map_err(AppError::DatabaseError)?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn get_role_permission_ids(&self, role_id: &Uuid) -> Result<Vec<Uuid>, AppError> {
        self.ensure_role_exists(role_id).await?;

        sqlx::query_scalar::<_, Uuid>(
            r#"
            SELECT permission_id
            FROM role_permissions
            WHERE role_id = $1
            ORDER BY permission_id
            "#,
        )
        .bind(role_id)
        .fetch_all(&self.pool)
        .await
        .map_err(AppError::DatabaseError)
    }

    pub async fn update_role_permissions(
        &self,
        role_id: &Uuid,
        permission_ids: &[Uuid],
    ) -> Result<Vec<Permission>, AppError> {
        let mut tx = self.pool.begin().await.map_err(AppError::DatabaseError)?;
        let permissions = self
            .replace_role_permissions_tx(&mut tx, role_id, permission_ids)
            .await?;
        tx.commit().await.map_err(AppError::DatabaseError)?;
        Ok(permissions)
    }

    pub async fn get_admin_user_role_ids(
        &self,
        admin_user_id: &Uuid,
    ) -> Result<Vec<Uuid>, AppError> {
        let exists: Option<bool> =
            sqlx::query_scalar("SELECT TRUE FROM admin_users WHERE id = $1 AND deleted_at IS NULL")
                .bind(admin_user_id)
                .fetch_optional(&self.pool)
                .await
                .map_err(AppError::DatabaseError)?;

        if exists != Some(true) {
            return Err(AppError::NotFound("管理员用户不存在".to_string()));
        }

        sqlx::query_scalar::<_, Uuid>(
            r#"
            SELECT role_id
            FROM admin_user_roles
            WHERE admin_user_id = $1
            ORDER BY role_id
            "#,
        )
        .bind(admin_user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(AppError::DatabaseError)
    }

    pub async fn update_admin_user_roles(
        &self,
        admin_user_id: &Uuid,
        role_ids: &[Uuid],
        assigned_by: Option<&Uuid>,
    ) -> Result<Vec<Uuid>, AppError> {
        let exists: Option<bool> =
            sqlx::query_scalar("SELECT TRUE FROM admin_users WHERE id = $1 AND deleted_at IS NULL")
                .bind(admin_user_id)
                .fetch_optional(&self.pool)
                .await
                .map_err(AppError::DatabaseError)?;

        if exists != Some(true) {
            return Err(AppError::NotFound("管理员用户不存在".to_string()));
        }

        self.validate_role_ids(role_ids).await?;

        let mut tx = self.pool.begin().await.map_err(AppError::DatabaseError)?;

        sqlx::query("DELETE FROM admin_user_roles WHERE admin_user_id = $1")
            .bind(admin_user_id)
            .execute(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)?;

        for role_id in role_ids {
            sqlx::query(
                r#"
                INSERT INTO admin_user_roles (admin_user_id, role_id, assigned_by)
                VALUES ($1, $2, $3)
                ON CONFLICT (admin_user_id, role_id) DO NOTHING
                "#,
            )
            .bind(admin_user_id)
            .bind(role_id)
            .bind(assigned_by)
            .execute(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)?;
        }

        tx.commit().await.map_err(AppError::DatabaseError)?;

        self.get_admin_user_role_ids(admin_user_id).await
    }

    pub async fn has_admin_permission(
        &self,
        admin_user_id: &Uuid,
        permission_code: &str,
    ) -> Result<bool, AppError> {
        let has_permission = sqlx::query_scalar::<_, bool>(
            r#"
            SELECT EXISTS (
                SELECT 1
                FROM permissions p
                INNER JOIN role_permissions rp ON rp.permission_id = p.id
                INNER JOIN admin_user_roles aur ON aur.role_id = rp.role_id
                WHERE aur.admin_user_id = $1 AND p.code = $2
            )
            "#,
        )
        .bind(admin_user_id)
        .bind(permission_code)
        .fetch_one(&self.pool)
        .await
        .map_err(AppError::DatabaseError)?;

        Ok(has_permission)
    }

    async fn replace_role_permissions_tx(
        &self,
        tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
        role_id: &Uuid,
        permission_ids: &[Uuid],
    ) -> Result<Vec<Permission>, AppError> {
        self.ensure_role_exists_tx(tx, role_id).await?;
        self.validate_permission_ids(permission_ids).await?;

        sqlx::query("DELETE FROM role_permissions WHERE role_id = $1")
            .bind(role_id)
            .execute(&mut **tx)
            .await
            .map_err(AppError::DatabaseError)?;

        for permission_id in permission_ids {
            sqlx::query(
                r#"
                INSERT INTO role_permissions (role_id, permission_id)
                VALUES ($1, $2)
                ON CONFLICT (role_id, permission_id) DO NOTHING
                "#,
            )
            .bind(role_id)
            .bind(permission_id)
            .execute(&mut **tx)
            .await
            .map_err(AppError::DatabaseError)?;
        }

        self.list_role_permissions_tx(tx, role_id).await
    }

    async fn list_role_permissions_tx(
        &self,
        tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
        role_id: &Uuid,
    ) -> Result<Vec<Permission>, AppError> {
        sqlx::query_as::<_, Permission>(
            r#"
            SELECT p.id, p.name, p.code, p.description, p.created_at, p.updated_at
            FROM permissions p
            INNER JOIN role_permissions rp ON rp.permission_id = p.id
            WHERE rp.role_id = $1
            ORDER BY p.code ASC
            "#,
        )
        .bind(role_id)
        .fetch_all(&mut **tx)
        .await
        .map_err(AppError::DatabaseError)
    }

    async fn ensure_role_exists_tx(
        &self,
        tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
        role_id: &Uuid,
    ) -> Result<(), AppError> {
        let exists: Option<bool> = sqlx::query_scalar("SELECT TRUE FROM roles WHERE id = $1")
            .bind(role_id)
            .fetch_optional(&mut **tx)
            .await
            .map_err(AppError::DatabaseError)?;

        if exists != Some(true) {
            return Err(AppError::NotFound("角色不存在".to_string()));
        }

        Ok(())
    }

    async fn ensure_role_exists(&self, role_id: &Uuid) -> Result<(), AppError> {
        let exists: Option<bool> = sqlx::query_scalar("SELECT TRUE FROM roles WHERE id = $1")
            .bind(role_id)
            .fetch_optional(&self.pool)
            .await
            .map_err(AppError::DatabaseError)?;

        if exists != Some(true) {
            return Err(AppError::NotFound("角色不存在".to_string()));
        }

        Ok(())
    }

    async fn validate_permission_ids(&self, permission_ids: &[Uuid]) -> Result<(), AppError> {
        if permission_ids.is_empty() {
            return Ok(());
        }

        let count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*)::BIGINT FROM permissions WHERE id = ANY($1)",
        )
        .bind(permission_ids)
        .fetch_one(&self.pool)
        .await
        .map_err(AppError::DatabaseError)?;

        if count != permission_ids.len() as i64 {
            return Err(AppError::ValidationError("包含不存在的权限 ID".to_string()));
        }

        Ok(())
    }

    async fn validate_role_ids(&self, role_ids: &[Uuid]) -> Result<(), AppError> {
        if role_ids.is_empty() {
            return Ok(());
        }

        let count =
            sqlx::query_scalar::<_, i64>("SELECT COUNT(*)::BIGINT FROM roles WHERE id = ANY($1)")
                .bind(role_ids)
                .fetch_one(&self.pool)
                .await
                .map_err(AppError::DatabaseError)?;

        if count != role_ids.len() as i64 {
            return Err(AppError::ValidationError("包含不存在的角色 ID".to_string()));
        }

        Ok(())
    }
}

#[derive(Debug, FromRow)]
struct RoleWithPermissionRow {
    role_id: Uuid,
    role_name: String,
    role_code: String,
    role_description: Option<String>,
    role_is_system: bool,
    role_created_at: DateTime<Utc>,
    role_updated_at: DateTime<Utc>,
    permission_id: Option<Uuid>,
    permission_name: Option<String>,
    permission_code: Option<String>,
    permission_description: Option<String>,
    permission_created_at: Option<DateTime<Utc>>,
    permission_updated_at: Option<DateTime<Utc>>,
}
