use chrono::{DateTime, Utc};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

#[derive(Debug, Clone)]
pub struct ReportInsert {
    pub id: Uuid,
    pub reporter_id: Uuid,
    pub target_type: i32,
    pub target_room_id: Option<Uuid>,
    pub target_user_id: Option<Uuid>,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct ReportAttachmentInsert {
    pub object_key: String,
    pub content_type: Option<String>,
    pub file_size: Option<i64>,
}

#[derive(Debug, Clone, FromRow)]
pub struct AdminReportRow {
    pub id: Uuid,
    pub reporter_id: Uuid,
    pub reporter_username: String,
    pub reporter_nickname: Option<String>,
    pub target_type: i32,
    pub target_room_id: Option<Uuid>,
    pub target_room_name: Option<String>,
    pub target_user_id: Option<Uuid>,
    pub target_user_username: Option<String>,
    pub target_user_nickname: Option<String>,
    pub content: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, FromRow)]
pub struct ReportAttachmentRow {
    pub report_id: Uuid,
    pub object_key: String,
    pub content_type: Option<String>,
    pub file_size: Option<i64>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone)]
pub struct AdminReportListFilters {
    pub reporter_id: Option<Uuid>,
    pub target_type: Option<i32>,
    pub target_room_id: Option<Uuid>,
    pub target_user_id: Option<Uuid>,
    pub keyword: Option<String>,
    pub limit: i64,
    pub offset: i64,
}

pub struct ReportStore<'a> {
    pub pool: &'a PgPool,
}

impl<'a> ReportStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    pub async fn create_report(
        &self,
        insert: ReportInsert,
        attachments: Vec<ReportAttachmentInsert>,
    ) -> Result<(), sqlx::Error> {
        let mut tx = self.pool.begin().await?;

        sqlx::query(
            r#"
            INSERT INTO reports (
                id, reporter_id, target_type, target_room_id, target_user_id, content
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            "#,
        )
        .bind(insert.id)
        .bind(insert.reporter_id)
        .bind(insert.target_type)
        .bind(insert.target_room_id)
        .bind(insert.target_user_id)
        .bind(insert.content)
        .execute(&mut *tx)
        .await?;

        for item in attachments {
            sqlx::query(
                r#"
                INSERT INTO report_attachments (
                    report_id, object_key, content_type, file_size
                )
                VALUES ($1, $2, $3, $4)
                "#,
            )
            .bind(insert.id)
            .bind(item.object_key)
            .bind(item.content_type)
            .bind(item.file_size)
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    pub async fn count_admin_reports(
        &self,
        filters: &AdminReportListFilters,
    ) -> Result<i64, sqlx::Error> {
        let keyword = filters.keyword.as_deref();
        let row: (i64,) = sqlx::query_as(
            r#"
            SELECT COUNT(1) AS total
            FROM reports r
            JOIN users reporter ON reporter.id = r.reporter_id
            LEFT JOIN rooms room ON room.id = r.target_room_id
            LEFT JOIN users target_user ON target_user.id = r.target_user_id
            WHERE ($1::uuid IS NULL OR r.reporter_id = $1)
              AND ($2::int4 IS NULL OR r.target_type = $2)
              AND (
                  ($3::uuid IS NULL AND $4::uuid IS NULL)
                  OR ($3::uuid IS NOT NULL AND r.target_room_id = $3)
                  OR ($4::uuid IS NOT NULL AND r.target_user_id = $4)
              )
              AND (
                  $5::text IS NULL
                  OR r.content ILIKE '%' || $5 || '%'
                  OR reporter.username ILIKE '%' || $5 || '%'
                  OR COALESCE(reporter.nickname, '') ILIKE '%' || $5 || '%'
                  OR COALESCE(room.name, '') ILIKE '%' || $5 || '%'
                  OR COALESCE(target_user.username, '') ILIKE '%' || $5 || '%'
                  OR COALESCE(target_user.nickname, '') ILIKE '%' || $5 || '%'
              )
            "#,
        )
        .bind(filters.reporter_id)
        .bind(filters.target_type)
        .bind(filters.target_room_id)
        .bind(filters.target_user_id)
        .bind(keyword)
        .fetch_one(self.pool)
        .await?;

        Ok(row.0)
    }

    pub async fn list_admin_reports(
        &self,
        filters: &AdminReportListFilters,
    ) -> Result<Vec<AdminReportRow>, sqlx::Error> {
        let keyword = filters.keyword.as_deref();
        sqlx::query_as::<_, AdminReportRow>(
            r#"
            SELECT
                r.id,
                r.reporter_id,
                reporter.username AS reporter_username,
                reporter.nickname AS reporter_nickname,
                r.target_type,
                r.target_room_id,
                room.name AS target_room_name,
                r.target_user_id,
                target_user.username AS target_user_username,
                target_user.nickname AS target_user_nickname,
                r.content,
                r.created_at
            FROM reports r
            JOIN users reporter ON reporter.id = r.reporter_id
            LEFT JOIN rooms room ON room.id = r.target_room_id
            LEFT JOIN users target_user ON target_user.id = r.target_user_id
            WHERE ($1::uuid IS NULL OR r.reporter_id = $1)
              AND ($2::int4 IS NULL OR r.target_type = $2)
              AND (
                  ($3::uuid IS NULL AND $4::uuid IS NULL)
                  OR ($3::uuid IS NOT NULL AND r.target_room_id = $3)
                  OR ($4::uuid IS NOT NULL AND r.target_user_id = $4)
              )
              AND (
                  $5::text IS NULL
                  OR r.content ILIKE '%' || $5 || '%'
                  OR reporter.username ILIKE '%' || $5 || '%'
                  OR COALESCE(reporter.nickname, '') ILIKE '%' || $5 || '%'
                  OR COALESCE(room.name, '') ILIKE '%' || $5 || '%'
                  OR COALESCE(target_user.username, '') ILIKE '%' || $5 || '%'
                  OR COALESCE(target_user.nickname, '') ILIKE '%' || $5 || '%'
              )
            ORDER BY r.created_at DESC
            LIMIT $6 OFFSET $7
            "#,
        )
        .bind(filters.reporter_id)
        .bind(filters.target_type)
        .bind(filters.target_room_id)
        .bind(filters.target_user_id)
        .bind(keyword)
        .bind(filters.limit)
        .bind(filters.offset)
        .fetch_all(self.pool)
        .await
    }

    pub async fn list_attachments_by_report_ids(
        &self,
        report_ids: &[Uuid],
    ) -> Result<Vec<ReportAttachmentRow>, sqlx::Error> {
        if report_ids.is_empty() {
            return Ok(vec![]);
        }

        sqlx::query_as::<_, ReportAttachmentRow>(
            r#"
            SELECT report_id, object_key, content_type, file_size, created_at
            FROM report_attachments
            WHERE report_id = ANY($1)
            ORDER BY created_at ASC
            "#,
        )
        .bind(report_ids)
        .fetch_all(self.pool)
        .await
    }
}
