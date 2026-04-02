use crate::database::emoji_pack_store::EmojiPackStore;
use crate::database::file_upload_audit_store::FileUploadAuditStore;
use crate::database::models::{
    CreateEmojiItemRequest, CreateEmojiPackRequest, EmojiItem, EmojiPack, UpdateEmojiItemRequest,
    UpdateEmojiPackRequest,
};
use crate::error::AppError;
use crate::handlers::user::load_default_storage_provider;
use crate::i18n::{localizer::default_localizer, message::MessageParams};
use crate::middleware::current_request_locale;
use crate::models::Claims;
use crate::redis::cache::CacheManager;
use crate::redis::models::CacheKeys;
use crate::storage;
use crate::AppState;
use axum::{
    extract::{Path, Query, State},
    Extension, Json,
};
use serde::{Deserialize, Serialize};
use tracing::{info, warn};
use uuid::Uuid;

fn emoji_localized_message(message_key: &'static str, params: Option<&MessageParams>) -> String {
    let localizer = default_localizer();
    let locale =
        current_request_locale().unwrap_or_else(|| localizer.fallback_locale().to_string());
    localizer.localize(&locale, message_key, params)
}

// ===== API 响应模型 =====

#[derive(Debug, Serialize)]
pub struct EmojiPackResponse {
    pub id: String,
    pub name: String,
    pub icon_url: Option<String>,
    /// COS 对象键（用于生成临时下载地址）
    pub icon_object_key: Option<String>,
    pub description: Option<String>,
    pub is_active: bool,
    pub pack_type: i16, // 0=单个, 1=贴纸包
    pub parent_id: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Serialize)]
pub struct EmojiItemResponse {
    pub id: String,
    pub pack_id: String,
    pub image_url: String,
    /// COS 对象键（用于生成临时下载地址）
    pub image_object_key: Option<String>,
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
        icon_object_key: pack.icon_object_key.clone(),
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
        image_object_key: item.image_object_key.clone(),
        name: item.name.clone(),
        sort_order: item.sort_order,
        created_at: item.created_at.to_rfc3339(),
    }
}

// ===== 管理员 API：贴纸管理 =====

/// 获取所有贴纸列表（管理员）
pub async fn list_all_packs(
    State(state): State<AppState>,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Vec<EmojiPackResponse>>, AppError> {
    let store = EmojiPackStore::new(state.database.clone());

    // 如果有关键词，执行搜索
    if let Some(keyword) = params.get("keyword") {
        if !keyword.trim().is_empty() {
            let packs = store.search_all_packs(keyword).await?;
            let response: Vec<EmojiPackResponse> = packs.iter().map(db_pack_to_api).collect();
            return Ok(Json(response));
        }
    }

    // 如果有 parent_id，返回指定贴纸包下的贴纸
    if let Some(parent_id_str) = params.get("parent_id") {
        if !parent_id_str.trim().is_empty() {
            let parent_id = Uuid::parse_str(parent_id_str).map_err(|_| {
                AppError::ValidationError(String::new()).with_message_key("emoji.suite_id_invalid")
            })?;
            let packs = store.list_packs_by_parent(parent_id).await?;
            let response: Vec<EmojiPackResponse> = packs.iter().map(db_pack_to_api).collect();
            return Ok(Json(response));
        }
    }

    // 否则返回所有贴纸
    let packs = store.list_all_packs().await?;
    let response: Vec<EmojiPackResponse> = packs.iter().map(db_pack_to_api).collect();
    Ok(Json(response))
}

/// 创建贴纸（管理员）
pub async fn create_pack(
    State(state): State<AppState>,
    Json(payload): Json<CreateEmojiPackRequest>,
) -> Result<Json<EmojiPackResponse>, AppError> {
    if payload.name.trim().is_empty() {
        return Err(
            AppError::ValidationError(String::new()).with_message_key("emoji.pack_name_required")
        );
    }

    let store = EmojiPackStore::new(state.database.clone());
    let pack = store.create_pack(payload).await?;

    // 贴纸/表情属于可传播资源：写入审核任务（违规会删除对象并记录原因）
    if let Some(key) = pack
        .icon_object_key
        .as_deref()
        .map(|v| v.trim())
        .filter(|v| !v.is_empty())
    {
        let provider = load_default_storage_provider(&state).await?;
        let audit_store = FileUploadAuditStore::new(state.database.clone());
        let _ = audit_store
            .upsert_task(&provider.id, key, "emoji_pack_icon", "image", None, None)
            .await
            .map_err(AppError::from)?;
    }

    Ok(Json(db_pack_to_api(&pack)))
}

/// 获取贴纸详情（管理员）
pub async fn get_pack(
    State(state): State<AppState>,
    Path(pack_id): Path<String>,
) -> Result<Json<EmojiPackWithItemsResponse>, AppError> {
    let pack_id = Uuid::parse_str(&pack_id).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.pack_id_invalid")
    })?;

    let store = EmojiPackStore::new(state.database.clone());
    let pack = store.get_pack_by_id(pack_id).await?.ok_or_else(|| {
        AppError::NotFound(String::new()).with_message_key("emoji.pack_not_found")
    })?;

    let items = store.list_items_by_pack(pack_id).await?;

    Ok(Json(EmojiPackWithItemsResponse {
        pack: db_pack_to_api(&pack),
        items: items.iter().map(db_item_to_api).collect(),
    }))
}

/// 更新贴纸（管理员）
pub async fn update_pack(
    State(state): State<AppState>,
    Path(pack_id): Path<String>,
    Json(payload): Json<UpdateEmojiPackRequest>,
) -> Result<Json<EmojiPackResponse>, AppError> {
    let pack_id = Uuid::parse_str(&pack_id).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.pack_id_invalid")
    })?;

    let store = EmojiPackStore::new(state.database.clone());
    let pack = store.update_pack(pack_id, payload).await?.ok_or_else(|| {
        AppError::NotFound(String::new()).with_message_key("emoji.pack_not_found")
    })?;

    if let Some(key) = pack
        .icon_object_key
        .as_deref()
        .map(|v| v.trim())
        .filter(|v| !v.is_empty())
    {
        let provider = load_default_storage_provider(&state).await?;
        let audit_store = FileUploadAuditStore::new(state.database.clone());
        let _ = audit_store
            .upsert_task(&provider.id, key, "emoji_pack_icon", "image", None, None)
            .await
            .map_err(AppError::from)?;
    }

    Ok(Json(db_pack_to_api(&pack)))
}

/// 删除贴纸（管理员）
pub async fn delete_pack(
    State(state): State<AppState>,
    Path(pack_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let pack_id = Uuid::parse_str(&pack_id).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.pack_id_invalid")
    })?;

    let store = EmojiPackStore::new(state.database.clone());
    let deleted = store.delete_pack(pack_id).await?;

    if !deleted {
        return Err(AppError::NotFound(String::new()).with_message_key("emoji.pack_not_found"));
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "ok"
    })))
}

// ===== 管理员 API：表情项管理 =====

/// 创建表情项（管理员）
pub async fn create_item(
    State(state): State<AppState>,
    Json(payload): Json<CreateEmojiItemRequest>,
) -> Result<Json<EmojiItemResponse>, AppError> {
    if payload.image_url.trim().is_empty() {
        return Err(AppError::ValidationError(String::new())
            .with_message_key("emoji.item_image_url_required"));
    }

    let store = EmojiPackStore::new(state.database.clone());
    let item = store.create_item(payload).await?;

    if let Some(key) = item
        .image_object_key
        .as_deref()
        .map(|v| v.trim())
        .filter(|v| !v.is_empty())
    {
        let provider = load_default_storage_provider(&state).await?;
        let audit_store = FileUploadAuditStore::new(state.database.clone());
        let _ = audit_store
            .upsert_task(&provider.id, key, "emoji_item_image", "image", None, None)
            .await
            .map_err(AppError::from)?;
    }

    Ok(Json(db_item_to_api(&item)))
}

/// 获取表情项详情（管理员）
pub async fn get_item(
    State(state): State<AppState>,
    Path(item_id): Path<String>,
) -> Result<Json<EmojiItemResponse>, AppError> {
    let item_id = Uuid::parse_str(&item_id).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.item_id_invalid")
    })?;

    let store = EmojiPackStore::new(state.database.clone());
    let item = store.get_item_by_id(item_id).await?.ok_or_else(|| {
        AppError::NotFound(String::new()).with_message_key("emoji.item_not_found")
    })?;

    Ok(Json(db_item_to_api(&item)))
}

/// 更新表情项（管理员）
pub async fn update_item(
    State(state): State<AppState>,
    Path(item_id): Path<String>,
    Json(payload): Json<UpdateEmojiItemRequest>,
) -> Result<Json<EmojiItemResponse>, AppError> {
    let item_id = Uuid::parse_str(&item_id).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.item_id_invalid")
    })?;

    let store = EmojiPackStore::new(state.database.clone());
    let item = store.update_item(item_id, payload).await?.ok_or_else(|| {
        AppError::NotFound(String::new()).with_message_key("emoji.item_not_found")
    })?;

    if let Some(key) = item
        .image_object_key
        .as_deref()
        .map(|v| v.trim())
        .filter(|v| !v.is_empty())
    {
        let provider = load_default_storage_provider(&state).await?;
        let audit_store = FileUploadAuditStore::new(state.database.clone());
        let _ = audit_store
            .upsert_task(&provider.id, key, "emoji_item_image", "image", None, None)
            .await
            .map_err(AppError::from)?;
    }

    Ok(Json(db_item_to_api(&item)))
}

/// 删除表情项（管理员）
pub async fn delete_item(
    State(state): State<AppState>,
    Path(item_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let item_id = Uuid::parse_str(&item_id).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.item_id_invalid")
    })?;

    let store = EmojiPackStore::new(state.database.clone());
    let deleted = store.delete_item(item_id).await?;

    if !deleted {
        return Err(AppError::NotFound(String::new()).with_message_key("emoji.item_not_found"));
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "ok"
    })))
}

// ===== 用户 API：贴纸使用 =====

/// 获取用户的贴纸列表
pub async fn list_user_packs(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<Vec<EmojiPackWithItemsResponse>>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.user_id_invalid")
    })?;

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

/// 获取所有可用的贴纸（用于用户选择添加）
pub async fn list_available_packs(
    State(state): State<AppState>,
) -> Result<Json<Vec<EmojiPackResponse>>, AppError> {
    let store = EmojiPackStore::new(state.database.clone());
    let packs = store.list_active_packs().await?;

    let response: Vec<EmojiPackResponse> = packs.iter().map(db_pack_to_api).collect();
    Ok(Json(response))
}

/// 添加用户贴纸
pub async fn add_user_pack(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(pack_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.user_id_invalid")
    })?;
    let pack_id = Uuid::parse_str(&pack_id).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.pack_id_invalid")
    })?;

    let store = EmojiPackStore::new(state.database.clone());

    // 检查贴纸是否存在且激活
    let pack = store.get_pack_by_id(pack_id).await?.ok_or_else(|| {
        AppError::NotFound(String::new()).with_message_key("emoji.pack_not_found")
    })?;

    if !matches!(
        pack.is_active,
        crate::database::models::EmojiPackStatus::Active
    ) {
        return Err(
            AppError::ValidationError(String::new()).with_message_key("emoji.pack_inactive")
        );
    }

    store.add_user_pack(user_id, pack_id).await?;

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "ok"
    })))
}

/// 删除用户贴纸
pub async fn remove_user_pack(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(pack_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.user_id_invalid")
    })?;
    let pack_id = Uuid::parse_str(&pack_id).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.pack_id_invalid")
    })?;

    let store = EmojiPackStore::new(state.database.clone());
    let removed = store.remove_user_pack(user_id, pack_id).await?;

    if !removed {
        return Err(AppError::NotFound(String::new()).with_message_key("emoji.user_pack_not_found"));
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "ok"
    })))
}

/// 搜索贴纸和贴纸包
pub async fn search_packs(
    State(state): State<AppState>,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Vec<EmojiPackResponse>>, AppError> {
    let keyword = params.get("keyword").ok_or_else(|| {
        AppError::ValidationError(String::new()).with_message_key("emoji.search_keyword_required")
    })?;

    if keyword.trim().is_empty() {
        return Ok(Json(vec![]));
    }

    let store = EmojiPackStore::new(state.database.clone());
    let packs = store.search_packs(keyword).await?;

    let response: Vec<EmojiPackResponse> = packs.iter().map(db_pack_to_api).collect();
    Ok(Json(response))
}

/// 添加贴纸包（添加贴纸包下的所有贴纸）
pub async fn add_user_suite(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(suite_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.user_id_invalid")
    })?;
    let suite_id = Uuid::parse_str(&suite_id).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.suite_id_invalid")
    })?;

    let store = EmojiPackStore::new(state.database.clone());

    // 检查贴纸包是否存在且是贴纸包类型
    let suite = store.get_pack_by_id(suite_id).await?.ok_or_else(|| {
        AppError::NotFound(String::new()).with_message_key("emoji.suite_not_found")
    })?;

    if !matches!(
        suite.pack_type,
        crate::database::models::EmojiPackType::Suite
    ) {
        return Err(
            AppError::ValidationError(String::new()).with_message_key("emoji.suite_expected")
        );
    }

    if !matches!(
        suite.is_active,
        crate::database::models::EmojiPackStatus::Active
    ) {
        return Err(
            AppError::ValidationError(String::new()).with_message_key("emoji.suite_inactive")
        );
    }

    let count = store.add_suite_packs_to_user(user_id, suite_id).await?;

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "ok",
        "count": count
    })))
}

/// 获取用户贴纸包下的贴纸列表（只返回用户已添加的，包含表情项）
pub async fn list_user_suite_packs(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(suite_id): Path<String>,
) -> Result<Json<Vec<EmojiPackWithItemsResponse>>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.user_id_invalid")
    })?;
    let suite_id = Uuid::parse_str(&suite_id).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("emoji.suite_id_invalid")
    })?;

    let store = EmojiPackStore::new(state.database.clone());

    // 检查用户是否已添加此贴纸包
    let has_suite = store.has_user_pack(user_id, suite_id).await?;
    if !has_suite {
        return Err(
            AppError::NotFound(String::new()).with_message_key("emoji.user_suite_not_found")
        );
    }

    // 获取贴纸包下的所有贴纸（从数据库）
    let child_packs = store.list_packs_by_parent(suite_id).await?;
    tracing::info!(
        "贴纸包下找到贴纸数量: {}, suite_id={}",
        child_packs.len(),
        suite_id
    );

    // 只返回用户已添加的贴纸
    let mut result = Vec::new();
    for pack in child_packs {
        // 检查用户是否已添加此贴纸
        let has_pack = store.has_user_pack(user_id, pack.id).await?;
        tracing::debug!(
            "检查贴纸: pack_id={}, pack_name={}, has_pack={}, is_active={:?}",
            pack.id,
            pack.name,
            has_pack,
            pack.is_active
        );

        if has_pack
            && matches!(
                pack.is_active,
                crate::database::models::EmojiPackStatus::Active
            )
        {
            let items = store.list_items_by_pack(pack.id).await?;
            // 添加详细日志
            tracing::info!(
                "贴纸包贴纸: pack_id={}, pack_name={}, items_count={}, items={:?}",
                pack.id,
                pack.name,
                items.len(),
                items.iter().map(|i| i.id.to_string()).collect::<Vec<_>>()
            );
            // 如果 items 为空，记录警告
            if items.is_empty() {
                tracing::warn!(
                    "警告: 贴纸 pack_id={}, pack_name={} 的 items 为空，pack_id类型={:?}",
                    pack.id,
                    pack.name,
                    pack.id
                );
            }
            // 转换 items 为 API 响应格式
            let item_responses: Vec<EmojiItemResponse> = items.iter().map(db_item_to_api).collect();
            tracing::debug!(
                "转换后的 items: pack_id={}, items_count={}",
                pack.id,
                item_responses.len()
            );
            result.push(EmojiPackWithItemsResponse {
                pack: db_pack_to_api(&pack),
                items: item_responses,
            });
        } else {
            // 记录为什么没有包含此贴纸
            tracing::debug!(
                "跳过贴纸: pack_id={}, pack_name={}, has_pack={}, is_active={:?}",
                pack.id,
                pack.name,
                has_pack,
                pack.is_active
            );
        }
    }

    Ok(Json(result))
}

// ===== 表情图片下载 URL（用户 API）=====

#[derive(Debug, Deserialize)]
pub struct EmojiDownloadUrlQuery {
    /// COS 对象键，例如 emoji-items/xxx.gif 或 emoji-packs/icons/xxx.png
    pub object_key: String,
    /// 有效期（秒），默认 3600，范围 [60, 86400]
    pub expires_in_seconds: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct EmojiDownloadUrlResponse {
    pub success: bool,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub download_url: Option<String>,
}

/// 根据 COS 对象键生成表情图片的临时下载地址
pub async fn get_emoji_download_url(
    State(state): State<AppState>,
    Extension(_claims): Extension<Claims>,
    Query(query): Query<EmojiDownloadUrlQuery>,
) -> Result<Json<EmojiDownloadUrlResponse>, AppError> {
    let mut key_raw = query.object_key.trim().to_string();
    if key_raw.is_empty() {
        return Ok(Json(EmojiDownloadUrlResponse {
            success: false,
            message: emoji_localized_message("emoji.object_key_required", None),
            download_url: None,
        }));
    }

    // 兼容历史上存储为 URL 编码形式的对象键（例如 emoji-packs%2Ficons%2Fxxx.gif）
    if key_raw.contains('%') {
        if let Ok(decoded) = urlencoding::decode(&key_raw) {
            key_raw = decoded.into_owned();
        }
    }

    // 仅允许访问表情相关前缀，避免被滥用为通用下载接口
    if !key_raw.starts_with("emoji-items/") && !key_raw.starts_with("emoji-packs/") {
        return Err(
            AppError::ValidationError(String::new()).with_message_key("emoji.object_key_invalid")
        );
    }

    let expires = query.expires_in_seconds.unwrap_or(3600).clamp(60, 86_400);

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    let cache_key = CacheKeys::download_url_cache(&key_raw, &provider.id.to_string(), expires);
    let cache_manager = CacheManager::new(state.redis.get_cache_client().clone());

    // 优先从缓存读取
    let download_url =
        if let Ok(Some(cached)) = cache_manager.get_cached_download_url(&cache_key).await {
            info!("命中表情下载 URL 缓存: key={}", key_raw);
            cached
        } else {
            let url = storage_service
                .generate_download_url(&key_raw, Some(expires))
                .await?;

            let cache_ttl = (expires as f64 * 0.9) as u64;
            if let Err(e) = cache_manager
                .cache_download_url(&cache_key, &url, cache_ttl)
                .await
            {
                warn!("缓存表情下载 URL 失败: {:?}", e);
            } else {
                info!("缓存表情下载 URL 成功: key={}, ttl={}s", key_raw, cache_ttl);
            }

            url
        };

    Ok(Json(EmojiDownloadUrlResponse {
        success: true,
        message: "ok".to_string(),
        download_url: Some(download_url),
    }))
}

#[cfg(test)]
mod tests {
    #[test]
    fn emoji_download_url_empty_object_key_should_use_catalog_message() {
        let source = include_str!("emoji_pack.rs");

        assert!(
            source.contains("emoji_localized_message(\"emoji.object_key_required\", None)"),
            "emoji download url handler should use emoji.object_key_required catalog message"
        );
    }

    #[test]
    fn emoji_download_url_should_not_embed_legacy_object_key_literal() {
        let source = include_str!("emoji_pack.rs");
        let legacy = ["object_key ", "\u{4e0d}\u{80fd}\u{4e3a}\u{7a7a}"].concat();

        assert!(
            !source.contains(&legacy),
            "emoji download url handler should not embed legacy object_key literal"
        );
    }
}
