use crate::database::models::{
    CreateEmojiItemRequest, CreateEmojiPackRequest, EmojiItem, EmojiPack, EmojiPackStatus,
    EmojiPackType, UpdateEmojiItemRequest, UpdateEmojiPackRequest, UserEmojiPack,
};
use crate::database::Database;
use crate::id::generate;
use chrono::Utc;
use sqlx::{query_as, Error, Row};
use uuid::Uuid;

#[derive(Clone)]
pub struct EmojiPackStore {
    database: Database,
}

impl EmojiPackStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    // ===== 表情包相关方法 =====

    /// 创建表情包
    pub async fn create_pack(&self, request: CreateEmojiPackRequest) -> Result<EmojiPack, Error> {
        let pack_id = generate();
        let now = Utc::now();
        let is_active = if request.is_active.unwrap_or(true) {
            EmojiPackStatus::Active
        } else {
            EmojiPackStatus::Inactive
        };
        let pack_type = match request.pack_type {
            Some(1) => EmojiPackType::Suite,
            _ => EmojiPackType::Single,
        };
        let parent_id = if let Some(parent_id_str) = request.parent_id {
            Some(
                Uuid::parse_str(&parent_id_str)
                    .map_err(|e| Error::Decode(format!("Invalid parent_id: {}", e).into()))?,
            )
        } else {
            None
        };

        let pack = query_as::<_, EmojiPack>(
            r#"
            INSERT INTO emoji_packs (id, name, icon_url, description, is_active, pack_type, parent_id, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $8)
            RETURNING id, name, icon_url, description, is_active, pack_type, parent_id, created_at, updated_at
            "#,
        )
        .bind(pack_id)
        .bind(&request.name)
        .bind(&request.icon_url)
        .bind(&request.description)
        .bind(is_active)
        .bind(pack_type)
        .bind(parent_id)
        .bind(now)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(pack)
    }

    /// 获取所有表情包（管理员用）
    pub async fn list_all_packs(&self) -> Result<Vec<EmojiPack>, Error> {
        let packs = query_as::<_, EmojiPack>(
            r#"
            SELECT id, name, icon_url, description, is_active, pack_type, parent_id, created_at, updated_at
            FROM emoji_packs
            ORDER BY created_at DESC
            "#,
        )
        .fetch_all(&self.database.pool)
        .await?;

        Ok(packs)
    }

    /// 获取激活的表情包列表（只返回单个表情包和套件，不返回套件下的子表情包）
    pub async fn list_active_packs(&self) -> Result<Vec<EmojiPack>, Error> {
        let packs = query_as::<_, EmojiPack>(
            r#"
            SELECT id, name, icon_url, description, is_active, pack_type, parent_id, created_at, updated_at
            FROM emoji_packs
            WHERE is_active = $1 AND parent_id IS NULL
            ORDER BY created_at DESC
            "#,
        )
        .bind(EmojiPackStatus::Active)
        .fetch_all(&self.database.pool)
        .await?;

        Ok(packs)
    }

    /// 获取套件下的所有表情包（管理员用，包括未激活的）
    pub async fn list_packs_by_parent(&self, parent_id: Uuid) -> Result<Vec<EmojiPack>, Error> {
        let packs = query_as::<_, EmojiPack>(
            r#"
            SELECT id, name, icon_url, description, is_active, pack_type, parent_id, created_at, updated_at
            FROM emoji_packs
            WHERE parent_id = $1
            ORDER BY created_at DESC
            "#,
        )
        .bind(parent_id)
        .fetch_all(&self.database.pool)
        .await?;

        Ok(packs)
    }

    /// 搜索表情包和套件（用户用，只搜索激活的）
    pub async fn search_packs(&self, keyword: &str) -> Result<Vec<EmojiPack>, Error> {
        let search_pattern = format!("%{}%", keyword);
        let packs = query_as::<_, EmojiPack>(
            r#"
            SELECT id, name, icon_url, description, is_active, pack_type, parent_id, created_at, updated_at
            FROM emoji_packs
            WHERE is_active = $1 
              AND parent_id IS NULL
              AND (LOWER(name) LIKE LOWER($2) OR LOWER(description) LIKE LOWER($2))
            ORDER BY created_at DESC
            LIMIT 50
            "#,
        )
        .bind(EmojiPackStatus::Active)
        .bind(&search_pattern)
        .fetch_all(&self.database.pool)
        .await?;

        Ok(packs)
    }

    /// 搜索所有表情包和套件（管理员用，包括未激活的）
    pub async fn search_all_packs(&self, keyword: &str) -> Result<Vec<EmojiPack>, Error> {
        let search_pattern = format!("%{}%", keyword);
        let packs = query_as::<_, EmojiPack>(
            r#"
            SELECT id, name, icon_url, description, is_active, pack_type, parent_id, created_at, updated_at
            FROM emoji_packs
            WHERE parent_id IS NULL
              AND (LOWER(name) LIKE LOWER($1) OR LOWER(description) LIKE LOWER($1))
            ORDER BY created_at DESC
            LIMIT 100
            "#,
        )
        .bind(&search_pattern)
        .fetch_all(&self.database.pool)
        .await?;

        Ok(packs)
    }

    /// 根据 ID 获取表情包
    pub async fn get_pack_by_id(&self, pack_id: Uuid) -> Result<Option<EmojiPack>, Error> {
        let pack = query_as::<_, EmojiPack>(
            r#"
            SELECT id, name, icon_url, description, is_active, pack_type, parent_id, created_at, updated_at
            FROM emoji_packs
            WHERE id = $1
            "#,
        )
        .bind(pack_id)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(pack)
    }

    /// 更新表情包
    pub async fn update_pack(
        &self,
        pack_id: Uuid,
        request: UpdateEmojiPackRequest,
    ) -> Result<Option<EmojiPack>, Error> {
        // 先获取现有数据
        let existing = match self.get_pack_by_id(pack_id).await? {
            Some(p) => p,
            None => return Ok(None),
        };

        let name = request.name.as_ref().unwrap_or(&existing.name);
        let icon_url = request.icon_url.as_ref().or(existing.icon_url.as_ref());
        let description = request
            .description
            .as_ref()
            .or(existing.description.as_ref());
        let is_active = if let Some(active) = request.is_active {
            if active {
                EmojiPackStatus::Active
            } else {
                EmojiPackStatus::Inactive
            }
        } else {
            existing.is_active
        };
        let pack_type = if let Some(type_val) = request.pack_type {
            if type_val == 1 {
                EmojiPackType::Suite
            } else {
                EmojiPackType::Single
            }
        } else {
            existing.pack_type
        };
        let parent_id = if let Some(parent_id_str) = request.parent_id {
            Some(
                Uuid::parse_str(&parent_id_str)
                    .map_err(|e| Error::Decode(format!("Invalid parent_id: {}", e).into()))?,
            )
        } else {
            existing.parent_id
        };

        let pack = query_as::<_, EmojiPack>(
            r#"
            UPDATE emoji_packs
            SET name = $1, icon_url = $2, description = $3, is_active = $4, pack_type = $5, parent_id = $6, updated_at = $7
            WHERE id = $8
            RETURNING id, name, icon_url, description, is_active, pack_type, parent_id, created_at, updated_at
            "#,
        )
        .bind(name)
        .bind(icon_url)
        .bind(description)
        .bind(is_active)
        .bind(pack_type)
        .bind(parent_id)
        .bind(Utc::now())
        .bind(pack_id)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(pack)
    }

    /// 删除表情包
    pub async fn delete_pack(&self, pack_id: Uuid) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            DELETE FROM emoji_packs
            WHERE id = $1
            "#,
        )
        .bind(pack_id)
        .execute(&self.database.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    // ===== 表情项相关方法 =====

    /// 创建表情项
    pub async fn create_item(&self, request: CreateEmojiItemRequest) -> Result<EmojiItem, Error> {
        let item_id = generate();
        let pack_id = Uuid::parse_str(&request.pack_id)
            .map_err(|e| Error::Decode(format!("Invalid pack_id: {}", e).into()))?;
        let now = Utc::now();
        let sort_order = request.sort_order.unwrap_or(0);

        let item = query_as::<_, EmojiItem>(
            r#"
            INSERT INTO emoji_items (id, pack_id, image_url, name, sort_order, created_at)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING id, pack_id, image_url, name, sort_order, created_at
            "#,
        )
        .bind(item_id)
        .bind(pack_id)
        .bind(&request.image_url)
        .bind(&request.name)
        .bind(sort_order)
        .bind(now)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(item)
    }

    /// 获取表情包的所有表情项
    pub async fn list_items_by_pack(&self, pack_id: Uuid) -> Result<Vec<EmojiItem>, Error> {
        tracing::debug!("查询表情项: pack_id={}", pack_id);
        let items = query_as::<_, EmojiItem>(
            r#"
            SELECT id, pack_id, image_url, name, sort_order, created_at
            FROM emoji_items
            WHERE pack_id = $1
            ORDER BY sort_order ASC, created_at ASC
            "#,
        )
        .bind(pack_id)
        .fetch_all(&self.database.pool)
        .await?;

        tracing::debug!("查询结果: pack_id={}, items_count={}", pack_id, items.len());
        Ok(items)
    }

    /// 根据 ID 获取表情项
    pub async fn get_item_by_id(&self, item_id: Uuid) -> Result<Option<EmojiItem>, Error> {
        let item = query_as::<_, EmojiItem>(
            r#"
            SELECT id, pack_id, image_url, name, sort_order, created_at
            FROM emoji_items
            WHERE id = $1
            "#,
        )
        .bind(item_id)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(item)
    }

    /// 更新表情项
    pub async fn update_item(
        &self,
        item_id: Uuid,
        request: UpdateEmojiItemRequest,
    ) -> Result<Option<EmojiItem>, Error> {
        // 先获取现有数据
        let existing = match self.get_item_by_id(item_id).await? {
            Some(i) => i,
            None => return Ok(None),
        };

        let image_url = request.image_url.as_ref().unwrap_or(&existing.image_url);
        let name = request.name.as_ref().or(existing.name.as_ref());
        let sort_order = request.sort_order.unwrap_or(existing.sort_order);

        let item = query_as::<_, EmojiItem>(
            r#"
            UPDATE emoji_items
            SET image_url = $1, name = $2, sort_order = $3
            WHERE id = $4
            RETURNING id, pack_id, image_url, name, sort_order, created_at
            "#,
        )
        .bind(image_url)
        .bind(name)
        .bind(sort_order)
        .bind(item_id)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(item)
    }

    /// 删除表情项
    pub async fn delete_item(&self, item_id: Uuid) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            DELETE FROM emoji_items
            WHERE id = $1
            "#,
        )
        .bind(item_id)
        .execute(&self.database.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    // ===== 用户表情包关联相关方法 =====

    /// 获取用户的表情包列表（返回单个表情包和套件）
    pub async fn list_user_packs(&self, user_id: Uuid) -> Result<Vec<EmojiPack>, Error> {
        let packs = query_as::<_, EmojiPack>(
            r#"
            SELECT p.id, p.name, p.icon_url, p.description, p.is_active, p.pack_type, p.parent_id, p.created_at, p.updated_at
            FROM emoji_packs p
            INNER JOIN user_emoji_packs uep ON p.id = uep.pack_id
            WHERE uep.user_id = $1 AND p.is_active = $2
            ORDER BY uep.created_at DESC
            "#,
        )
        .bind(user_id)
        .bind(EmojiPackStatus::Active)
        .fetch_all(&self.database.pool)
        .await?;

        Ok(packs)
    }

    /// 添加套件下的所有表情包到用户
    pub async fn add_suite_packs_to_user(
        &self,
        user_id: Uuid,
        suite_id: Uuid,
    ) -> Result<usize, Error> {
        let now = Utc::now();
        let mut count = 0;

        // 首先添加套件本身到用户表情包列表
        let suite_exists = self.has_user_pack(user_id, suite_id).await?;
        if !suite_exists {
            sqlx::query(
                r#"
                INSERT INTO user_emoji_packs (user_id, pack_id, created_at)
                VALUES ($1, $2, $3)
                ON CONFLICT (user_id, pack_id) DO NOTHING
                "#,
            )
            .bind(user_id)
            .bind(suite_id)
            .bind(now)
            .execute(&self.database.pool)
            .await?;
        }

        // 获取套件下的所有表情包（只添加激活的）
        let child_packs = self.list_packs_by_parent(suite_id).await?;

        for pack in child_packs {
            // 只添加激活的表情包
            if pack.is_active != EmojiPackStatus::Active {
                continue;
            }
            // 检查是否已添加
            let exists = self.has_user_pack(user_id, pack.id).await?;
            if !exists {
                sqlx::query(
                    r#"
                    INSERT INTO user_emoji_packs (user_id, pack_id, created_at)
                    VALUES ($1, $2, $3)
                    ON CONFLICT (user_id, pack_id) DO NOTHING
                    "#,
                )
                .bind(user_id)
                .bind(pack.id)
                .bind(now)
                .execute(&self.database.pool)
                .await?;
                count += 1;
            }
        }

        Ok(count)
    }

    /// 添加用户表情包
    pub async fn add_user_pack(
        &self,
        user_id: Uuid,
        pack_id: Uuid,
    ) -> Result<UserEmojiPack, Error> {
        let now = Utc::now();

        let user_pack = query_as::<_, UserEmojiPack>(
            r#"
            INSERT INTO user_emoji_packs (user_id, pack_id, created_at)
            VALUES ($1, $2, $3)
            ON CONFLICT (user_id, pack_id) DO NOTHING
            RETURNING user_id, pack_id, created_at
            "#,
        )
        .bind(user_id)
        .bind(pack_id)
        .bind(now)
        .fetch_optional(&self.database.pool)
        .await?;

        match user_pack {
            Some(up) => Ok(up),
            None => {
                // 如果已存在，直接查询返回
                query_as::<_, UserEmojiPack>(
                    r#"
                    SELECT user_id, pack_id, created_at
                    FROM user_emoji_packs
                    WHERE user_id = $1 AND pack_id = $2
                    "#,
                )
                .bind(user_id)
                .bind(pack_id)
                .fetch_one(&self.database.pool)
                .await
            }
        }
    }

    /// 删除用户表情包
    pub async fn remove_user_pack(&self, user_id: Uuid, pack_id: Uuid) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            DELETE FROM user_emoji_packs
            WHERE user_id = $1 AND pack_id = $2
            "#,
        )
        .bind(user_id)
        .bind(pack_id)
        .execute(&self.database.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    /// 检查用户是否已添加表情包
    pub async fn has_user_pack(&self, user_id: Uuid, pack_id: Uuid) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM user_emoji_packs
                WHERE user_id = $1 AND pack_id = $2
            )
            "#,
        )
        .bind(user_id)
        .bind(pack_id)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(result.get::<bool, _>(0))
    }
}
