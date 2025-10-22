use crate::database::models::{AppDocument, DocumentUpdate};
use crate::database::Database;
use sqlx::{query_as, Error};

#[derive(Clone)]
pub struct DocumentStore {
    database: Database,
}

impl DocumentStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    pub async fn get_document(&self, key: &str) -> Result<Option<AppDocument>, Error> {
        let doc = query_as::<_, AppDocument>(
            r#"
            SELECT key, title, content, updated_at, updated_by
            FROM app_documents
            WHERE key = $1
            "#,
        )
        .bind(key)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(doc)
    }

    pub async fn upsert_document(
        &self,
        key: &str,
        payload: &DocumentUpdate,
    ) -> Result<AppDocument, Error> {
        let doc = query_as::<_, AppDocument>(
            r#"
            INSERT INTO app_documents (key, title, content, updated_at, updated_by)
            VALUES ($1, COALESCE($2, '文档'), $3, NOW(), $4)
            ON CONFLICT (key) DO UPDATE SET
                title = COALESCE(EXCLUDED.title, app_documents.title),
                content = EXCLUDED.content,
                updated_at = NOW(),
                updated_by = EXCLUDED.updated_by
            RETURNING key, title, content, updated_at, updated_by
            "#,
        )
        .bind(key)
        .bind(payload.title.as_ref())
        .bind(&payload.content)
        .bind(payload.updated_by)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(doc)
    }
}
