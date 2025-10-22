use sqlx::{postgres::PgPoolOptions, PgPool};
use std::env;

pub mod document_store;
pub mod friend_store;
pub mod message_read_store;
pub mod message_store;
pub mod models;
pub mod room_store;
pub mod settings_store;
pub mod user_store;

/// 数据库连接池
#[derive(Clone)]
pub struct Database {
    pub pool: PgPool,
}

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
    /// - 若检测到基础表不存在（空库），自动执行全量初始化脚本 `backend/sql/all.sql`；
    /// - 否则，仅在缺失列或索引时应用幂等补丁脚本；
    /// - 两类脚本都使用同一数据库连接顺序执行，兼容 DO $$ 与 BEGIN/COMMIT；
    pub async fn migrate(&self) -> Result<(), sqlx::Error> {
        use sqlx::Row;

        // 1) 检查是否为空库（至少判断 users/rooms/messages 三张核心表）
        let base_tables_exist: bool = sqlx::query(
            "SELECT (
                 EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='users')
              OR EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='rooms')
              OR EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='messages')
            ) AS exists;",
        )
        .fetch_one(&self.pool)
        .await?
        .get::<bool, _>("exists");

        if !base_tables_exist {
            tracing::warn!("检测到数据库为空：将执行全量初始化脚本 all.sql");

            const ALL_SQL: &str = include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/sql/all.sql"));
            let mut conn = self.pool.acquire().await?;
            for stmt in split_sql_statements(ALL_SQL) {
                // 避免执行空语句
                if stmt.trim().is_empty() {
                    continue;
                }
                sqlx::query(&stmt).execute(&mut *conn).await?;
            }
            tracing::info!("全量初始化脚本执行完成");
            return Ok(());
        }

        // 2) 仅应用必要的补丁
        let room_type_exists: bool = sqlx::query(
            "SELECT EXISTS (
                 SELECT 1
                 FROM information_schema.columns
                 WHERE table_schema = 'public'
                   AND table_name = 'rooms'
                   AND column_name = 'room_type'
             ) AS exists;",
        )
        .fetch_one(&self.pool)
        .await?
        .get::<bool, _>("exists");

        let mr_unique_exists: bool = sqlx::query(
            "SELECT EXISTS (
                 SELECT 1 FROM pg_indexes
                 WHERE schemaname = 'public'
                   AND tablename  = 'message_reads'
                   AND indexname  = 'idx_message_reads_unique_message_user'
             ) AS exists;",
        )
        .fetch_one(&self.pool)
        .await?
        .get::<bool, _>("exists");

        if room_type_exists && mr_unique_exists {
            tracing::info!("数据库结构校验通过：无需变更");
            return Ok(());
        }

        tracing::warn!(
            "检测到数据库结构缺失：room_type={} unique_idx={}; 即将应用修复SQL",
            room_type_exists,
            mr_unique_exists
        );

        const PATCH_SQL: &str = include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/sql/20251020103045_fix_room_schema_and_message_reads.sql"
        ));

        // 使用同一连接，保证脚本中的 BEGIN/COMMIT 生效
        let mut conn = self.pool.acquire().await?;
        for stmt in split_sql_statements(PATCH_SQL) {
            if stmt.trim().is_empty() {
                continue;
            }
            sqlx::query(&stmt).execute(&mut *conn).await?;
        }

        tracing::info!("数据库结构修复完成");
        Ok(())
    }

    /// 获取连接池
    pub fn pool(&self) -> &PgPool {
        &self.pool
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
