use std::collections::HashSet;

use axum::{
    extract::{Extension, Path, Query, State},
    response::Json,
};
use chrono;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::{
    models::{MemberRole, Room, RoomType},
    room_store::RoomStore,
};
use crate::error::AppError;
use crate::models::convert::{db_chat_summary_to_api, string_to_uuid};
use crate::models::{ChatSummary, Claims};
use crate::websocket::{RoomCreatedPayload, ServerPush};
use crate::AppState;

#[derive(Deserialize)]
pub struct CreateRoomPayload {
    pub name: String,
    pub description: Option<String>,
    pub room_type: Option<RoomType>,
    #[serde(default)]
    pub member_ids: Vec<String>,
}

#[derive(Serialize)]
pub struct CreateRoomResponse {
    pub room: Room,
}

pub async fn create_room(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<CreateRoomPayload>,
) -> Result<Json<CreateRoomResponse>, AppError> {
    let CreateRoomPayload {
        name,
        description,
        room_type,
        member_ids,
    } = payload;

    if name.trim().is_empty() {
        return Err(AppError::ValidationError(
            "Room name cannot be empty".to_string(),
        ));
    }

    let requested_type = room_type.unwrap_or(RoomType::Group);
    if matches!(requested_type, RoomType::Private | RoomType::Favorite) {
        return Err(AppError::ValidationError(
            "Cannot create room of this type via this endpoint".to_string(),
        ));
    }

    let owner = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let mut unique_members = HashSet::new();
    let mut member_uuid_list = Vec::new();
    for raw_id in member_ids {
        let trimmed = raw_id.trim();
        if trimmed.is_empty() {
            continue;
        }
        let member_uuid = Uuid::parse_str(trimmed)
            .map_err(|_| AppError::ValidationError(format!("Invalid member ID: {}", trimmed)))?;
        if member_uuid == owner {
            continue;
        }
        if unique_members.insert(member_uuid) {
            member_uuid_list.push(member_uuid);
        }
    }

    if requested_type == RoomType::Group && member_uuid_list.is_empty() {
        return Err(AppError::ValidationError(
            "Group room must contain at least one additional member".to_string(),
        ));
    }

    let store = RoomStore::new(state.database.pool());
    let room = store
        .create_room_with_members(
            owner,
            name,
            description,
            Some(requested_type),
            &member_uuid_list,
        )
        .await?;

    // 通知所有相关成员刷新会话列表
    let mut notify_targets: HashSet<Uuid> = member_uuid_list.into_iter().collect();
    notify_targets.insert(owner);
    let room_id = room.id;
    let room_name = room.name.clone();
    let room_description = room.description.clone();
    let room_avatar = room.avatar_url.clone();
    let room_created_at = room.created_at;
    let room_owner = room.owner_id;
    for user_id in notify_targets {
        let payload = ServerPush::RoomCreated {
            data: RoomCreatedPayload {
                room_id,
                room_name: room_name.clone(),
                room_type: requested_type.to_string(),
                initiator_id: owner,
                owner_id: room_owner,
                description: room_description.clone(),
                avatar_url: room_avatar.clone(),
                created_at: Some(room_created_at),
            },
        };
        state
            .connection_manager
            .send_to_user(&user_id.to_string(), payload)
            .await;
    }

    Ok(Json(CreateRoomResponse { room }))
}

#[derive(Serialize)]
pub struct JoinRoomResponse {
    pub ok: bool,
}

pub async fn join_room(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<JoinRoomResponse>, AppError> {
    let user = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = RoomStore::new(state.database.pool());
    let _ = store
        .add_member(room_id, user, Some(MemberRole::Member))
        .await?;

    Ok(Json(JoinRoomResponse { ok: true }))
}

#[derive(Serialize)]
pub struct LeaveRoomResponse {
    pub ok: bool,
}

#[derive(Serialize)]
pub struct PinRoomResponse {
    pub is_pinned: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pinned_at: Option<String>,
}

pub async fn leave_room(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<LeaveRoomResponse>, AppError> {
    let user = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = RoomStore::new(state.database.pool());
    let ok = store.remove_member(room_id, user).await?;

    if !ok {
        return Err(AppError::NotFound(format!(
            "User {} is not a member of room {}",
            user, room_id
        )));
    }

    Ok(Json(LeaveRoomResponse { ok }))
}

#[derive(Serialize)]
pub struct RoomMemberDto {
    pub user_id: Uuid,
    pub username: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub nickname: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub avatar_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub avatar_object_key: Option<String>,
    pub role: MemberRole,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub joined_at: Option<String>,
}

pub async fn list_members(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<Vec<RoomMemberDto>>, AppError> {
    let store = RoomStore::new(state.database.pool());
    let rows = store.list_members_with_user_info(room_id).await?;

    let items = rows
        .into_iter()
        .map(|rm| RoomMemberDto {
            user_id: rm.user_id,
            username: rm.username,
            nickname: rm.nickname,
            avatar_url: rm.avatar_url,
            avatar_object_key: rm.avatar_object_key,
            role: rm.role,
            joined_at: rm.joined_at.map(|dt| dt.to_rfc3339()),
        })
        .collect();

    Ok(Json(items))
}

#[derive(Serialize)]
pub struct MyRoomDto {
    pub id: Uuid,
    pub name: String,
    pub room_type: RoomType,
}

pub async fn list_my_rooms(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<Vec<MyRoomDto>>, AppError> {
    let user = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = RoomStore::new(state.database.pool());
    let rooms = store.list_user_rooms(user).await?;

    let result = rooms
        .into_iter()
        .map(|r| MyRoomDto {
            id: r.id,
            name: r.name,
            room_type: r.room_type,
        })
        .collect();

    Ok(Json(result))
}

/// 获取当前用户的会话列表概要
pub async fn list_chat_summaries(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<Vec<ChatSummary>>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let store = RoomStore::new(state.database.pool());
    store.ensure_favorite_room(user_id).await?;
    let rows = store.list_chat_summaries(user_id).await?;

    let summaries = rows
        .into_iter()
        .map(|row| db_chat_summary_to_api(&row))
        .collect();

    Ok(Json(summaries))
}

#[derive(Deserialize)]
pub struct UpdateNotificationSettingsPayload {
    pub notification_settings: i32,
}

#[derive(Serialize)]
pub struct UpdateNotificationSettingsResponse {
    pub notification_settings: i32,
}

#[derive(Serialize)]
pub struct DeleteChatResponse {
    pub success: bool,
}

pub async fn delete_chat(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<DeleteChatResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = RoomStore::new(state.database.pool());
    let success = store.delete_chat(room_id, user_id).await?;

    if !success {
        return Err(AppError::NotFound(format!(
            "Chat {} not found or you don't have permission to delete it",
            room_id
        )));
    }

    Ok(Json(DeleteChatResponse { success }))
}

pub async fn update_notification_settings(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Json(payload): Json<UpdateNotificationSettingsPayload>,
) -> Result<Json<UpdateNotificationSettingsResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    // 验证通知设置值
    let notification_setting = match payload.notification_settings {
        0 => crate::database::models::NotificationSetting::All,
        1 => crate::database::models::NotificationSetting::MentionsOnly,
        2 => crate::database::models::NotificationSetting::Muted,
        _ => return Err(AppError::ValidationError(
            "Invalid notification settings value. Must be 0 (all), 1 (mentions only), or 2 (muted)"
                .to_string(),
        )),
    };

    let store = RoomStore::new(state.database.pool());
    store
        .update_notification_settings(room_id, user_id, notification_setting)
        .await?;

    Ok(Json(UpdateNotificationSettingsResponse {
        notification_settings: payload.notification_settings,
    }))
}

pub async fn pin_room(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<PinRoomResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = RoomStore::new(state.database.pool());
    if !store.is_user_in_room(room_id, user_id).await? {
        return Err(AppError::Forbidden(
            "You are not a member of this room".to_string(),
        ));
    }

    let record = store.pin_room_for_user(user_id, room_id).await?;

    Ok(Json(PinRoomResponse {
        is_pinned: true,
        pinned_at: Some(record.pinned_at.to_rfc3339()),
    }))
}

pub async fn unpin_room(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<PinRoomResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = RoomStore::new(state.database.pool());
    if !store.is_user_in_room(room_id, user_id).await? {
        return Err(AppError::Forbidden(
            "You are not a member of this room".to_string(),
        ));
    }

    let _ = store.unpin_room_for_user(user_id, room_id).await?;

    Ok(Json(PinRoomResponse {
        is_pinned: false,
        pinned_at: None,
    }))
}

#[derive(Deserialize)]
pub struct UpdateRoomRequest {
    pub name: Option<String>,
    pub description: Option<String>,
    pub avatar_url: Option<String>,
}

#[derive(Serialize)]
pub struct UpdateRoomResponse {
    pub success: bool,
    pub message: String,
    pub room: Option<Room>,
}

pub async fn update_room(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
    Extension(claims): Extension<Claims>,
    Json(request): Json<UpdateRoomRequest>,
) -> Result<Json<UpdateRoomResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = RoomStore::new(state.database.pool());
    
    // 检查用户权限
    let member = store
        .get_member(room_id, user_id)
        .await?
        .ok_or_else(|| AppError::Forbidden("You are not a member of this room".to_string()))?;
    
    let is_owner = member.user_id == store.get_room_owner(room_id).await?;
    if !is_owner && member.role != MemberRole::Admin {
        return Err(AppError::Forbidden("Only room owner or admin can update room".to_string()));
    }

    let room = store
        .update_room(room_id, request.name, request.description, request.avatar_url, None)
        .await?;

    Ok(Json(UpdateRoomResponse {
        success: true,
        message: "Room updated successfully".to_string(),
        room: Some(room),
    }))
}

#[derive(Deserialize)]
pub struct RoomAvatarDirectUploadRequest {
    pub filename: String,
    pub content_type: String,
    #[serde(default)]
    pub file_size: Option<i64>,
}

#[derive(Serialize)]
pub struct RoomAvatarDirectUploadResponse {
    pub success: bool,
    pub message: String,
    pub key: Option<String>,
    pub signature: Option<crate::storage::DirectUploadSignature>,
}

pub async fn generate_room_avatar_direct_upload(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<RoomAvatarDirectUploadRequest>,
) -> Result<Json<RoomAvatarDirectUploadResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    // 验证文件类型
    if !req.content_type.starts_with("image/") {
        return Ok(Json(RoomAvatarDirectUploadResponse {
            success: false,
            message: "Only image files are allowed".to_string(),
            key: None,
            signature: None,
        }));
    }

    // 验证文件大小
    if let Some(file_size) = req.file_size {
        if file_size > crate::constants::AVATAR_MAX_SIZE_BYTES as i64 {
            return Ok(Json(RoomAvatarDirectUploadResponse {
                success: false,
                message: format!(
                    "文件大小超出限制，最大允许{}MB",
                    crate::constants::AVATAR_MAX_SIZE_BYTES / 1024 / 1024
                ),
                key: None,
                signature: None,
            }));
        }
    }

    let store = RoomStore::new(state.database.pool());

    // 检查用户权限（只有房主或管理员可以上传头像）
    let member = store
        .get_member(room_id, user_id)
        .await?
        .ok_or_else(|| AppError::Forbidden("You are not a member of this room".to_string()))?;

    let is_owner = member.user_id == store.get_room_owner(room_id).await?;
    if !is_owner && member.role != MemberRole::Admin {
        return Err(AppError::Forbidden("Only room owner or admin can upload avatar".to_string()));
    }

    // 加载默认存储提供商
    let provider = crate::handlers::user::load_default_storage_provider(&state).await?;
    let storage_service = crate::storage::create_storage_service(&provider)?;

    // 生成唯一的对象键
    let timestamp = chrono::Utc::now().format("%Y%m%d%H%M%S");
    let ext = req.filename.rsplit('.').next().unwrap_or("png");
    let key = format!("room_avatars/{}/{}_{}.{}", room_id, timestamp, uuid::Uuid::new_v4().to_string()[..8].to_string(), ext);

    // 生成直传签名
    let signature = storage_service
        .generate_direct_upload_signature(&key, Some(&req.content_type))
        .await?;

    Ok(Json(RoomAvatarDirectUploadResponse {
        success: true,
        message: "生成群头像直传签名成功".to_string(),
        key: Some(key),
        signature: Some(signature),
    }))
}

#[derive(Deserialize)]
pub struct CommitRoomAvatarUploadRequest {
    pub key: String,
}

#[derive(Serialize)]
pub struct CommitRoomAvatarUploadResponse {
    pub success: bool,
    pub message: String,
    pub avatar_url: Option<String>,
}

pub async fn commit_room_avatar_upload(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<CommitRoomAvatarUploadRequest>,
) -> Result<Json<CommitRoomAvatarUploadResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let key = req.key.trim();
    if key.is_empty() {
        return Ok(Json(CommitRoomAvatarUploadResponse {
            success: false,
            message: "文件路径（key）不能为空".to_string(),
            avatar_url: None,
        }));
    }

    let store = RoomStore::new(state.database.pool());

    // 检查用户权限
    let member = store
        .get_member(room_id, user_id)
        .await?
        .ok_or_else(|| AppError::Forbidden("You are not a member of this room".to_string()))?;

    let is_owner = member.user_id == store.get_room_owner(room_id).await?;
    if !is_owner && member.role != MemberRole::Admin {
        return Err(AppError::Forbidden("Only room owner or admin can upload avatar".to_string()));
    }

    // 验证对象键格式
    if !key.starts_with(&format!("room_avatars/{}/", room_id)) {
        return Err(AppError::InvalidInput("Invalid object key".to_string()));
    }

    // 加载存储服务并获取文件URL
    let provider = crate::handlers::user::load_default_storage_provider(&state).await?;
    let storage_service = crate::storage::create_storage_service(&provider)?;
    let avatar_url = storage_service.get_file_url(key);

    // 更新房间头像：存储 object_key 和 url
    store
        .update_room(room_id, None, None, Some(avatar_url.clone()), Some(key.to_string()))
        .await?;

    Ok(Json(CommitRoomAvatarUploadResponse {
        success: true,
        message: "群头像上传成功".to_string(),
        avatar_url: Some(avatar_url),
    }))
}

#[derive(Deserialize)]
pub struct RoomAvatarDownloadUrlRequest {
    pub expires_in_seconds: Option<u32>,
}

#[derive(Serialize)]
pub struct RoomAvatarDownloadUrlResponse {
    pub success: bool,
    pub message: String,
    pub download_url: Option<String>,
}

/// 获取群头像临时下载地址
pub async fn get_room_avatar_download_url(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
    Extension(_claims): Extension<Claims>,
    Query(params): Query<RoomAvatarDownloadUrlRequest>,
) -> Result<Json<RoomAvatarDownloadUrlResponse>, AppError> {
    let store = RoomStore::new(state.database.pool());

    // 获取房间信息
    let room = sqlx::query_as::<_, crate::database::models::Room>(
        r#"
        SELECT id, name, description, avatar_url, avatar_object_key, room_type, owner_id, created_at, updated_at, deleted_at
        FROM rooms
        WHERE id = $1 AND deleted_at IS NULL
        "#,
    )
    .bind(room_id)
    .fetch_optional(state.database.pool())
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Room {} not found", room_id)))?;

    let key = match room.avatar_object_key {
        Some(ref key) => key.clone(),
        None => {
            return Ok(Json(RoomAvatarDownloadUrlResponse {
                success: false,
                message: "该群聊尚未设置头像".to_string(),
                download_url: None,
            }));
        }
    };

    let provider = crate::handlers::user::load_default_storage_provider(&state).await?;
    let storage_service = crate::storage::create_storage_service(&provider)?;
    let download_url = storage_service
        .generate_download_url(&key, params.expires_in_seconds)
        .await?;

    Ok(Json(RoomAvatarDownloadUrlResponse {
        success: true,
        message: "生成下载链接成功".to_string(),
        download_url: Some(download_url),
    }))
}
