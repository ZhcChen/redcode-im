use crate::auth::{generate_token, hash_password};
use crate::database::user_store::UserStore;
use crate::error::AppError;
use crate::handlers::admin;
use crate::models::convert::{
    api_create_user_to_db, api_login_to_db, db_user_to_api_user_info, string_to_uuid,
};
use crate::models::{Claims, CreateUserRequest, LoginRequest, LoginResponse, UserInfo};
use crate::AppState;
use axum::{
    extract::{Extension, State},
    response::Json,
};
use rand::{distributions::Alphanumeric, thread_rng, Rng};
use redis::AsyncCommands;
use serde::Serialize;
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

    if !payload.email.contains('@') {
        return Err(AppError::ValidationError("邮箱格式不正确".to_string()));
    }

    let store = UserStore::new(state.database.clone());

    // 唯一性检查
    if store.username_exists(&payload.username).await? {
        return Err(AppError::AlreadyExists(format!(
            "用户名 {} 已被使用",
            payload.username
        )));
    }

    if store.email_exists(&payload.email).await? {
        return Err(AppError::AlreadyExists(format!(
            "邮箱 {} 已被使用",
            payload.email
        )));
    }

    // 转换为数据库层请求
    let mut db_req = api_create_user_to_db(&payload);
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

    info!("User logged in successfully: {}", db_user.username);

    // 生成 JWT token
    let claims = Claims {
        sub: db_user.id.to_string(),
        username: db_user.username.clone(),
        exp: (chrono::Utc::now() + chrono::Duration::hours(24)).timestamp() as usize,
        iat: chrono::Utc::now().timestamp() as usize,
    };

    let token = generate_token(&claims)
        .map_err(|e| AppError::InternalError(format!("Failed to generate token: {}", e)))?;

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

    let code: u32 = thread_rng().gen_range(100000..=999999);
    let key = format!("auth:sms:{}", phone);

    let mut conn = state
        .redis
        .get_cache_client()
        .get_multiplexed_async_connection()
        .await
        .map_err(|e| AppError::CacheError(format!("Redis connection failed: {}", e)))?;

    conn.set_ex::<_, _, ()>(&key, code.to_string(), 300)
        .await
        .map_err(|e| AppError::CacheError(format!("Redis set_ex failed: {}", e)))?;

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

    let key = format!("auth:sms:{}", phone);
    let mut conn = state
        .redis
        .get_cache_client()
        .get_multiplexed_async_connection()
        .await
        .map_err(|e| AppError::CacheError(format!("Redis connection failed: {}", e)))?;

    let stored: Option<String> = conn
        .get(&key)
        .await
        .map_err(|e| AppError::CacheError(format!("Redis get failed: {}", e)))?;

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
        Some(user) => user,
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
                        Some(existing) => existing,
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
            .map_err(|e| AppError::CacheError(format!("Redis del failed: {}", e)))?;
    }

    let claims = Claims {
        sub: db_user.id.to_string(),
        username: db_user.username.clone(),
        exp: (chrono::Utc::now() + chrono::Duration::hours(24)).timestamp() as usize,
        iat: chrono::Utc::now().timestamp() as usize,
    };

    let token = generate_token(&claims)
        .map_err(|e| AppError::InternalError(format!("Failed to generate token: {}", e)))?;

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
        .map_err(|e| AppError::CacheError(format!("Redis connection failed: {}", e)))?;

    let stored: Option<String> = conn
        .get(&key)
        .await
        .map_err(|e| AppError::CacheError(format!("Redis get failed: {}", e)))?;

    if stored.as_deref() != Some(code) {
        return Err(AppError::ValidationError("验证码错误或已过期".to_string()));
    }

    // 校验完成，删除验证码
    let _: () = conn
        .del(&key)
        .await
        .map_err(|e| AppError::CacheError(format!("Redis del failed: {}", e)))?;

    let user_store = UserStore::new(state.database.clone());
    let db_user = user_store
        .find_by_username(phone)
        .await?
        .ok_or_else(|| AppError::NotFound("用户不存在".to_string()))?;

    let password_hash = hash_password(new_password)
        .map_err(|e| AppError::InternalError(format!("Password hashing failed: {}", e)))?;

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
    let normalized: String = username
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .collect::<String>()
        .to_lowercase();

    let local_part = if normalized.is_empty() {
        crate::id::generate().to_string().replace('-', "")
    } else {
        normalized
    };

    format!("{}@auto.redcode-im", local_part)
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
        .ok_or_else(|| AppError::NotFound(format!("User {} not found", user_id)))?;

    Ok(Json(db_user_to_api_user_info(&db_user)))
}
