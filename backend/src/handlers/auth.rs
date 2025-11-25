use crate::auth::{generate_token, hash_password};
use crate::database::models::AdminUserStatus;
use crate::database::settings_store::SettingsStore;
use crate::database::user_store::UserStore;
use crate::error::AppError;
use crate::handlers::admin;
use crate::handlers::user;
use crate::models::convert::{
    api_create_user_to_db, api_login_to_db, db_user_to_api_user_info, string_to_uuid,
};
use crate::models::UserStatus;
use crate::models::{Claims, CreateUserRequest, LoginRequest, LoginResponse, UserInfo};
use crate::storage;
use crate::AppState;
use axum::{
    extract::{Extension, State},
    response::Json,
};
use rand::{distributions::Alphanumeric, thread_rng, Rng};
use redis::AsyncCommands;
use serde::{Deserialize, Serialize};
use tracing::info;

pub async fn register(
    State(state): State<AppState>,
    Json(payload): Json<CreateUserRequest>,
) -> Result<Json<UserInfo>, AppError> {
    // 基础验证
    if payload.username.len() < 3 {
        return Err(AppError::ValidationError(
            "用户名长度至少为 3 个字符".to_string(),
        ));
    }

    if payload.password.len() < 6 {
        return Err(AppError::ValidationError(
            "密码长度至少为 6 个字符".to_string(),
        ));
    }

    // 邮箱自动生成：手机号 + @example.com
    let email = format!("{}@example.com", payload.username);

    let store = UserStore::new(state.database.clone());

    // 唯一性检查：用户名（手机号）必须唯一
    if store.username_exists(&payload.username).await? {
        return Err(AppError::AlreadyExists(format!(
            "手机号 {} 已被使用",
            payload.username
        )));
    }

    // 检查邮箱是否已存在（虽然自动生成，但需要检查）
    if store.email_exists(&email).await? {
        return Err(AppError::AlreadyExists(format!(
            "该手机号对应的邮箱已被使用",
        )));
    }

    // 创建请求，使用自动生成的邮箱
    let mut create_request = payload.clone();
    create_request.email = email;

    // 转换为数据库层请求
    let mut db_req = api_create_user_to_db(&create_request);
    if db_req
        .nickname
        .as_ref()
        .map(|n| n.trim().is_empty())
        .unwrap_or(true)
    {
        db_req.nickname = Some(payload.username.clone());
    }
    let db_user = store.create_user(db_req).await?;

    info!("User registered successfully: {}", db_user.username);

    // 转换为 API 层响应
    let user_info = db_user_to_api_user_info(&db_user);
    Ok(Json(user_info))
}

pub async fn login(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    let store = UserStore::new(state.database.clone());

    // 转换为数据库层请求
    let db_req = api_login_to_db(&payload);

    let db_user = match store.authenticate(db_req).await? {
        Some(u) => u,
        None => {
            return Err(AppError::InvalidCredentials);
        }
    };

    // 检查用户封禁状态
    if db_user.status == crate::database::models::UserStatus::Banned {
        return Err(AppError::Forbidden("账户已被封禁，无法登录".to_string()));
    }

    info!("User logged in successfully: {}", db_user.username);

    // 生成 JWT token
    let claims = Claims {
        sub: db_user.id.to_string(),
        username: db_user.username.clone(),
        exp: (chrono::Utc::now() + chrono::Duration::hours(24)).timestamp() as usize,
        iat: chrono::Utc::now().timestamp() as usize,
    };

    let token =
        generate_token(&claims).map_err(|_| AppError::InternalError("生成令牌失败".to_string()))?;

    let response = LoginResponse {
        token,
        user: db_user_to_api_user_info(&db_user),
    };

    Ok(Json(response))
}

#[derive(Debug, serde::Deserialize)]
pub struct SendSmsRequest {
    pub phone: String,
}

#[derive(Debug, serde::Deserialize)]
pub struct SmsLoginRequest {
    pub phone: String,
    pub code: String,
}

#[derive(Debug, Serialize)]
pub struct SmsResponse<'a> {
    success: bool,
    message: &'a str,
}

#[derive(Debug, serde::Deserialize)]
pub struct ResetPasswordRequest {
    pub phone: String,
    pub code: String,
    pub new_password: String,
}

pub async fn send_login_sms(
    State(state): State<AppState>,
    Json(payload): Json<SendSmsRequest>,
) -> Result<Json<SmsResponse<'static>>, AppError> {
    let phone = payload.phone.trim();
    if phone.is_empty() {
        return Err(AppError::ValidationError("手机号不能为空".to_string()));
    }

    // 检查是否开启登录/注册验证码
    let settings_store = SettingsStore::new(state.database.clone());
    let require_captcha = settings_store
        .require_captcha_for_login()
        .await
        .unwrap_or(false);
    if !require_captcha {
        return Err(AppError::ValidationError(
            "验证码登录功能已关闭，请使用密码登录".to_string(),
        ));
    }

    let code: u32 = thread_rng().gen_range(100000..=999999);
    let key = format!("auth:sms:{}", phone);

    let mut conn = state
        .redis
        .get_cache_client()
        .get_multiplexed_async_connection()
        .await
        .map_err(|_| AppError::CacheError("Redis 连接失败".to_string()))?;

    conn.set_ex::<_, _, ()>(&key, code.to_string(), 300)
        .await
        .map_err(|_| AppError::CacheError("Redis 设置失败".to_string()))?;

    info!("发送登录验证码 {} -> {}", phone, code);

    Ok(Json(SmsResponse {
        success: true,
        message: "验证码已发送",
    }))
}

pub async fn login_with_sms(
    State(state): State<AppState>,
    Json(payload): Json<SmsLoginRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    let phone = payload.phone.trim();
    let code = payload.code.trim();

    if phone.is_empty() || code.is_empty() {
        return Err(AppError::ValidationError(
            "手机号和验证码不能为空".to_string(),
        ));
    }

    // 检查是否开启登录/注册验证码
    let settings_store = SettingsStore::new(state.database.clone());
    let require_captcha = settings_store
        .require_captcha_for_login()
        .await
        .unwrap_or(false);
    if !require_captcha {
        return Err(AppError::ValidationError(
            "验证码登录功能已关闭，请使用密码登录".to_string(),
        ));
    }

    let key = format!("auth:sms:{}", phone);
    let mut conn = state
        .redis
        .get_cache_client()
        .get_multiplexed_async_connection()
        .await
        .map_err(|_| AppError::CacheError("Redis 连接失败".to_string()))?;

    let stored: Option<String> = conn
        .get(&key)
        .await
        .map_err(|_| AppError::CacheError("Redis 获取失败".to_string()))?;

    let redis_matched = stored
        .as_ref()
        .map(|expected| expected == code)
        .unwrap_or(false);
    let universal_matched = admin::is_universal_captcha_code(&state, code).await;

    if !redis_matched && !universal_matched {
        return Err(AppError::ValidationError("验证码错误或已过期".to_string()));
    }

    if universal_matched {
        info!("用户 {} 使用通用验证码登录", phone);
    }

    let store = UserStore::new(state.database.clone());
    let db_user = match store.find_by_username(phone).await? {
        Some(user) => {
            // 检查用户封禁状态
            if user.status == crate::database::models::UserStatus::Banned {
                return Err(AppError::Forbidden("账户已被封禁，无法登录".to_string()));
            }
            user
        }
        None => {
            let auto_request = build_auto_registration_request(phone);
            let db_request = api_create_user_to_db(&auto_request);

            match store.create_user(db_request).await {
                Ok(user) => {
                    info!("用户 {} 未注册，已通过验证码登录自动创建账号", phone);
                    user
                }
                Err(sqlx::Error::Database(db_err)) if db_err.code().as_deref() == Some("23505") => {
                    info!(
                        "检测到用户名 {} 正在并发注册或已存在，自动重试获取账号",
                        phone
                    );
                    match store.find_by_username(phone).await? {
                        Some(existing) => {
                            // 检查用户封禁状态
                            if existing.status == crate::database::models::UserStatus::Banned {
                                return Err(AppError::Forbidden(
                                    "账户已被封禁，无法登录".to_string(),
                                ));
                            }
                            existing
                        }
                        None => {
                            return Err(AppError::ValidationError(
                                "该账号已存在但当前不可登录，请联系管理员".to_string(),
                            ));
                        }
                    }
                }
                Err(err) => {
                    tracing::error!(
                        error = ?err,
                        "通过验证码登录自动注册账号 {} 失败",
                        phone
                    );
                    return Err(AppError::InternalError(
                        "自动注册失败，请稍后重试".to_string(),
                    ));
                }
            }
        }
    };

    if redis_matched {
        // 一次性验证码，使用后删除
        let _: () = conn
            .del(&key)
            .await
            .map_err(|_| AppError::CacheError("Redis 删除失败".to_string()))?;
    }

    let claims = Claims {
        sub: db_user.id.to_string(),
        username: db_user.username.clone(),
        exp: (chrono::Utc::now() + chrono::Duration::hours(24)).timestamp() as usize,
        iat: chrono::Utc::now().timestamp() as usize,
    };

    let token =
        generate_token(&claims).map_err(|_| AppError::InternalError("生成令牌失败".to_string()))?;

    let response = LoginResponse {
        token,
        user: db_user_to_api_user_info(&db_user),
    };

    Ok(Json(response))
}

pub async fn reset_password_with_sms(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<ResetPasswordRequest>,
) -> Result<Json<SmsResponse<'static>>, AppError> {
    let phone = payload.phone.trim();
    let code = payload.code.trim();
    let new_password = payload.new_password.trim();

    if phone.is_empty() || code.is_empty() || new_password.is_empty() {
        return Err(AppError::ValidationError(
            "手机号、验证码和新密码均不能为空".to_string(),
        ));
    }

    if new_password.len() < 6 {
        return Err(AppError::ValidationError(
            "新密码长度至少为 6 个字符".to_string(),
        ));
    }

    // 仅允许重置当前登录用户的密码
    if claims.username != phone {
        return Err(AppError::Forbidden("仅可重置当前账号的密码".to_string()));
    }

    let key = format!("auth:sms:{}", phone);
    let mut conn = state
        .redis
        .get_cache_client()
        .get_multiplexed_async_connection()
        .await
        .map_err(|_| AppError::CacheError("Redis 连接失败".to_string()))?;

    let stored: Option<String> = conn
        .get(&key)
        .await
        .map_err(|_| AppError::CacheError("Redis 获取失败".to_string()))?;

    if stored.as_deref() != Some(code) {
        return Err(AppError::ValidationError("验证码错误或已过期".to_string()));
    }

    // 校验完成，删除验证码
    let _: () = conn
        .del(&key)
        .await
        .map_err(|_| AppError::CacheError("Redis 删除失败".to_string()))?;

    let user_store = UserStore::new(state.database.clone());
    let db_user = user_store
        .find_by_username(phone)
        .await?
        .ok_or_else(|| AppError::NotFound("用户不存在".to_string()))?;

    let password_hash = hash_password(new_password)
        .map_err(|_| AppError::InternalError("密码加密失败".to_string()))?;

    user_store
        .update_password(&db_user.id, &password_hash)
        .await?;

    Ok(Json(SmsResponse {
        success: true,
        message: "密码已重置，请使用新密码登录",
    }))
}

fn build_auto_registration_request(username: &str) -> CreateUserRequest {
    CreateUserRequest {
        username: username.to_string(),
        email: build_auto_registration_email(username),
        password: build_auto_registration_password(username),
        nickname: Some(username.to_string()),
    }
}

fn build_auto_registration_email(username: &str) -> String {
    // 自动注册时，邮箱 = 手机号 + @example.com
    format!("{}@example.com", username)
}

fn build_auto_registration_password(username: &str) -> String {
    let rng = thread_rng();
    let mut prefix: String = username
        .chars()
        .filter(|c| c.is_ascii_digit())
        .take(4)
        .collect();

    if prefix.is_empty() {
        prefix.push_str("rcim");
    } else if prefix.len() < 4 {
        while prefix.len() < 4 {
            prefix.push('0');
        }
    }

    let mut password = prefix;
    password.extend(rng.sample_iter(&Alphanumeric).take(8).map(char::from));

    if !password.chars().any(|c| c.is_ascii_lowercase()) {
        password.push('a');
    }
    if !password.chars().any(|c| c.is_ascii_uppercase()) {
        password.push('A');
    }
    if !password.chars().any(|c| c.is_ascii_digit()) {
        password.push('7');
    }

    password
}

pub async fn get_current_user(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<UserInfo>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let store = UserStore::new(state.database.clone());

    let db_user = store
        .find_by_id(&user_id)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("用户 {} 不存在", user_id)))?;

    Ok(Json(db_user_to_api_user_info(&db_user)))
}

/// 管理员登录
pub async fn admin_login(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    // 基础验证
    if payload.username.trim().is_empty() || payload.password.trim().is_empty() {
        return Err(AppError::ValidationError(
            "用户名和密码不能为空".to_string(),
        ));
    }

    let store = admin::AdminUserStore::new(state.database.clone());

    let db_admin_user = match store
        .authenticate(crate::models::LoginRequest {
            username: payload.username.clone(),
            password: payload.password.clone(),
        })
        .await?
    {
        Some(u) => u,
        None => {
            return Err(AppError::InvalidCredentials);
        }
    };

    // 检查账户状态
    if db_admin_user.status != AdminUserStatus::Active {
        return Err(AppError::Forbidden("账户已被禁用或锁定".to_string()));
    }

    // 检查账户是否被锁定
    if let Some(locked_until) = db_admin_user.locked_until {
        if locked_until > chrono::Utc::now() {
            return Err(AppError::Forbidden("账户已被临时锁定".to_string()));
        }
    }

    // 记录登录历史
    let client_ip = None; // TODO: 从请求中获取客户端IP
    let user_agent = None; // TODO: 从请求中获取User-Agent

    if let Err(e) = store
        .record_login_history(
            &db_admin_user.id,
            client_ip.map(|ip: std::net::IpAddr| ip.into()),
            user_agent,
            true,
            None,
        )
        .await
    {
        tracing::warn!("记录管理员登录历史失败: {:?}", e);
    }

    // 更新最后登录时间和重置登录尝试次数
    if let Err(e) = store.update_login_info(&db_admin_user.id).await {
        tracing::warn!("更新管理员登录信息失败: {:?}", e);
    }

    info!(
        "Admin user logged in successfully: {}",
        db_admin_user.username
    );

    // 生成 JWT token（可设置更短的过期时间以提高安全性）
    let claims = Claims {
        sub: db_admin_user.id.to_string(),
        username: db_admin_user.username.clone(),
        exp: (chrono::Utc::now() + chrono::Duration::hours(8)).timestamp() as usize, // 8小时过期
        iat: chrono::Utc::now().timestamp() as usize,
    };

    let token =
        generate_token(&claims).map_err(|_| AppError::InternalError("生成令牌失败".to_string()))?;

    let response = LoginResponse {
        token,
        user: UserInfo {
            id: db_admin_user.id.to_string(),
            username: db_admin_user.username.clone(),
            email: db_admin_user.email.clone(),
            nickname: db_admin_user.nickname.clone(),
            avatar_url: db_admin_user.avatar_url.clone(),
            avatar_object_key: None,
            status: match db_admin_user.status {
                AdminUserStatus::Active => UserStatus::Active,
                AdminUserStatus::Inactive => UserStatus::Inactive,
                AdminUserStatus::Banned => UserStatus::Banned,
                AdminUserStatus::Locked => UserStatus::Banned,
            },
        },
    };

    Ok(Json(response))
}

/// 获取当前管理员用户信息
pub async fn get_current_admin_user(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<admin::AdminUserInfo>, AppError> {
    let admin_user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid admin user ID in token: {}", e)))?;

    let store = admin::AdminUserStore::new(state.database.clone());

    let db_admin_user = store
        .find_by_id(&admin_user_id)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("管理员用户 {} 不存在", admin_user_id)))?;

    // 转换为 API 层响应
    let admin_user_info = admin::AdminUserInfo {
        id: db_admin_user.id.to_string(),
        username: db_admin_user.username.clone(),
        email: db_admin_user.email.clone(),
        nickname: db_admin_user.nickname.clone(),
        avatar_url: db_admin_user.avatar_url.clone(),
        status: match db_admin_user.status {
            AdminUserStatus::Active => "active".to_string(),
            AdminUserStatus::Inactive => "inactive".to_string(),
            AdminUserStatus::Banned => "banned".to_string(),
            AdminUserStatus::Locked => "locked".to_string(),
        },
        last_login_at: db_admin_user.last_login_at.map(|dt| dt.to_rfc3339()),
        created_at: db_admin_user.created_at.to_rfc3339(),
        updated_at: db_admin_user.updated_at.to_rfc3339(),
    };
    Ok(Json(admin_user_info))
}

/// 更新当前管理员用户信息
#[derive(Debug, Deserialize)]
pub struct UpdateAdminUserRequest {
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct UpdateAdminUserResponse {
    pub success: bool,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<admin::AdminUserInfo>,
}

pub async fn update_current_admin_user(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<UpdateAdminUserRequest>,
) -> Result<Json<UpdateAdminUserResponse>, AppError> {
    let admin_user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid admin user ID in token: {}", e)))?;

    tracing::info!(
        "更新管理员用户信息: id={}, nickname={:?}, avatar_url={:?}",
        admin_user_id,
        payload.nickname,
        payload.avatar_url
    );

    let store = admin::AdminUserStore::new(state.database.clone());

    let updated_user = store
        .update_admin_user(&admin_user_id, payload.nickname, payload.avatar_url)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("管理员用户 {} 不存在", admin_user_id)))?;

    tracing::info!("更新成功: avatar_url={:?}", updated_user.avatar_url);

    // 转换为 API 层响应
    let admin_user_info = admin::AdminUserInfo {
        id: updated_user.id.to_string(),
        username: updated_user.username.clone(),
        email: updated_user.email.clone(),
        nickname: updated_user.nickname.clone(),
        avatar_url: updated_user.avatar_url.clone(),
        status: match updated_user.status {
            AdminUserStatus::Active => "active".to_string(),
            AdminUserStatus::Inactive => "inactive".to_string(),
            AdminUserStatus::Banned => "banned".to_string(),
            AdminUserStatus::Locked => "locked".to_string(),
        },
        last_login_at: updated_user.last_login_at.map(|dt| dt.to_rfc3339()),
        created_at: updated_user.created_at.to_rfc3339(),
        updated_at: updated_user.updated_at.to_rfc3339(),
    };

    Ok(Json(UpdateAdminUserResponse {
        success: true,
        message: "更新成功".to_string(),
        data: Some(admin_user_info),
    }))
}

/// 重置当前管理员用户密码
#[derive(Debug, Deserialize)]
pub struct ChangeAdminPasswordRequest {
    pub new_password: String,
}

#[derive(Debug, Serialize)]
pub struct ChangeAdminPasswordResponse {
    pub success: bool,
    pub message: String,
}

pub async fn change_current_admin_password(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<ChangeAdminPasswordRequest>,
) -> Result<Json<ChangeAdminPasswordResponse>, AppError> {
    let admin_user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid admin user ID in token: {}", e)))?;

    let store = admin::AdminUserStore::new(state.database.clone());

    // 验证新密码强度
    if payload.new_password.len() < 8 {
        return Err(AppError::ValidationError(
            "新密码长度至少为 8 个字符".to_string(),
        ));
    }

    if !payload.new_password.chars().any(|c| c.is_ascii_alphabetic())
        || !payload.new_password.chars().any(|c| c.is_ascii_digit())
    {
        return Err(AppError::ValidationError(
            "新密码必须包含字母和数字".to_string(),
        ));
    }

    // 加密新密码
    let new_password_hash = hash_password(&payload.new_password)
        .map_err(|_| AppError::InternalError("密码加密失败".to_string()))?;

    // 更新密码
    let updated = store.update_password(&admin_user_id, &new_password_hash).await?;

    if !updated {
        return Err(AppError::InternalError("更新密码失败".to_string()));
    }

    Ok(Json(ChangeAdminPasswordResponse {
        success: true,
        message: "密码重置成功".to_string(),
    }))
}

/// 上传当前管理员用户头像
#[derive(Debug, Serialize)]
pub struct UploadAdminAvatarResponse {
    pub success: bool,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub avatar_url: Option<String>,
}

pub async fn upload_current_admin_avatar(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    mut multipart: axum::extract::Multipart,
) -> Result<Json<UploadAdminAvatarResponse>, AppError> {
    let admin_user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid admin user ID in token: {}", e)))?;

    // 从 multipart 中获取文件
    let mut avatar_file = None;
    let mut content_type = None;

    while let Some(field) = multipart.next_field().await.map_err(|e| {
        AppError::InternalError(format!("读取上传文件失败: {}", e))
    })? {
        if field.name() == Some("avatar") {
            // 先获取 content_type，再读取数据
            content_type = field.content_type().map(|s| s.to_string());

            let data = field.bytes().await.map_err(|e| {
                AppError::InternalError(format!("读取文件数据失败: {}", e))
            })?;

            // 验证文件大小 (5MB)
            if data.len() > 5 * 1024 * 1024 {
                return Err(AppError::ValidationError(
                    "文件大小不能超过 5MB".to_string(),
                ));
            }

            avatar_file = Some(data);
            break;
        }
    }

    if avatar_file.is_none() {
        return Err(AppError::ValidationError("请选择要上传的头像文件".to_string()));
    }

    let file_data = avatar_file.unwrap();
    let content_type = content_type.unwrap_or_else(|| "image/jpeg".to_string());

    // 验证文件类型
    if !content_type.starts_with("image/") {
        return Err(AppError::ValidationError(
            "只支持上传图片文件".to_string(),
        ));
    }

    // 生成文件名
    let file_ext = match content_type.as_str() {
        "image/png" => "png",
        "image/jpeg" => "jpg",
        "image/gif" => "gif",
        "image/webp" => "webp",
        _ => "jpg",
    };

    let file_key = format!("admin/avatars/{}.{}", admin_user_id, file_ext);

    // 获取默认存储提供商
    let provider = user::load_default_storage_provider(&state).await?;

    // 创建存储服务实例
    let storage_service = storage::create_storage_service(&provider)
        .map_err(|e| AppError::InternalError(format!("创建存储服务失败: {}", e)))?;

    // 上传到存储
    let file_url = storage_service
        .upload_file(&file_key, file_data, Some(&content_type))
        .await
        .map_err(|e| AppError::InternalError(format!("上传文件失败: {}", e)))?;

    // 更新用户头像URL
    let store = admin::AdminUserStore::new(state.database.clone());
    let updated_user = store
        .update_admin_user(&admin_user_id, None, Some(file_url.clone()))
        .await?
        .ok_or_else(|| AppError::NotFound(format!("管理员用户 {} 不存在", admin_user_id)))?;

    Ok(Json(UploadAdminAvatarResponse {
        success: true,
        message: "头像上传成功".to_string(),
        avatar_url: Some(file_url),
    }))
}
