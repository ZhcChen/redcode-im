use redcode_im_api::Database;
use sqlx::PgPool;
use std::env;
use uuid::Uuid;

const ADOPT_ENV: &str = "ALLOW_INSECURE_MIGRATION_BASELINE_ADOPT";
const EXPECTED_MIGRATION_COUNT: i64 = 7;

static ENV_LOCK: once_cell::sync::Lazy<tokio::sync::Mutex<()>> =
    once_cell::sync::Lazy::new(|| tokio::sync::Mutex::new(()));

struct EnvGuard {
    key: &'static str,
    previous: Option<String>,
}

impl EnvGuard {
    fn set(key: &'static str, value: &str) -> Self {
        let previous = env::var(key).ok();
        env::set_var(key, value);
        Self { key, previous }
    }
}

impl Drop for EnvGuard {
    fn drop(&mut self) {
        if let Some(value) = &self.previous {
            env::set_var(self.key, value);
        } else {
            env::remove_var(self.key);
        }
    }
}

struct TempDatabase {
    admin_url: String,
    url: String,
    name: String,
}

impl TempDatabase {
    async fn create() -> Result<Self, Box<dyn std::error::Error>> {
        let base_url = env::var("DATABASE_URL")?;
        let (prefix, _) = base_url
            .rsplit_once('/')
            .ok_or("DATABASE_URL 缺少数据库名")?;
        let admin_url = format!("{prefix}/postgres");
        let name = format!("migration_smoke_{}", Uuid::new_v4().simple());
        let url = format!("{prefix}/{name}");

        let admin_pool = PgPool::connect(&admin_url).await?;
        sqlx::query(&format!(r#"CREATE DATABASE "{}""#, name))
            .execute(&admin_pool)
            .await?;
        admin_pool.close().await;

        Ok(Self {
            admin_url,
            url,
            name,
        })
    }

    async fn cleanup(&self) -> Result<(), Box<dyn std::error::Error>> {
        let admin_pool = PgPool::connect(&self.admin_url).await?;
        sqlx::query(&format!(
            r#"DROP DATABASE IF EXISTS "{}" WITH (FORCE)"#,
            self.name
        ))
        .execute(&admin_pool)
        .await?;
        admin_pool.close().await;
        Ok(())
    }
}

async fn run_migrate(url: &str) -> Result<Database, sqlx::Error> {
    let _database_url_guard = EnvGuard::set("DATABASE_URL", url);
    let db = Database::new().await?;
    db.migrate().await?;
    Ok(db)
}

async fn migrate_error(url: &str) -> Result<String, Box<dyn std::error::Error>> {
    let _database_url_guard = EnvGuard::set("DATABASE_URL", url);
    let db = Database::new().await?;
    match db.migrate().await {
        Ok(_) => Err("预期迁移失败，但实际成功".into()),
        Err(err) => Ok(err.to_string()),
    }
}

async fn table_exists(pool: &PgPool, table: &str) -> Result<bool, sqlx::Error> {
    sqlx::query_scalar(
        "SELECT EXISTS (
             SELECT 1
             FROM information_schema.tables
             WHERE table_schema = 'public'
               AND table_name = $1
               AND table_type = 'BASE TABLE'
         )",
    )
    .bind(table)
    .fetch_one(pool)
    .await
}

async fn view_exists(pool: &PgPool, view: &str) -> Result<bool, sqlx::Error> {
    sqlx::query_scalar(
        "SELECT EXISTS (
             SELECT 1
             FROM information_schema.views
             WHERE table_schema = 'public'
               AND table_name = $1
         )",
    )
    .bind(view)
    .fetch_one(pool)
    .await
}

async fn column_exists(pool: &PgPool, table: &str, column: &str) -> Result<bool, sqlx::Error> {
    sqlx::query_scalar(
        "SELECT EXISTS (
             SELECT 1
             FROM information_schema.columns
             WHERE table_schema = 'public'
               AND table_name = $1
               AND column_name = $2
         )",
    )
    .bind(table)
    .bind(column)
    .fetch_one(pool)
    .await
}

#[tokio::test]
async fn empty_database_migrate_builds_current_baseline() -> Result<(), Box<dyn std::error::Error>>
{
    let _lock = ENV_LOCK.lock().await;
    let temp = TempDatabase::create().await?;

    let db = run_migrate(&temp.url).await?;
    let pool = db.pool();

    for table in [
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
        "e2ee_account_identities",
        "e2ee_devices",
        "e2ee_key_packages",
        "e2ee_room_epochs",
        "e2ee_control_messages",
        "e2ee_control_receipts",
        "object_storage_configs",
        "user_room_preferences",
    ] {
        assert!(table_exists(pool, table).await?, "缺少表: {table}");
    }

    assert!(view_exists(pool, "group_detail_view").await?);
    assert!(column_exists(pool, "messages", "edited_at").await?);
    assert!(column_exists(pool, "messages", "encrypted_content").await?);
    assert!(column_exists(pool, "messages", "encryption_metadata").await?);
    assert!(column_exists(pool, "app_versions", "app_store_url").await?);
    assert!(column_exists(pool, "e2ee_devices", "approved_by_device_id").await?);
    assert!(column_exists(pool, "e2ee_devices", "revoked_at").await?);
    assert!(column_exists(pool, "e2ee_devices", "approval_public_key").await?);
    assert!(column_exists(pool, "e2ee_key_packages", "consumed_at").await?);
    assert!(column_exists(pool, "e2ee_room_epochs", "membership_revision").await?);
    assert!(column_exists(pool, "e2ee_control_messages", "idempotency_key").await?);
    assert!(column_exists(pool, "e2ee_control_receipts", "consumed_at").await?);
    let revision_trigger_exists: bool = sqlx::query_scalar(
        "SELECT EXISTS (
            SELECT 1 FROM pg_trigger
            WHERE tgname = 'trg_room_members_e2ee_revision' AND NOT tgisinternal
         )",
    )
    .fetch_one(pool)
    .await?;
    assert!(revision_trigger_exists);

    let admin_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM admin_users WHERE deleted_at IS NULL")
            .fetch_one(pool)
            .await?;
    assert_eq!(admin_count, 0);

    let permissions_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM permissions")
        .fetch_one(pool)
        .await?;
    assert_eq!(permissions_count, 8);

    let applied_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM db_migrations")
        .fetch_one(pool)
        .await?;
    assert_eq!(applied_count, EXPECTED_MIGRATION_COUNT);

    let checksum: Option<String> =
        sqlx::query_scalar("SELECT checksum FROM db_migrations WHERE name = 'base.sql'")
            .fetch_one(pool)
            .await?;
    assert!(checksum.is_some());

    db.pool.close().await;
    temp.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn non_empty_database_without_migration_table_is_rejected_by_default(
) -> Result<(), Box<dyn std::error::Error>> {
    let _lock = ENV_LOCK.lock().await;
    let temp = TempDatabase::create().await?;
    let pool = PgPool::connect(&temp.url).await?;
    sqlx::query("CREATE TABLE probe (id INTEGER PRIMARY KEY)")
        .execute(&pool)
        .await?;
    pool.close().await;

    let err = migrate_error(&temp.url).await?;
    assert!(err.contains("缺少迁移记录表"));
    assert!(err.contains(ADOPT_ENV));

    temp.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn explicit_adopt_allows_current_schema_without_migration_table(
) -> Result<(), Box<dyn std::error::Error>> {
    let _lock = ENV_LOCK.lock().await;
    let temp = TempDatabase::create().await?;
    let db = run_migrate(&temp.url).await?;
    sqlx::query("DROP TABLE db_migrations")
        .execute(db.pool())
        .await?;
    db.pool.close().await;

    let _adopt_guard = EnvGuard::set(ADOPT_ENV, "true");
    let adopted = run_migrate(&temp.url).await?;
    let applied_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM db_migrations")
        .fetch_one(adopted.pool())
        .await?;
    assert_eq!(applied_count, EXPECTED_MIGRATION_COUNT);

    let checksum: Option<String> =
        sqlx::query_scalar("SELECT checksum FROM db_migrations WHERE name = 'base.sql'")
            .fetch_one(adopted.pool())
            .await?;
    assert!(checksum.is_some());

    adopted.pool.close().await;
    temp.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn explicit_adopt_rejects_schema_missing_latest_tables(
) -> Result<(), Box<dyn std::error::Error>> {
    let _lock = ENV_LOCK.lock().await;
    let temp = TempDatabase::create().await?;
    let db = run_migrate(&temp.url).await?;
    sqlx::query("DROP TABLE object_storage_configs")
        .execute(db.pool())
        .await?;
    sqlx::query("DROP TABLE db_migrations")
        .execute(db.pool())
        .await?;
    db.pool.close().await;

    let _adopt_guard = EnvGuard::set(ADOPT_ENV, "true");
    let err = migrate_error(&temp.url).await?;
    assert!(err.contains("table:object_storage_configs"));

    temp.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn checksum_mismatch_is_rejected() -> Result<(), Box<dyn std::error::Error>> {
    let _lock = ENV_LOCK.lock().await;
    let temp = TempDatabase::create().await?;
    let db = run_migrate(&temp.url).await?;
    sqlx::query("UPDATE db_migrations SET checksum = 'bad-checksum' WHERE name = 'base.sql'")
        .execute(db.pool())
        .await?;
    db.pool.close().await;

    let err = migrate_error(&temp.url).await?;
    assert!(err.contains("checksum 不匹配"));

    temp.cleanup().await?;
    Ok(())
}
