use sqlx::{postgres::PgPoolOptions, PgPool};
use std::env;

pub mod account_store;
pub mod document_store;
pub mod emoji_pack_store;
pub mod friend_store;
pub mod group_management_store;
pub mod member_with_user_info;
pub mod message_read_store;
pub mod message_store;
pub mod models;
pub mod room_store;
pub mod settings_store;
pub mod storage_provider_store;
pub mod user_store;

/// 数据库连接池
#[derive(Clone)]
pub struct Database {
    pub pool: PgPool,
}

/// 迁移记录表名称
const MIGRATIONS_TABLE: &str = "db_migrations";

/// 基础初始化脚本（原 all.sql，重命名为 base.sql）
const BASE_MIGRATION_NAME: &str = "base.sql";
const BASE_MIGRATION_SQL: &str = include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/sql/base.sql"));

/// 按执行顺序写死的迁移脚本列表
///
/// 说明：
/// - 第一个必须是基础脚本 `base.sql`，用于初始化全新数据库；
/// - 后续新增迁移文件时，请按时间顺序追加到此数组中；
const MIGRATIONS: &[(&str, &str)] = &[
    // 基础初始化脚本
    (BASE_MIGRATION_NAME, BASE_MIGRATION_SQL),
    // 2025-12-07：好友相关 WebSocket 事件占位迁移（当前不做结构变更）
    (
        "20251207120000_friend_ws_placeholder.sql",
        include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/sql/migrations/20251207120000_friend_ws_placeholder.sql"
        )),
    ),
    // 2025-12-09：为表情包与表情项增加 COS 对象键字段
    (
        "20251209123000_add_emoji_object_keys.sql",
        include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/sql/migrations/20251209123000_add_emoji_object_keys.sql"
        )),
    ),
];

impl Database {
    /// 创建数据库连接池
    pub async fn new() -> Result<Self, sqlx::Error> {
        dotenvy::dotenv().ok();

        let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");

        tracing::info!("正在连接数据库: {}", database_url);

        let pool = PgPoolOptions::new()
            .max_connections(20)
            .connect(&database_url)
            .await?;

        tracing::info!("数据库连接成功!");

        Ok(Database { pool })
    }

    /// 运行数据库迁移
    ///
    /// 规则：
    /// - 使用 `db_migrations` 表记录已执行的脚本名称；
    /// - 按顺序执行 MIGRATIONS 数组中写死的脚本；
    /// - 针对不同环境做兼容处理：
    ///   - 空库（public 下没有任何表）：创建迁移记录表，顺序执行全部 MIGRATIONS；
    ///   - 非空库但不存在迁移记录表：创建迁移记录表，并仅记录 `base.sql` 已执行，然后执行其余 MIGRATIONS；
    ///   - 已存在迁移记录表：按照 MIGRATIONS 顺序执行尚未记录的脚本。
    pub async fn migrate(&self) -> Result<(), sqlx::Error> {
        use sqlx::Row;

        // 1) 检查 public schema 中是否存在任何表，用于识别“空库”
        let table_count: i64 = sqlx::query(
            "SELECT COUNT(*) AS count
             FROM information_schema.tables
             WHERE table_schema = 'public'
               AND table_type = 'BASE TABLE';",
        )
        .fetch_one(&self.pool)
        .await?
        .get::<i64, _>("count");

        let is_empty_database = table_count == 0;

        // 2) 检查迁移记录表是否存在
        let migrations_table_exists: bool = sqlx::query(
            "SELECT EXISTS (
                 SELECT 1
                 FROM information_schema.tables
                 WHERE table_schema = 'public'
                   AND table_name = $1
             ) AS exists;",
        )
        .bind(MIGRATIONS_TABLE)
        .fetch_one(&self.pool)
        .await?
        .get::<bool, _>("exists");

        // 3) 确保迁移记录表存在（在任意场景下都需要）
        self.ensure_migrations_table().await?;

        if is_empty_database {
            // 情况 A：空库（没有任何业务表）
            tracing::warn!(
                "检测到数据库为空: 将按顺序执行基础脚本 {:?} 以及后续迁移脚本",
                MIGRATIONS.iter().map(|(name, _)| *name).collect::<Vec<_>>()
            );

            self.apply_migrations(MIGRATIONS).await?;
            tracing::info!("空库初始化与迁移执行完成");
            return Ok(());
        }

        if !migrations_table_exists {
            // 情况 B：非空库且尚未存在迁移记录表
            // 说明：这是线上已有的旧环境，已经通过原来的 all.sql/base.sql 完成初始化，
            // 此时仅需要补上一条“base.sql 已执行”的记录，然后执行后续迁移脚本。
            tracing::info!(
                "检测到非空数据库且缺少迁移记录表: 将补记录 base.sql 已执行，然后执行后续迁移"
            );

            // 标记 base.sql 已执行（不再重复执行）
            self.insert_migration_record(BASE_MIGRATION_NAME).await?;

            // 执行 base 之后的迁移（若未来追加）
            if MIGRATIONS.len() > 1 {
                self.apply_migrations(&MIGRATIONS[1..]).await?;
            }

            tracing::info!("迁移记录表初始化完成, 后续迁移已同步执行");
            return Ok(());
        }

        // 情况 C：非空库且已有迁移记录表 —— 正常增量迁移
        tracing::info!(
            "检测到已有迁移记录表 {}: 将按顺序执行未完成的迁移脚本",
            MIGRATIONS_TABLE
        );
        self.apply_migrations(MIGRATIONS).await?;
        tracing::info!("数据库迁移已完成");
        Ok(())
    }

    /// 获取连接池
    pub fn pool(&self) -> &PgPool {
        &self.pool
    }
}

impl Database {
    /// 确保迁移记录表存在
    async fn ensure_migrations_table(&self) -> Result<(), sqlx::Error> {
        let create_table_sql = format!(
            "
            CREATE TABLE IF NOT EXISTS {} (
                id SERIAL PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
            ",
            MIGRATIONS_TABLE
        );

        sqlx::query(&create_table_sql).execute(&self.pool).await?;
        Ok(())
    }

    /// 检查指定迁移是否已经执行
    async fn has_migration(&self, name: &str) -> Result<bool, sqlx::Error> {
        use sqlx::Row;

        let exists: bool = sqlx::query(&format!(
            "SELECT EXISTS (
                 SELECT 1 FROM {} WHERE name = $1
             ) AS exists;",
            MIGRATIONS_TABLE
        ))
        .bind(name)
        .fetch_one(&self.pool)
        .await?
        .get::<bool, _>("exists");

        Ok(exists)
    }

    /// 插入迁移执行记录
    async fn insert_migration_record(&self, name: &str) -> Result<(), sqlx::Error> {
        let insert_sql = format!(
            "INSERT INTO {} (name) VALUES ($1) ON CONFLICT (name) DO NOTHING;",
            MIGRATIONS_TABLE
        );
        sqlx::query(&insert_sql)
            .bind(name)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    /// 执行给定列表中的迁移脚本（按顺序）
    async fn apply_migrations(&self, migrations: &[(&str, &str)]) -> Result<(), sqlx::Error> {
        let mut conn = self.pool.acquire().await?;

        for (name, sql) in migrations {
            if self.has_migration(name).await? {
                tracing::info!("跳过已执行的迁移脚本: {}", name);
                continue;
            }

            tracing::info!("开始执行迁移脚本: {}", name);

            for stmt in split_sql_statements(sql) {
                let trimmed = stmt.trim();
                if trimmed.is_empty() {
                    continue;
                }
                sqlx::query(trimmed).execute(&mut *conn).await?;
            }

            self.insert_migration_record(name).await?;
            tracing::info!("迁移脚本执行完成: {}", name);
        }

        Ok(())
    }
}

/// 将包含 DO $$ ... $$、BEGIN/COMMIT、多语句 的 SQL 脚本拆分为顶层语句序列。
fn split_sql_statements(script: &str) -> Vec<String> {
    let chars: Vec<char> = script.chars().collect();
    let mut i = 0usize;
    let n = chars.len();
    let mut stmts = Vec::new();
    let mut current = String::new();

    #[derive(PartialEq)]
    enum State {
        Normal,
        Single,
        Double,
        LineComment,
        BlockComment,
        Dollar(String),
    }
    let mut state = State::Normal;

    while i < n {
        let ch = chars[i];
        match state {
            State::Normal => {
                if ch == '-' && i + 1 < n && chars[i + 1] == '-' {
                    current.push(ch);
                    current.push(chars[i + 1]);
                    i += 2;
                    state = State::LineComment;
                    continue;
                }
                if ch == '/' && i + 1 < n && chars[i + 1] == '*' {
                    current.push(ch);
                    current.push(chars[i + 1]);
                    i += 2;
                    state = State::BlockComment;
                    continue;
                }
                if ch == '\'' {
                    current.push(ch);
                    i += 1;
                    state = State::Single;
                    continue;
                }
                if ch == '"' {
                    current.push(ch);
                    i += 1;
                    state = State::Double;
                    continue;
                }
                if ch == '$' {
                    // 捕获 $tag$
                    let mut j = i + 1;
                    while j < n && chars[j] != '$' {
                        j += 1;
                    }
                    if j < n && chars[j] == '$' {
                        // 形成了 $...$
                        let delim: String = chars[i..=j].iter().collect();
                        current.push_str(&delim);
                        i = j + 1;
                        state = State::Dollar(delim);
                        continue;
                    } else {
                        // 单独的 '$' 按普通字符处理
                        current.push(ch);
                        i += 1;
                        continue;
                    }
                }
                if ch == ';' {
                    let stmt = current.trim();
                    if !stmt.is_empty() {
                        stmts.push(format!("{};", stmt));
                    }
                    current.clear();
                    i += 1;
                } else {
                    current.push(ch);
                    i += 1;
                }
            }
            State::Single => {
                current.push(ch);
                i += 1;
                if ch == '\'' {
                    if i < n && chars[i] == '\'' {
                        current.push('\'');
                        i += 1;
                    } else {
                        state = State::Normal;
                    }
                }
            }
            State::Double => {
                current.push(ch);
                i += 1;
                if ch == '"' {
                    state = State::Normal;
                }
            }
            State::LineComment => {
                current.push(ch);
                i += 1;
                if ch == '\n' {
                    state = State::Normal;
                }
            }
            State::BlockComment => {
                current.push(ch);
                i += 1;
                if ch == '*' && i < n && chars[i] == '/' {
                    current.push('/');
                    i += 1;
                    state = State::Normal;
                }
            }
            State::Dollar(ref delim) => {
                // 复制字符直到再次遇到 delim
                if ch == delim.chars().next().unwrap_or('$') {
                    // 可能的闭合，尝试匹配
                    let m = delim.len();
                    if i + m <= n {
                        let candidate: String = chars[i..i + m].iter().collect();
                        if &candidate == delim {
                            current.push_str(&candidate);
                            i += m;
                            state = State::Normal;
                            continue;
                        }
                    }
                }
                current.push(ch);
                i += 1;
            }
        }
    }

    let tail = current.trim();
    if !tail.is_empty() {
        stmts.push(tail.to_string());
    }
    stmts
}

pub mod version_store;
