use sqlx::{postgres::PgPoolOptions, Acquire, Executor, PgPool, Postgres, Row};
use std::env;

pub mod account_store;
pub mod document_store;
pub mod emoji_pack_store;
pub mod file_upload_multipart_store;
pub mod file_upload_store;
pub mod friend_store;
pub mod group_management_store;
pub mod member_with_user_info;
pub mod message_read_store;
pub mod message_store;
pub mod models;
pub mod report_store;
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

/// 数据库迁移全局互斥锁（PostgreSQL advisory lock），避免多实例并发执行迁移导致冲突。
///
/// 注意：advisory lock 是“会话级”锁，必须在迁移结束后显式释放，否则连接复用会导致锁长期占用。
const MIGRATION_ADVISORY_LOCK_KEY: i64 = 0x7265_6463_6f64_65; // "redcode"

/// 基础初始化脚本（base.sql）
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
    // 2025-12-09：为贴纸与表情项增加 COS 对象键字段
    (
        "20251209123000_add_emoji_object_keys.sql",
        include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/sql/migrations/20251209123000_add_emoji_object_keys.sql"
        )),
    ),
    // 2025-12-11：创建统一文件上传记录表，用于管理 COS 直传文件及去重
    (
        "20251211120000_create_file_upload_records.sql",
        include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/sql/migrations/20251211120000_create_file_upload_records.sql"
        )),
    ),
    // 2025-12-15：为版本管理增加 App Store 链接字段（iOS/macOS 两种发布入口）
    (
        "20251215120000_add_app_store_url_to_app_versions.sql",
        include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/sql/migrations/20251215120000_add_app_store_url_to_app_versions.sql"
        )),
    ),
    // 2025-12-18：举报（群聊/用户）与截图附件记录表
    (
        "20251218120000_create_reports.sql",
        include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/sql/migrations/20251218120000_create_reports.sql"
        )),
    ),
    // 2025-12-19：大文件分片直传会话表（COS Multipart Upload）
    (
        "20251219120000_create_file_upload_multipart_sessions.sql",
        include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/sql/migrations/20251219120000_create_file_upload_multipart_sessions.sql"
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
        let mut conn = self.pool.acquire().await?;

        tracing::info!("正在获取数据库迁移锁...");
        acquire_migration_lock(&mut conn).await?;
        tracing::info!("数据库迁移锁已获取");

        let result = self.migrate_with_conn(&mut conn).await;

        // 必须释放锁，避免连接复用导致锁长期占用
        release_migration_lock(&mut conn).await;

        result
    }

    async fn migrate_with_conn(
        &self,
        conn: &mut sqlx::pool::PoolConnection<Postgres>,
    ) -> Result<(), sqlx::Error> {
        // 预检：确保数据库具备必要的 UUID 生成能力（base.sql / migrations 中大量使用 gen_random_uuid()）
        if let Err(e) = sqlx::query("SELECT gen_random_uuid();")
            .execute(&mut **conn)
            .await
        {
            tracing::error!(
                "数据库缺少 gen_random_uuid()，通常需要启用 pgcrypto 扩展：CREATE EXTENSION IF NOT EXISTS pgcrypto;"
            );
            return Err(e);
        }

        // 1) 检查 public schema 中是否存在任何表，用于识别“空库”
        let table_count: i64 = sqlx::query(
            "SELECT COUNT(*) AS count
             FROM information_schema.tables
             WHERE table_schema = 'public'
               AND table_type = 'BASE TABLE';",
        )
        .fetch_one(&mut **conn)
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
        .fetch_one(&mut **conn)
        .await?
        .get::<bool, _>("exists");

        // 3) 确保迁移记录表存在（在任意场景下都需要）
        self.ensure_migrations_table(&mut **conn).await?;

        if is_empty_database {
            // 情况 A：空库（没有任何业务表）
            tracing::warn!(
                "检测到数据库为空: 将按顺序执行基础脚本 {:?} 以及后续迁移脚本",
                MIGRATIONS.iter().map(|(name, _)| *name).collect::<Vec<_>>()
            );

            self.apply_migrations(conn, MIGRATIONS).await?;
            tracing::info!("空库初始化与迁移执行完成");
            return Ok(());
        }

        if !migrations_table_exists {
            // 情况 B：非空库且尚未存在迁移记录表
            // 说明：这是线上已有的旧环境，已经通过基线脚本完成初始化，
            // 此时仅需要补上一条“base.sql 已执行”的记录，然后执行后续迁移脚本。
            tracing::info!(
                "检测到非空数据库且缺少迁移记录表: 将补记录 base.sql 已执行，然后执行后续迁移"
            );

            // 标记 base.sql 已执行（不再重复执行）
            self.insert_migration_record(&mut **conn, BASE_MIGRATION_NAME)
                .await?;

            // 执行 base 之后的迁移（若未来追加）
            if MIGRATIONS.len() > 1 {
                self.apply_migrations(conn, &MIGRATIONS[1..]).await?;
            }

            tracing::info!("迁移记录表初始化完成, 后续迁移已同步执行");
            return Ok(());
        }

        // 情况 C：非空库且已有迁移记录表 —— 正常增量迁移
        tracing::info!(
            "检测到已有迁移记录表 {}: 将按顺序执行未完成的迁移脚本",
            MIGRATIONS_TABLE
        );
        self.apply_migrations(conn, MIGRATIONS).await?;
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
    async fn ensure_migrations_table<'e, E>(&self, executor: E) -> Result<(), sqlx::Error>
    where
        E: Executor<'e, Database = Postgres>,
    {
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

        sqlx::query(&create_table_sql).execute(executor).await?;
        Ok(())
    }

    /// 检查指定迁移是否已经执行
    async fn has_migration<'e, E>(&self, executor: E, name: &str) -> Result<bool, sqlx::Error>
    where
        E: Executor<'e, Database = Postgres>,
    {
        let exists: bool = sqlx::query(&format!(
            "SELECT EXISTS (
                 SELECT 1 FROM {} WHERE name = $1
             ) AS exists;",
            MIGRATIONS_TABLE
        ))
        .bind(name)
        .fetch_one(executor)
        .await?
        .get::<bool, _>("exists");

        Ok(exists)
    }

    /// 插入迁移执行记录
    async fn insert_migration_record<'e, E>(
        &self,
        executor: E,
        name: &str,
    ) -> Result<(), sqlx::Error>
    where
        E: Executor<'e, Database = Postgres>,
    {
        let insert_sql = format!(
            "INSERT INTO {} (name) VALUES ($1) ON CONFLICT (name) DO NOTHING;",
            MIGRATIONS_TABLE
        );
        sqlx::query(&insert_sql)
            .bind(name)
            .execute(executor)
            .await?;
        Ok(())
    }

    /// 执行给定列表中的迁移脚本（按顺序）
    async fn apply_migrations(
        &self,
        conn: &mut sqlx::pool::PoolConnection<Postgres>,
        migrations: &[(&str, &str)],
    ) -> Result<(), sqlx::Error> {
        for (name, sql) in migrations {
            if self.has_migration(&mut **conn, name).await? {
                tracing::info!("跳过已执行的迁移脚本: {}", name);
                continue;
            }

            let mut tx = conn.begin().await?;

            let migrate_result: Result<bool, sqlx::Error> = async {
                // 二次校验：即使拿到迁移锁，也避免“手工插入迁移记录”导致的重复执行
                if self.has_migration(&mut *tx, name).await? {
                    return Ok(false);
                }

                tracing::info!("开始执行迁移脚本: {}", name);

                for stmt in split_sql_statements(sql) {
                    if is_transaction_control_statement(&stmt) {
                        continue;
                    }

                    let trimmed = stmt.trim();
                    if trimmed.is_empty() {
                        continue;
                    }
                    sqlx::query(trimmed).execute(&mut *tx).await?;
                }

                self.insert_migration_record(&mut *tx, name).await?;
                Ok(true)
            }
            .await;

            match migrate_result {
                Ok(false) => {
                    let _ = tx.rollback().await;
                    tracing::info!("跳过已执行的迁移脚本: {}", name);
                }
                Ok(true) => {
                    tx.commit().await?;
                    tracing::info!("迁移脚本执行完成: {}", name);
                }
                Err(e) => {
                    let _ = tx.rollback().await;
                    return Err(e);
                }
            }
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

async fn acquire_migration_lock(
    conn: &mut sqlx::pool::PoolConnection<Postgres>,
) -> Result<(), sqlx::Error> {
    sqlx::query("SELECT pg_advisory_lock($1);")
        .bind(MIGRATION_ADVISORY_LOCK_KEY)
        .execute(&mut **conn)
        .await?;
    Ok(())
}

async fn release_migration_lock(conn: &mut sqlx::pool::PoolConnection<Postgres>) {
    let _ = sqlx::query("SELECT pg_advisory_unlock($1);")
        .bind(MIGRATION_ADVISORY_LOCK_KEY)
        .execute(&mut **conn)
        .await;
}

fn is_transaction_control_statement(stmt: &str) -> bool {
    let trimmed = strip_leading_sql_comments(stmt)
        .trim()
        .trim_end_matches(';')
        .trim();
    trimmed.eq_ignore_ascii_case("BEGIN") || trimmed.eq_ignore_ascii_case("COMMIT")
}

fn strip_leading_sql_comments(stmt: &str) -> &str {
    let mut s = stmt.trim_start();
    loop {
        if let Some(rest) = s.strip_prefix("--") {
            s = match rest.find('\n') {
                Some(pos) => &rest[pos + 1..],
                None => "",
            };
            s = s.trim_start();
            continue;
        }

        if let Some(rest) = s.strip_prefix("/*") {
            s = match rest.find("*/") {
                Some(pos) => &rest[pos + 2..],
                None => "",
            };
            s = s.trim_start();
            continue;
        }

        break;
    }
    s
}

pub mod version_store;
