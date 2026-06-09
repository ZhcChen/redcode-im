use axum::{
    extract::{Extension, State},
    response::Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{error::AppError, models::Claims, AppState};

#[derive(Debug, Deserialize)]
pub struct SubmitFeedbackRequest {
    pub content: String,
    #[serde(default)]
    pub contact: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct SubmitFeedbackResponse {
    pub success: bool,
    pub message: String,
}

pub async fn submit_feedback(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<SubmitFeedbackRequest>,
) -> Result<Json<SubmitFeedbackResponse>, AppError> {
    let content = payload.content.trim();
    if content.is_empty() {
        return Err(AppError::ValidationError("反馈内容不能为空".to_string()));
    }

    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user id".to_string()))?;

    let feedback_id = crate::id::generate();

    sqlx::query("INSERT INTO feedbacks (id, user_id, contact, content) VALUES ($1, $2, $3, $4)")
        .bind(feedback_id)
        .bind(user_id)
        .bind(payload.contact.as_deref())
        .bind(content)
        .execute(&state.database.pool)
        .await?;

    Ok(Json(SubmitFeedbackResponse {
        success: true,
        message: "反馈提交成功，感谢您的支持！".to_string(),
    }))
}
