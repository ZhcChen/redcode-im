use crate::database::emoji_pack_store::EmojiPackStore;
use crate::database::models::{
    CreateEmojiItemRequest, CreateEmojiPackRequest, EmojiItem, EmojiPack, UpdateEmojiItemRequest,
    UpdateEmojiPackRequest,
};
use crate::error::AppError;
use crate::models::Claims;
use crate::AppState;
use axum::{extract::Path, extract::State, Extension, Json};
use serde::Serialize;
use uuid::Uuid;

// ===== API 响应模型 =====

#[derive(Debug, Serialize)]
pub struct EmojiPackResponse {
    pub id: String,
    pub name: String,
    pub icon_url: Option<String>,
    pub description: Option<String>,
    pub is_active: bool,
    pub pack_type: i16, // 0=单个, 1=套件
    pub parent_id: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Serialize)]
pub struct EmojiItemResponse {
    pub id: String,
    pub pack_id: String,
    pub image_url: String,
    pub name: Option<String>,
    pub sort_order: i32,
    pub created_at: String,
}

#[derive(Debug, Serialize)]
pub struct EmojiPackWithItemsResponse {
    pub pack: EmojiPackResponse,
    pub items: Vec<EmojiItemResponse>,
}

// ===== 转换函数 =====

fn db_pack_to_api(pack: &EmojiPack) -> EmojiPackResponse {
    EmojiPackResponse {
        id: pack.id.to_string(),
        name: pack.name.clone(),
        icon_url: pack.icon_url.clone(),
        description: pack.description.clone(),
        is_active: matches!(
            pack.is_active,
            crate::database::models::EmojiPackStatus::Active
        ),
        pack_type: matches!(
            pack.pack_type,
            crate::database::models::EmojiPackType::Suite
        ) as i16,
        parent_id: pack.parent_id.map(|id| id.to_string()),
        created_at: pack.created_at.to_rfc3339(),
        updated_at: pack.updated_at.to_rfc3339(),
    }
}

fn db_item_to_api(item: &EmojiItem) -> EmojiItemResponse {
    EmojiItemResponse {
        id: item.id.to_string(),
        pack_id: item.pack_id.to_string(),
        image_url: item.image_url.clone(),
        name: item.name.clone(),
        sort_order: item.sort_order,
        created_at: item.created_at.to_rfc3339(),
    }
}

// ===== 管理员 API：表情包管理 =====

/// 获取所有表情包列表（管理员）
pub async fn list_all_packs(
    State(state): State<AppState>,
) -> Result<Json<Vec<EmojiPackResponse>>, AppError> {
    let store = EmojiPackStore::new(state.database.clone());
    let packs = store.list_all_packs().await?;

    let response: Vec<EmojiPackResponse> = packs.iter().map(db_pack_to_api).collect();
    Ok(Json(response))
}

/// 创建表情包（管理员）
pub async fn create_pack(
    State(state): State<AppState>,
    Json(payload): Json<CreateEmojiPackRequest>,
) -> Result<Json<EmojiPackResponse>, AppError> {
    if payload.name.trim().is_empty() {
        return Err(AppError::ValidationError("表情包名称不能为空".to_string()));
    }

    let store = EmojiPackStore::new(state.database.clone());
    let pack = store.create_pack(payload).await?;

    Ok(Json(db_pack_to_api(&pack)))
}

/// 获取表情包详情（管理员）
pub async fn get_pack(
    State(state): State<AppState>,
    Path(pack_id): Path<String>,
) -> Result<Json<EmojiPackWithItemsResponse>, AppError> {
    let pack_id = Uuid::parse_str(&pack_id)
        .map_err(|_| AppError::ValidationError("无效的表情包ID".to_string()))?;

    let store = EmojiPackStore::new(state.database.clone());
    let pack = store
        .get_pack_by_id(pack_id)
        .await?
        .ok_or_else(|| AppError::NotFound("表情包不存在".to_string()))?;

    let items = store.list_items_by_pack(pack_id).await?;

    Ok(Json(EmojiPackWithItemsResponse {
        pack: db_pack_to_api(&pack),
        items: items.iter().map(db_item_to_api).collect(),
    }))
}

/// 更新表情包（管理员）
pub async fn update_pack(
    State(state): State<AppState>,
    Path(pack_id): Path<String>,
    Json(payload): Json<UpdateEmojiPackRequest>,
) -> Result<Json<EmojiPackResponse>, AppError> {
    let pack_id = Uuid::parse_str(&pack_id)
        .map_err(|_| AppError::ValidationError("无效的表情包ID".to_string()))?;

    let store = EmojiPackStore::new(state.database.clone());
    let pack = store
        .update_pack(pack_id, payload)
        .await?
        .ok_or_else(|| AppError::NotFound("表情包不存在".to_string()))?;

    Ok(Json(db_pack_to_api(&pack)))
}

/// 删除表情包（管理员）
pub async fn delete_pack(
    State(state): State<AppState>,
    Path(pack_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let pack_id = Uuid::parse_str(&pack_id)
        .map_err(|_| AppError::ValidationError("无效的表情包ID".to_string()))?;

    let store = EmojiPackStore::new(state.database.clone());
    let deleted = store.delete_pack(pack_id).await?;

    if !deleted {
        return Err(AppError::NotFound("表情包不存在".to_string()));
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "删除成功"
    })))
}

// ===== 管理员 API：表情项管理 =====

/// 创建表情项（管理员）
pub async fn create_item(
    State(state): State<AppState>,
    Json(payload): Json<CreateEmojiItemRequest>,
) -> Result<Json<EmojiItemResponse>, AppError> {
    if payload.image_url.trim().is_empty() {
        return Err(AppError::ValidationError("表情图片URL不能为空".to_string()));
    }

    let store = EmojiPackStore::new(state.database.clone());
    let item = store.create_item(payload).await?;

    Ok(Json(db_item_to_api(&item)))
}

/// 获取表情项详情（管理员）
pub async fn get_item(
    State(state): State<AppState>,
    Path(item_id): Path<String>,
) -> Result<Json<EmojiItemResponse>, AppError> {
    let item_id = Uuid::parse_str(&item_id)
        .map_err(|_| AppError::ValidationError("无效的表情项ID".to_string()))?;

    let store = EmojiPackStore::new(state.database.clone());
    let item = store
        .get_item_by_id(item_id)
        .await?
        .ok_or_else(|| AppError::NotFound("表情项不存在".to_string()))?;

    Ok(Json(db_item_to_api(&item)))
}

/// 更新表情项（管理员）
pub async fn update_item(
    State(state): State<AppState>,
    Path(item_id): Path<String>,
    Json(payload): Json<UpdateEmojiItemRequest>,
) -> Result<Json<EmojiItemResponse>, AppError> {
    let item_id = Uuid::parse_str(&item_id)
        .map_err(|_| AppError::ValidationError("无效的表情项ID".to_string()))?;

    let store = EmojiPackStore::new(state.database.clone());
    let item = store
        .update_item(item_id, payload)
        .await?
        .ok_or_else(|| AppError::NotFound("表情项不存在".to_string()))?;

    Ok(Json(db_item_to_api(&item)))
}

/// 删除表情项（管理员）
pub async fn delete_item(
    State(state): State<AppState>,
    Path(item_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let item_id = Uuid::parse_str(&item_id)
        .map_err(|_| AppError::ValidationError("无效的表情项ID".to_string()))?;

    let store = EmojiPackStore::new(state.database.clone());
    let deleted = store.delete_item(item_id).await?;

    if !deleted {
        return Err(AppError::NotFound("表情项不存在".to_string()));
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "删除成功"
    })))
}

// ===== 用户 API：表情包使用 =====

/// 获取用户的表情包列表
pub async fn list_user_packs(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<Vec<EmojiPackWithItemsResponse>>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::ValidationError("无效的用户ID".to_string()))?;

    let store = EmojiPackStore::new(state.database.clone());
    let packs = store.list_user_packs(user_id).await?;

    let mut result = Vec::new();
    for pack in packs {
        let items = store.list_items_by_pack(pack.id).await?;
        result.push(EmojiPackWithItemsResponse {
            pack: db_pack_to_api(&pack),
            items: items.iter().map(db_item_to_api).collect(),
        });
    }

    Ok(Json(result))
}

/// 获取所有可用的表情包（用于用户选择添加）
pub async fn list_available_packs(
    State(state): State<AppState>,
) -> Result<Json<Vec<EmojiPackResponse>>, AppError> {
    let store = EmojiPackStore::new(state.database.clone());
    let packs = store.list_active_packs().await?;

    let response: Vec<EmojiPackResponse> = packs.iter().map(db_pack_to_api).collect();
    Ok(Json(response))
}

/// 添加用户表情包
pub async fn add_user_pack(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(pack_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::ValidationError("无效的用户ID".to_string()))?;
    let pack_id = Uuid::parse_str(&pack_id)
        .map_err(|_| AppError::ValidationError("无效的表情包ID".to_string()))?;

    let store = EmojiPackStore::new(state.database.clone());

    // 检查表情包是否存在且激活
    let pack = store
        .get_pack_by_id(pack_id)
        .await?
        .ok_or_else(|| AppError::NotFound("表情包不存在".to_string()))?;

    if !matches!(
        pack.is_active,
        crate::database::models::EmojiPackStatus::Active
    ) {
        return Err(AppError::ValidationError("表情包未激活".to_string()));
    }

    store.add_user_pack(user_id, pack_id).await?;

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "添加成功"
    })))
}

/// 删除用户表情包
pub async fn remove_user_pack(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(pack_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::ValidationError("无效的用户ID".to_string()))?;
    let pack_id = Uuid::parse_str(&pack_id)
        .map_err(|_| AppError::ValidationError("无效的表情包ID".to_string()))?;

    let store = EmojiPackStore::new(state.database.clone());
    let removed = store.remove_user_pack(user_id, pack_id).await?;

    if !removed {
        return Err(AppError::NotFound("用户未添加此表情包".to_string()));
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "删除成功"
    })))
}

/// 搜索表情包和套件
pub async fn search_packs(
    State(state): State<AppState>,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Vec<EmojiPackResponse>>, AppError> {
    let keyword = params
        .get("keyword")
        .ok_or_else(|| AppError::ValidationError("缺少搜索关键词".to_string()))?;

    if keyword.trim().is_empty() {
        return Ok(Json(vec![]));
    }

    let store = EmojiPackStore::new(state.database.clone());
    let packs = store.search_packs(keyword).await?;

    let response: Vec<EmojiPackResponse> = packs.iter().map(db_pack_to_api).collect();
    Ok(Json(response))
}

/// 添加表情包套件（添加套件下的所有表情包）
pub async fn add_user_suite(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(suite_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::ValidationError("无效的用户ID".to_string()))?;
    let suite_id = Uuid::parse_str(&suite_id)
        .map_err(|_| AppError::ValidationError("无效的套件ID".to_string()))?;

    let store = EmojiPackStore::new(state.database.clone());

    // 检查套件是否存在且是套件类型
    let suite = store
        .get_pack_by_id(suite_id)
        .await?
        .ok_or_else(|| AppError::NotFound("套件不存在".to_string()))?;

    if !matches!(
        suite.pack_type,
        crate::database::models::EmojiPackType::Suite
    ) {
        return Err(AppError::ValidationError(
            "指定的不是表情包套件".to_string(),
        ));
    }

    if !matches!(
        suite.is_active,
        crate::database::models::EmojiPackStatus::Active
    ) {
        return Err(AppError::ValidationError("套件未激活".to_string()));
    }

    let count = store.add_suite_packs_to_user(user_id, suite_id).await?;

    Ok(Json(serde_json::json!({
        "success": true,
        "message": format!("成功添加 {} 个表情包", count),
        "count": count
    })))
}
