use crate::database::document_store::DocumentStore;
use crate::error::AppError;
use crate::models::convert::{api_update_document_to_db, db_document_to_api, string_to_uuid};
use crate::models::{Claims, DocumentContent, UpdateDocumentRequest};
use crate::AppState;
use axum::{extract::State, Extension, Json};

const PRIVACY_POLICY_KEY: &str = "privacy_policy";
const PRIVACY_POLICY_FALLBACK_TITLE: &str = "隐私政策";
const PRIVACY_POLICY_FALLBACK_CONTENT: &str = "<p>隐私政策内容尚未配置。</p>";

pub async fn get_privacy_policy(
    State(state): State<AppState>,
) -> Result<Json<DocumentContent>, AppError> {
    let store = DocumentStore::new(state.database.clone());
    let doc = match store.get_document(PRIVACY_POLICY_KEY).await? {
        Some(doc) => doc,
        None => {
            let update = crate::database::models::DocumentUpdate {
                title: Some(PRIVACY_POLICY_FALLBACK_TITLE.to_string()),
                content: PRIVACY_POLICY_FALLBACK_CONTENT.to_string(),
                updated_by: None,
            };
            store.upsert_document(PRIVACY_POLICY_KEY, &update).await?
        }
    };

    Ok(Json(db_document_to_api(&doc)))
}

pub async fn get_privacy_policy_admin(
    State(state): State<AppState>,
) -> Result<Json<DocumentContent>, AppError> {
    get_privacy_policy(State(state)).await
}

pub async fn update_privacy_policy(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<UpdateDocumentRequest>,
) -> Result<Json<DocumentContent>, AppError> {
    if payload.content.trim().is_empty() {
        return Err(AppError::ValidationError(
            "隐私政策内容不能为空".to_string(),
        ));
    }

    let editor_id = string_to_uuid(&claims.sub)?;
    let store = DocumentStore::new(state.database.clone());
    let update = api_update_document_to_db(&payload, Some(editor_id));

    let doc = store.upsert_document(PRIVACY_POLICY_KEY, &update).await?;

    Ok(Json(db_document_to_api(&doc)))
}
