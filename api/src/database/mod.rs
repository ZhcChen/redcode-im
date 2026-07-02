use sha2::{Digest, Sha256};
use sqlx::{postgres::PgPoolOptions, Acquire, Executor, PgPool, Postgres, Row};
use std::{env, time::Duration};

pub mod account_store;
pub mod admin_rbac_store;
pub mod document_store;
pub mod e2ee_key_store;
pub mod emoji_pack_store;
pub mod file_upload_audit_store;
pub mod file_upload_multipart_store;
pub mod file_upload_store;
pub mod friend_store;
pub mod group_management_store;
pub mod member_with_user_info;
pub mod message_reaction_store;
pub mod message_read_store;
pub mod message_store;
pub mod models;
pub mod object_storage_config_store;
pub mod push_device_store;
pub mod push_job_store;
pub mod push_log_store;
pub mod push_provider_config_store;
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
const MIGRATIONS_TABLE_FQN: &str = "public.db_migrations";

/// 数据库迁移全局互斥锁（PostgreSQL advisory lock），避免多实例并发执行迁移导致冲突。
///
/// 注意：advisory lock 是“会话级”锁，必须在迁移结束后显式释放，否则连接复用会导致锁长期占用。
const MIGRATION_ADVISORY_LOCK_KEY: i64 = 0x7265_6463_6f64_65; // "redcode"

const DEFAULT_DATABASE_MAX_CONNECTIONS: u32 = 20;
const DEFAULT_DATABASE_MIN_CONNECTIONS: u32 = 0;
const DEFAULT_DATABASE_ACQUIRE_TIMEOUT_SECONDS: u64 = 30;

/// 基础初始化脚本（base.sql）
const BASE_MIGRATION_NAME: &str = "base.sql";
const BASE_MIGRATION_SQL: &str = include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/sql/base.sql"));
const MIGRATION_ADOPT_ENV: &str = "ALLOW_INSECURE_MIGRATION_BASELINE_ADOPT";

/// 按执行顺序写死的迁移脚本列表
///
/// 说明：
/// - 第一个必须是基础脚本 `base.sql`，用于初始化全新数据库；
/// - 2026-06-09 整合重置：历史增量迁移已折叠进 base.sql；
/// - 后续若有新增迁移，请按时间顺序追加到此数组中（additive-only，由 `make migration.guard` 强制）；
const MIGRATIONS: &[(&str, &str)] = &[
    // 基础初始化脚本（已整合历史增量）
    (BASE_MIGRATION_NAME, BASE_MIGRATION_SQL),
];

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DatabasePoolConfig {
    pub max_connections: u32,
    pub min_connections: u32,
    pub acquire_timeout: Duration,
}

impl Default for DatabasePoolConfig {
    fn default() -> Self {
        Self {
            max_connections: DEFAULT_DATABASE_MAX_CONNECTIONS,
            min_connections: DEFAULT_DATABASE_MIN_CONNECTIONS,
            acquire_timeout: Duration::from_secs(DEFAULT_DATABASE_ACQUIRE_TIMEOUT_SECONDS),
        }
    }
}

impl DatabasePoolConfig {
    pub fn from_env() -> Self {
        let max_connections = read_positive_u32_alias(
            &[
                "DATABASE_MAX_CONNECTIONS",
                "DATABASE_POOL_MAX_CONNECTIONS",
                "PG_POOL_MAX",
            ],
            DEFAULT_DATABASE_MAX_CONNECTIONS,
        );
        let min_connections = read_positive_u32_alias(
            &[
                "DATABASE_MIN_CONNECTIONS",
                "DATABASE_POOL_MIN_CONNECTIONS",
                "PG_POOL_MIN",
            ],
            DEFAULT_DATABASE_MIN_CONNECTIONS,
        )
        .min(max_connections);
        let acquire_timeout_seconds = read_positive_u64_alias(
            &[
                "DATABASE_ACQUIRE_TIMEOUT_SECONDS",
                "DATABASE_POOL_ACQUIRE_TIMEOUT_SECONDS",
                "PG_POOL_ACQUIRE_TIMEOUT_SECONDS",
            ],
            DEFAULT_DATABASE_ACQUIRE_TIMEOUT_SECONDS,
        );

        Self {
            max_connections,
            min_connections,
            acquire_timeout: Duration::from_secs(acquire_timeout_seconds),
        }
    }

    fn apply_to(&self, options: PgPoolOptions) -> PgPoolOptions {
        options
            .max_connections(self.max_connections)
            .min_connections(self.min_connections)
            .acquire_timeout(self.acquire_timeout)
    }
}

#[derive(Debug, Clone)]
struct MigrationRecord {
    checksum: Option<String>,
}

impl Database {
    /// 创建数据库连接池
    pub async fn new() -> Result<Self, sqlx::Error> {
        dotenvy::dotenv().ok();

        let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
        let pool_config = DatabasePoolConfig::from_env();

        tracing::info!(
            "正在连接数据库: {} (pool max={}, min={}, acquire_timeout={}s)",
            database_url,
            pool_config.max_connections,
            pool_config.min_connections,
            pool_config.acquire_timeout.as_secs()
        );

        let pool = pool_config
            .apply_to(PgPoolOptions::new())
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
    ///   - 非空库但不存在迁移记录表：默认拒绝自动 adopt；仅在显式环境变量开启时，做结构校验后补记 `base.sql`；
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
            tracing::warn!(
                "数据库缺少 gen_random_uuid()，尝试自动启用 pgcrypto 扩展（需要具备 CREATE EXTENSION 权限）: {}",
                e
            );

            // 尝试自动启用 pgcrypto（适配“全新数据库/刚删库”的开发环境）
            // 说明：若权限不足或扩展不可用，则会继续返回原始错误，提示手工处理。
            let create_result = sqlx::query("CREATE EXTENSION IF NOT EXISTS pgcrypto;")
                .execute(&mut **conn)
                .await;
            match create_result {
                Ok(_) => tracing::info!("pgcrypto 扩展已启用（或已存在）"),
                Err(create_err) => {
                    tracing::error!(
                        "自动启用 pgcrypto 扩展失败，请手工执行：CREATE EXTENSION IF NOT EXISTS pgcrypto; error={}",
                        create_err
                    );
                    return Err(e);
                }
            }

            // 二次验证
            if let Err(e2) = sqlx::query("SELECT gen_random_uuid();")
                .execute(&mut **conn)
                .await
            {
                tracing::error!(
                    "pgcrypto 启用后仍无法使用 gen_random_uuid()，请检查扩展安装状态与权限: {}",
                    e2
                );
                return Err(e2);
            }
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
            if !allow_insecure_migration_baseline_adopt() {
                return Err(migration_protocol_error(format!(
                    "检测到非空数据库但缺少迁移记录表 {}。默认拒绝自动 adopt，\
请重建数据库；若确认该库已是当前完整 schema，可临时设置环境变量 {}=true 后重试。",
                    MIGRATIONS_TABLE, MIGRATION_ADOPT_ENV
                )));
            }

            tracing::warn!(
                "检测到非空数据库且缺少迁移记录表，但已显式启用 {}。开始校验当前 schema 是否可安全 adopt。",
                MIGRATION_ADOPT_ENV
            );
            ensure_database_matches_current_baseline(&mut **conn).await?;

            tracing::info!("结构校验通过：补记当前迁移链已执行");
            for (name, sql) in MIGRATIONS {
                self.insert_migration_record(&mut **conn, name, &migration_checksum(sql))
                    .await?;
            }

            tracing::info!("迁移记录表已建立，当前数据库已 adopt 为最新基线");
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
    async fn ensure_migrations_table(
        &self,
        executor: &mut sqlx::PgConnection,
    ) -> Result<(), sqlx::Error> {
        let create_table_sql = format!(
            "
            CREATE TABLE IF NOT EXISTS {} (
                id SERIAL PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                checksum TEXT,
                applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
            ",
            MIGRATIONS_TABLE_FQN
        );

        sqlx::query(&create_table_sql)
            .execute(&mut *executor)
            .await?;
        sqlx::query(&format!(
            "ALTER TABLE {} ADD COLUMN IF NOT EXISTS checksum TEXT;",
            MIGRATIONS_TABLE_FQN
        ))
        .execute(&mut *executor)
        .await?;
        Ok(())
    }

    /// 获取指定迁移记录
    async fn get_migration_record<'e, E>(
        &self,
        executor: E,
        name: &str,
    ) -> Result<Option<MigrationRecord>, sqlx::Error>
    where
        E: Executor<'e, Database = Postgres>,
    {
        let row = sqlx::query(&format!(
            "SELECT checksum
             FROM {}
             WHERE name = $1
             LIMIT 1;",
            MIGRATIONS_TABLE_FQN
        ))
        .bind(name)
        .fetch_optional(executor)
        .await?;

        Ok(row.map(|row| MigrationRecord {
            checksum: row.try_get::<Option<String>, _>("checksum").unwrap_or(None),
        }))
    }

    async fn update_migration_checksum<'e, E>(
        &self,
        executor: E,
        name: &str,
        checksum: &str,
    ) -> Result<(), sqlx::Error>
    where
        E: Executor<'e, Database = Postgres>,
    {
        let update_sql = format!(
            "UPDATE {} SET checksum = $2 WHERE name = $1;",
            MIGRATIONS_TABLE_FQN
        );
        sqlx::query(&update_sql)
            .bind(name)
            .bind(checksum)
            .execute(executor)
            .await?;
        Ok(())
    }

    /// 插入迁移执行记录
    async fn insert_migration_record<'e, E>(
        &self,
        executor: E,
        name: &str,
        checksum: &str,
    ) -> Result<(), sqlx::Error>
    where
        E: Executor<'e, Database = Postgres>,
    {
        let insert_sql = format!(
            "INSERT INTO {} (name, checksum) VALUES ($1, $2)
             ON CONFLICT (name) DO UPDATE SET checksum = EXCLUDED.checksum;",
            MIGRATIONS_TABLE_FQN
        );
        sqlx::query(&insert_sql)
            .bind(name)
            .bind(checksum)
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
            let checksum = migration_checksum(sql);

            if let Some(record) = self.get_migration_record(&mut **conn, name).await? {
                ensure_migration_record_checksum(
                    self,
                    &mut **conn,
                    name,
                    &checksum,
                    record.checksum.as_deref(),
                )
                .await?;
                tracing::info!("跳过已执行的迁移脚本: {}", name);
                continue;
            }

            let mut tx = conn.begin().await?;

            let migrate_result: Result<bool, sqlx::Error> = async {
                // 二次校验：即使拿到迁移锁，也避免“手工插入迁移记录”导致的重复执行
                if let Some(record) = self.get_migration_record(&mut *tx, name).await? {
                    ensure_migration_record_checksum(
                        self,
                        &mut *tx,
                        name,
                        &checksum,
                        record.checksum.as_deref(),
                    )
                    .await?;
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

                self.insert_migration_record(&mut *tx, name, &checksum)
                    .await?;
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

async fn ensure_migration_record_checksum<'e, E>(
    db: &Database,
    executor: E,
    name: &str,
    expected_checksum: &str,
    existing_checksum: Option<&str>,
) -> Result<(), sqlx::Error>
where
    E: Executor<'e, Database = Postgres>,
{
    match existing_checksum {
        Some(checksum) if checksum == expected_checksum => Ok(()),
        Some(checksum) => Err(migration_protocol_error(format!(
            "迁移脚本 {} 的 checksum 不匹配：数据库记录为 {}，当前文件为 {}。请检查是否有人修改了已发布 migration。",
            name, checksum, expected_checksum
        ))),
        None => {
            db.update_migration_checksum(executor, name, expected_checksum)
                .await?;
            Ok(())
        }
    }
}

fn migration_checksum(sql: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(sql.as_bytes());
    hex::encode(hasher.finalize())
}

fn allow_insecure_migration_baseline_adopt() -> bool {
    matches!(
        env::var(MIGRATION_ADOPT_ENV)
            .unwrap_or_default()
            .trim()
            .to_ascii_lowercase()
            .as_str(),
        "1" | "true" | "yes" | "on"
    )
}

fn migration_protocol_error(message: impl Into<String>) -> sqlx::Error {
    sqlx::Error::Protocol(message.into())
}

fn read_positive_u32_alias(names: &[&str], default: u32) -> u32 {
    names
        .iter()
        .find_map(|name| {
            env::var(name)
                .ok()
                .and_then(|value| value.trim().parse::<u32>().ok())
                .filter(|value| *value > 0)
        })
        .unwrap_or(default)
}

fn read_positive_u64_alias(names: &[&str], default: u64) -> u64 {
    names
        .iter()
        .find_map(|name| {
            env::var(name)
                .ok()
                .and_then(|value| value.trim().parse::<u64>().ok())
                .filter(|value| *value > 0)
        })
        .unwrap_or(default)
}

async fn ensure_database_matches_current_baseline(
    executor: &mut sqlx::PgConnection,
) -> Result<(), sqlx::Error> {
    const REQUIRED_TABLES: &[&str] = &[
        "admin_users",
        "users",
        "rooms",
        "messages",
        "storage_providers",
        "file_upload_records",
        "reports",
        "file_upload_multipart_sessions",
        "system_logs",
        "file_upload_audit_tasks",
        "message_reactions",
        "push_devices",
        "push_provider_configs",
        "push_logs",
        "push_job_queue",
        "e2ee_identity_keys",
        "object_storage_configs",
    ];
    const REQUIRED_VIEWS: &[&str] = &["group_detail_view"];
    const REQUIRED_COLUMNS: &[(&str, &str)] = &[
        ("messages", "edited_at"),
        ("messages", "encrypted_content"),
        ("messages", "encryption_metadata"),
        ("app_versions", "app_store_url"),
        ("emoji_packs", "icon_object_key"),
        ("emoji_items", "image_object_key"),
    ];

    let mut missing = Vec::new();

    for table in REQUIRED_TABLES {
        if !table_exists(executor, table).await? {
            missing.push(format!("table:{table}"));
        }
    }

    for view in REQUIRED_VIEWS {
        if !view_exists(executor, view).await? {
            missing.push(format!("view:{view}"));
        }
    }

    for (table, column) in REQUIRED_COLUMNS {
        if !column_exists(executor, table, column).await? {
            missing.push(format!("column:{table}.{column}"));
        }
    }

    if missing.is_empty() {
        return Ok(());
    }

    Err(migration_protocol_error(format!(
        "当前数据库缺少最新基线要求的对象，不能通过 {} 自动 adopt：{}。请重建数据库或手工补齐结构。",
        MIGRATION_ADOPT_ENV,
        missing.join(", ")
    )))
}

async fn table_exists(executor: &mut sqlx::PgConnection, table: &str) -> Result<bool, sqlx::Error> {
    let exists: bool = sqlx::query(
        "SELECT EXISTS (
             SELECT 1
             FROM information_schema.tables
             WHERE table_schema = 'public'
               AND table_name = $1
               AND table_type = 'BASE TABLE'
         ) AS exists;",
    )
    .bind(table)
    .fetch_one(&mut *executor)
    .await?
    .get("exists");

    Ok(exists)
}

async fn view_exists(executor: &mut sqlx::PgConnection, view: &str) -> Result<bool, sqlx::Error> {
    let exists: bool = sqlx::query(
        "SELECT EXISTS (
             SELECT 1
             FROM information_schema.views
             WHERE table_schema = 'public'
               AND table_name = $1
         ) AS exists;",
    )
    .bind(view)
    .fetch_one(&mut *executor)
    .await?
    .get("exists");

    Ok(exists)
}

async fn column_exists(
    executor: &mut sqlx::PgConnection,
    table: &str,
    column: &str,
) -> Result<bool, sqlx::Error> {
    let exists: bool = sqlx::query(
        "SELECT EXISTS (
             SELECT 1
             FROM information_schema.columns
             WHERE table_schema = 'public'
               AND table_name = $1
               AND column_name = $2
         ) AS exists;",
    )
    .bind(table)
    .bind(column)
    .fetch_one(&mut *executor)
    .await?
    .get("exists");

    Ok(exists)
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::sync::{Mutex, OnceLock};

    const POOL_ENV_NAMES: &[&str] = &[
        "DATABASE_MAX_CONNECTIONS",
        "DATABASE_POOL_MAX_CONNECTIONS",
        "PG_POOL_MAX",
        "DATABASE_MIN_CONNECTIONS",
        "DATABASE_POOL_MIN_CONNECTIONS",
        "PG_POOL_MIN",
        "DATABASE_ACQUIRE_TIMEOUT_SECONDS",
        "DATABASE_POOL_ACQUIRE_TIMEOUT_SECONDS",
        "PG_POOL_ACQUIRE_TIMEOUT_SECONDS",
    ];

    fn env_lock() -> &'static Mutex<()> {
        static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        LOCK.get_or_init(|| Mutex::new(()))
    }

    struct EnvGuard {
        saved: Vec<(&'static str, Option<String>)>,
    }

    impl EnvGuard {
        fn apply(entries: &[(&'static str, Option<&str>)]) -> Self {
            let mut saved = Vec::with_capacity(POOL_ENV_NAMES.len());
            for name in POOL_ENV_NAMES {
                saved.push((*name, env::var(name).ok()));
                env::remove_var(name);
            }

            for (name, value) in entries {
                match value {
                    Some(value) => env::set_var(name, value),
                    None => env::remove_var(name),
                }
            }

            Self { saved }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            for (name, value) in &self.saved {
                match value {
                    Some(value) => env::set_var(name, value),
                    None => env::remove_var(name),
                }
            }
        }
    }

    #[test]
    fn database_pool_config_uses_safe_defaults() {
        let _lock = env_lock().lock().expect("env lock poisoned");
        let _guard = EnvGuard::apply(&[]);

        assert_eq!(
            DatabasePoolConfig::from_env(),
            DatabasePoolConfig::default()
        );
    }

    #[test]
    fn database_pool_config_reads_primary_env_names() {
        let _lock = env_lock().lock().expect("env lock poisoned");
        let _guard = EnvGuard::apply(&[
            ("DATABASE_MAX_CONNECTIONS", Some("80")),
            ("DATABASE_MIN_CONNECTIONS", Some("8")),
            ("DATABASE_ACQUIRE_TIMEOUT_SECONDS", Some("5")),
        ]);

        let config = DatabasePoolConfig::from_env();
        assert_eq!(config.max_connections, 80);
        assert_eq!(config.min_connections, 8);
        assert_eq!(config.acquire_timeout, Duration::from_secs(5));
    }

    #[test]
    fn database_pool_config_supports_aliases_and_clamps_min_to_max() {
        let _lock = env_lock().lock().expect("env lock poisoned");
        let _guard = EnvGuard::apply(&[
            ("PG_POOL_MAX", Some("16")),
            ("PG_POOL_MIN", Some("32")),
            ("PG_POOL_ACQUIRE_TIMEOUT_SECONDS", Some("9")),
        ]);

        let config = DatabasePoolConfig::from_env();
        assert_eq!(config.max_connections, 16);
        assert_eq!(config.min_connections, 16);
        assert_eq!(config.acquire_timeout, Duration::from_secs(9));
    }

    #[test]
    fn database_pool_config_ignores_invalid_values() {
        let _lock = env_lock().lock().expect("env lock poisoned");
        let _guard = EnvGuard::apply(&[
            ("DATABASE_MAX_CONNECTIONS", Some("0")),
            ("DATABASE_MIN_CONNECTIONS", Some("not-a-number")),
            ("DATABASE_ACQUIRE_TIMEOUT_SECONDS", Some("-1")),
        ]);

        assert_eq!(
            DatabasePoolConfig::from_env(),
            DatabasePoolConfig::default()
        );
    }

    #[test]
    fn split_sql_statements_keeps_dollar_quoted_function_body_intact() {
        let sql = r#"
        CREATE FUNCTION demo() RETURNS void AS $$
        BEGIN
            PERFORM 1;
            PERFORM 2;
        END;
        $$ LANGUAGE plpgsql;

        CREATE TABLE demo_table (id INT);
        "#;

        let statements = split_sql_statements(sql);
        assert_eq!(statements.len(), 2);
        assert!(statements[0].contains("PERFORM 1;"));
        assert!(statements[0].contains("PERFORM 2;"));
        assert!(statements[1].contains("CREATE TABLE demo_table"));
    }

    #[test]
    fn migration_manifest_matches_current_migrations_directory() {
        let mut manifest_names = MIGRATIONS
            .iter()
            .skip(1)
            .map(|(name, _)| (*name).to_string())
            .collect::<Vec<_>>();
        manifest_names.sort();

        let migrations_dir =
            std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("sql/migrations");
        let mut filesystem_names = fs::read_dir(migrations_dir)
            .unwrap()
            .filter_map(|entry| {
                let entry = entry.ok()?;
                let path = entry.path();
                if path.extension().and_then(|ext| ext.to_str()) != Some("sql") {
                    return None;
                }
                path.file_name()
                    .and_then(|name| name.to_str())
                    .map(|name| name.to_string())
            })
            .collect::<Vec<_>>();
        filesystem_names.sort();

        assert_eq!(manifest_names, filesystem_names);
    }

    #[test]
    fn migration_checksum_is_stable() {
        let sql = "CREATE TABLE demo (id INT);";
        assert_eq!(migration_checksum(sql), migration_checksum(sql));
    }
}

pub mod version_store;
