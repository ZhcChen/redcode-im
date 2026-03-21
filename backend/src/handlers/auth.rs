use crate::auth::{generate_token, hash_password};
use crate::database::models::AdminUserStatus;
use crate::database::models::UpdateUserRequest as DbUpdateUserRequest;
use crate::database::settings_store::SettingsStore;
use crate::database::user_store::UserStore;
use crate::error::AppError;
use crate::handlers::admin;
use crate::models::convert::{
    api_create_user_to_db, api_login_to_db, db_user_to_api_user_info, string_to_uuid,
};
use crate::models::UserStatus;
use crate::models::{Claims, CreateUserRequest, LoginRequest, LoginResponse, OAuthLoginRequest, UserInfo};
use crate::AppState;
use axum::{
    extract::{Extension, State},
    http::HeaderMap,
    response::Json,
};
use jsonwebtoken::{decode, decode_header, Algorithm, DecodingKey, Validation};
use once_cell::sync::Lazy;
use reqwest::Client;
use rand::{distributions::Alphanumeric, thread_rng, Rng};
use redis::AsyncCommands;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::env;
use std::time::{Duration, Instant};
use tokio::sync::RwLock;
use tracing::info;

/// 刷新令牌在 Redis 中的存储前缀
const REFRESH_TOKEN_PREFIX: &str = "auth:refresh:";
/// 刷新令牌的滑动有效期（30 天）
const REFRESH_TOKEN_TTL_SECONDS: usize = 30 * 24 * 60 * 60;

/// Google OIDC JWKS（用于校验 Google ID Token）
const DEFAULT_GOOGLE_JWKS_URL: &str = "https://www.googleapis.com/oauth2/v3/certs";
/// Apple OIDC JWKS（用于校验 Sign in with Apple ID Token）
const DEFAULT_APPLE_JWKS_URL: &str = "https://appleid.apple.com/auth/keys";
const JWKS_CACHE_TTL: Duration = Duration::from_secs(60 * 60);

static OIDC_HTTP_CLIENT: Lazy<Client> = Lazy::new(Client::new);
static JWKS_CACHE: Lazy<RwLock<HashMap<String, CachedJwks>>> =
    Lazy::new(|| RwLock::new(HashMap::new()));

#[derive(Debug, Deserialize)]
struct JwksResponse {
    keys: Vec<JwkKey>,
}

#[derive(Debug, Deserialize)]
struct JwkKey {
    kid: String,
    kty: Option<String>,
    n: Option<String>,
    e: Option<String>,
}

#[derive(Debug, Clone)]
struct CachedJwks {
    fetched_at: Instant,
    keys: HashMap<String, (String, String)>,
}

#[derive(Debug)]
struct ExternalIdentity {
    provider: &'static str,
    provider_user_id: String,
    email: Option<String>,
    display_name: Option<String>,
    avatar_url: Option<String>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct GoogleIdTokenClaims {
    sub: String,
    email: Option<String>,
    name: Option<String>,
    picture: Option<String>,
    exp: usize,
    iat: usize,
    iss: Option<String>,
    aud: Option<String>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct AppleIdTokenClaims {
    sub: String,
    email: Option<String>,
    exp: usize,
    iat: usize,
    iss: Option<String>,
    aud: Option<String>,
}

fn google_jwks_url() -> String {
    env::var("GOOGLE_OIDC_JWKS_URL").unwrap_or_else(|_| DEFAULT_GOOGLE_JWKS_URL.to_string())
}

fn apple_jwks_url() -> String {
    env::var("APPLE_OIDC_JWKS_URL").unwrap_or_else(|_| DEFAULT_APPLE_JWKS_URL.to_string())
}

async fn fetch_jwks(jwks_url: &str) -> Result<CachedJwks, AppError> {
    let resp = OIDC_HTTP_CLIENT
        .get(jwks_url)
        .send()
        .await
        .map_err(|e| AppError::ServiceUnavailable(format!("获取第三方公钥失败: {}", e)))?;

    if !resp.status().is_success() {
        return Err(AppError::ServiceUnavailable(format!(
            "获取第三方公钥失败: HTTP {}",
            resp.status().as_u16()
        )));
    }

    let parsed: JwksResponse = resp
        .json()
        .await
        .map_err(|e| AppError::ServiceUnavailable(format!("解析第三方公钥失败: {}", e)))?;

    let mut keys = HashMap::new();
    for key in parsed.keys {
        if key.kty.as_deref() != Some("RSA") {
            continue;
        }
        let (Some(n), Some(e)) = (key.n, key.e) else {
            continue;
        };
        keys.insert(key.kid, (n, e));
    }

    Ok(CachedJwks {
        fetched_at: Instant::now(),
        keys,
    })
}

async fn get_rsa_components(jwks_url: &str, kid: &str) -> Result<(String, String), AppError> {
    {
        let cache = JWKS_CACHE.read().await;
        if let Some(entry) = cache.get(jwks_url) {
            if entry.fetched_at.elapsed() < JWKS_CACHE_TTL {
                if let Some((n, e)) = entry.keys.get(kid) {
                    return Ok((n.clone(), e.clone()));
                }
            }
        }
    }

    let fetched = fetch_jwks(jwks_url).await?;
    {
        let mut cache = JWKS_CACHE.write().await;
        cache.insert(jwks_url.to_string(), fetched.clone());
    }

    fetched
        .keys
        .get(kid)
        .cloned()
        .ok_or_else(|| AppError::InvalidToken("第三方令牌无效或已过期".to_string()))
}

fn build_oauth_username(provider: &str, provider_user_id: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(provider_user_id.as_bytes());
    let digest = hasher.finalize();
    let hex = hex::encode(digest);
    // provider + '_' + 16 chars = 1 + 16 + provider length，确保 < 50
    let short = &hex[..16.min(hex.len())];
    format!("{}_{}", provider, short)
}

fn build_random_password(len: usize) -> String {
    thread_rng()
        .sample_iter(&Alphanumeric)
        .take(len)
        .map(char::from)
        .collect()
}

async fn verify_google_id_token(id_token: &str) -> Result<ExternalIdentity, AppError> {
    let client_id = env::var("GOOGLE_OAUTH_CLIENT_ID").map_err(|_| {
        AppError::ServiceUnavailable("GOOGLE_OAUTH_CLIENT_ID 未配置，无法使用 Google 登录".to_string())
    })?;

    let header = decode_header(id_token)
        .map_err(|_| AppError::InvalidToken("第三方令牌格式无效".to_string()))?;
    let kid = header
        .kid
        .ok_or_else(|| AppError::InvalidToken("第三方令牌缺少 kid".to_string()))?;

    let jwks_url = google_jwks_url();
    let (n, e) = get_rsa_components(&jwks_url, &kid).await?;
    let key = DecodingKey::from_rsa_components(&n, &e)
        .map_err(|_| AppError::InvalidToken("第三方公钥无效".to_string()))?;

    let mut validation = Validation::new(Algorithm::RS256);
    validation.set_audience(&[client_id.as_str()]);
    validation.set_issuer(&["accounts.google.com", "https://accounts.google.com"]);

    let claims = decode::<GoogleIdTokenClaims>(id_token, &key, &validation)
        .map_err(|_| AppError::InvalidToken("第三方令牌校验失败".to_string()))?
        .claims;

    Ok(ExternalIdentity {
        provider: "google",
        provider_user_id: claims.sub,
        email: claims.email,
        display_name: claims.name,
        avatar_url: claims.picture,
    })
}

async fn verify_apple_id_token(id_token: &str) -> Result<ExternalIdentity, AppError> {
    let client_id = env::var("APPLE_OAUTH_CLIENT_ID").map_err(|_| {
        AppError::ServiceUnavailable("APPLE_OAUTH_CLIENT_ID 未配置，无法使用 Apple 登录".to_string())
    })?;

    let header = decode_header(id_token)
        .map_err(|_| AppError::InvalidToken("第三方令牌格式无效".to_string()))?;
    let kid = header
        .kid
        .ok_or_else(|| AppError::InvalidToken("第三方令牌缺少 kid".to_string()))?;

    let jwks_url = apple_jwks_url();
    let (n, e) = get_rsa_components(&jwks_url, &kid).await?;
    let key = DecodingKey::from_rsa_components(&n, &e)
        .map_err(|_| AppError::InvalidToken("第三方公钥无效".to_string()))?;

    let mut validation = Validation::new(Algorithm::RS256);
    validation.set_audience(&[client_id.as_str()]);
    validation.set_issuer(&["https://appleid.apple.com"]);

    let claims = decode::<AppleIdTokenClaims>(id_token, &key, &validation)
        .map_err(|_| AppError::InvalidToken("第三方令牌校验失败".to_string()))?
        .claims;

    Ok(ExternalIdentity {
        provider: "apple",
        provider_user_id: claims.sub,
        email: claims.email,
        display_name: None,
        avatar_url: None,
    })
}

/// 刷新令牌在 Redis 中存储的内容
#[derive(Debug, Serialize, Deserialize)]
struct RefreshTokenPayload {
    user_id: String,
    is_admin: bool,
}

/// 生成刷新令牌并写入 Redis，返回明文刷新令牌
async fn generate_and_store_refresh_token(
    state: &AppState,
    user_id: &str,
    is_admin: bool,
) -> Result<String, AppError> {
    let refresh_token = uuid::Uuid::new_v4().to_string();
    let key = format!("{}{}", REFRESH_TOKEN_PREFIX, refresh_token);

    let payload = RefreshTokenPayload {
        user_id: user_id.to_string(),
        is_admin,
    };
    let value = serde_json::to_string(&payload)
        .map_err(|_| AppError::InternalError("刷新令牌序列化失败".to_string()))?;

    let mut conn = state
        .redis
        .get_cache_client()
        .get_multiplexed_async_connection()
        .await
        .map_err(|_| AppError::CacheError("Redis 连接失败".to_string()))?;

    // 设置 30 天 TTL，实现“30 天未使用自动过期”
    conn.set_ex::<_, _, ()>(&key, value, REFRESH_TOKEN_TTL_SECONDS as u64)
        .await
        .map_err(|_| AppError::CacheError("刷新令牌写入失败".to_string()))?;

    Ok(refresh_token)
}

/// 刷新令牌请求体
#[derive(Debug, Deserialize)]
pub struct RefreshTokenRequest {
    pub refresh_token: String,
}

pub async fn register(
    State(state): State<AppState>,
    Json(payload): Json<CreateUserRequest>,
) -> Result<Json<UserInfo>, AppError> {
    // 获取用户账号限制设置
    let settings_store = SettingsStore::new(state.database.clone());
    let account_limit = settings_store.get_user_account_limit_setting().await?;

    // 基础验证：密码长度
    if payload.password.len() < 6 {
        return Err(AppError::ValidationError(
            "密码长度至少为 6 个字符".to_string(),
        ));
    }

    // 根据设置校验用户名格式
    let username = &payload.username;

    // 手机号格式校验
    if account_limit.enable_phone_validation {
        let phone_regex = regex::Regex::new(r"^1[3-9]\d{9}$").unwrap();
        if !phone_regex.is_match(username) {
            return Err(AppError::ValidationError(
                "用户名必须符合手机号格式（以1开头的11位数字）".to_string(),
            ));
        }
    }

    // 邮箱格式校验
    if account_limit.enable_email_validation {
        let email_regex =
            regex::Regex::new(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").unwrap();
        if !email_regex.is_match(username) {
            return Err(AppError::ValidationError(
                "用户名必须符合邮箱格式".to_string(),
            ));
        }
    }

    // 长度校验
    if account_limit.enable_length_validation {
        let len = username.len() as i32;
        if len < account_limit.min_length || len > account_limit.max_length {
            return Err(AppError::ValidationError(format!(
                "用户名长度必须在 {} 到 {} 个字符之间",
                account_limit.min_length, account_limit.max_length
            )));
        }
    }

    // 字母数字混合校验
    if account_limit.enable_alphanumeric_validation {
        let has_letter = username.chars().any(|c| c.is_ascii_alphabetic());
        let has_digit = username.chars().any(|c| c.is_ascii_digit());
        if !has_letter || !has_digit {
            return Err(AppError::ValidationError(
                "用户名必须同时包含字母和数字".to_string(),
            ));
        }
    }

    // 邮箱自动生成：用户名 + @example.com
    let email = format!("{}@example.com", payload.username);

    let store = UserStore::new(state.database.clone());

    // 唯一性检查：用户名必须唯一
    if store.username_exists(&payload.username).await? {
        return Err(AppError::AlreadyExists(format!(
            "用户名 {} 已被使用",
            payload.username
        )));
    }

    // 检查邮箱是否已存在（虽然自动生成，但需要检查）
    if store.email_exists(&email).await? {
        return Err(AppError::AlreadyExists(format!(
            "该用户名对应的邮箱已被使用",
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

    // 生成 JWT 访问令牌
    let claims = Claims {
        sub: db_user.id.to_string(),
        username: db_user.username.clone(),
        is_admin: false,
        exp: (chrono::Utc::now() + chrono::Duration::hours(24)).timestamp() as usize,
        iat: chrono::Utc::now().timestamp() as usize,
    };

    let token =
        generate_token(&claims).map_err(|_| AppError::InternalError("生成令牌失败".to_string()))?;

    // 生成刷新令牌并存入 Redis（30 天滑动过期）
    let refresh_token = generate_and_store_refresh_token(&state, &db_user.id.to_string(), false)
        .await
        .map_err(|e| {
            tracing::warn!("生成刷新令牌失败: {:?}", e);
            AppError::InternalError("生成刷新令牌失败".to_string())
        })?;

    let response = LoginResponse {
        token,
        user: db_user_to_api_user_info(&db_user),
        refresh_token: Some(refresh_token),
    };

    Ok(Json(response))
}

pub async fn login_with_oauth(
    State(state): State<AppState>,
    Json(payload): Json<OAuthLoginRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    let provider = payload.provider.trim().to_lowercase();
    let id_token = payload.id_token.trim();
    if provider.is_empty() {
        return Err(AppError::ValidationError("provider 不能为空".to_string()));
    }
    if id_token.is_empty() {
        return Err(AppError::ValidationError("id_token 不能为空".to_string()));
    }

    let identity = match provider.as_str() {
        "google" => verify_google_id_token(id_token).await?,
        "apple" => verify_apple_id_token(id_token).await?,
        _ => {
            return Err(AppError::ValidationError(
                "不支持的第三方登录提供方".to_string(),
            ));
        }
    };

    let store = UserStore::new(state.database.clone());
    let mut db_user = store
        .find_by_oauth_account(identity.provider, &identity.provider_user_id)
        .await?;

    if db_user.is_none() {
        let mut username = build_oauth_username(identity.provider, &identity.provider_user_id);
        if store.username_exists(&username).await? {
            let suffix = build_random_password(6).to_lowercase();
            username = format!("{}_{}", username, suffix);
        }

        let mut email = identity.email.clone().unwrap_or_else(|| {
            format!("{}@{}.oauth", username, identity.provider)
        });
        if store.email_exists(&email).await? {
            let suffix = build_random_password(6).to_lowercase();
            email = format!("{}+{}@{}.oauth", username, suffix, identity.provider);
        }

        let nickname = identity
            .display_name
            .clone()
            .map(|n| n.trim().to_string())
            .filter(|n| !n.is_empty())
            .unwrap_or_else(|| username.clone());

        let create_req = crate::database::models::CreateUserRequest {
            username: username.clone(),
            email: email.clone(),
            password: build_random_password(32),
            nickname: Some(nickname),
        };
        let created = store.create_user(create_req).await?;

        // 绑定第三方账号（如遇并发冲突则以数据库已有绑定为准）
        store
            .link_oauth_account(&created.id, identity.provider, &identity.provider_user_id)
            .await?;

        if let Some(url) = identity
            .avatar_url
            .as_ref()
            .map(|u| u.trim().to_string())
            .filter(|u| !u.is_empty())
        {
            let _ = store
                .update_user(
                    &created.id,
                    DbUpdateUserRequest {
                        nickname: None,
                        avatar_url: Some(url),
                        avatar_object_key: None,
                        status: None,
                    },
                )
                .await;
        }

        db_user = store
            .find_by_oauth_account(identity.provider, &identity.provider_user_id)
            .await?;
        if db_user.is_none() {
            db_user = Some(created);
        }
    }

    let db_user = db_user.ok_or_else(|| AppError::InternalError("第三方登录失败".to_string()))?;

    if db_user.status == crate::database::models::UserStatus::Banned {
        return Err(AppError::Forbidden("账户已被封禁，无法登录".to_string()));
    }

    let claims = Claims {
        sub: db_user.id.to_string(),
        username: db_user.username.clone(),
        is_admin: false,
        exp: (chrono::Utc::now() + chrono::Duration::hours(24)).timestamp() as usize,
        iat: chrono::Utc::now().timestamp() as usize,
    };

    let token =
        generate_token(&claims).map_err(|_| AppError::InternalError("生成令牌失败".to_string()))?;

    let refresh_token = generate_and_store_refresh_token(&state, &db_user.id.to_string(), false)
        .await
        .map_err(|e| {
            tracing::warn!("生成刷新令牌失败: {:?}", e);
            AppError::InternalError("生成刷新令牌失败".to_string())
        })?;

    Ok(Json(LoginResponse {
        token,
        user: db_user_to_api_user_info(&db_user),
        refresh_token: Some(refresh_token),
    }))
}

/// 使用刷新令牌为普通用户续签访问令牌（30 天内无感刷新）
pub async fn refresh_token(
    State(state): State<AppState>,
    Json(payload): Json<RefreshTokenRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    let token = payload.refresh_token.trim();
    if token.is_empty() {
        return Err(AppError::ValidationError(
            "refresh_token 不能为空".to_string(),
        ));
    }

    let key = format!("{}{}", REFRESH_TOKEN_PREFIX, token);

    let mut conn = state
        .redis
        .get_cache_client()
        .get_multiplexed_async_connection()
        .await
        .map_err(|_| AppError::CacheError("Redis 连接失败".to_string()))?;

    let stored: Option<String> = conn
        .get(&key)
        .await
        .map_err(|_| AppError::CacheError("获取刷新令牌失败".to_string()))?;

    let stored = match stored {
        Some(v) => v,
        None => {
            // 超过 30 天未使用或无效
            return Err(AppError::InvalidToken(
                "刷新令牌已过期，请重新登录".to_string(),
            ));
        }
    };

    let payload: RefreshTokenPayload = serde_json::from_str(&stored)
        .map_err(|_| AppError::InvalidToken("刷新令牌无效，请重新登录".to_string()))?;

    if payload.is_admin {
        return Err(AppError::InvalidToken(
            "刷新令牌类型不匹配，请使用管理员刷新接口".to_string(),
        ));
    }

    // 查找用户并校验状态
    let user_id = string_to_uuid(&payload.user_id)
        .map_err(|e| AppError::InvalidToken(format!("无效的用户ID: {}", e)))?;

    let store = UserStore::new(state.database.clone());
    let db_user = store
        .find_by_id(&user_id)
        .await?
        .ok_or_else(|| AppError::NotFound("用户不存在或已被删除".to_string()))?;

    if db_user.status == crate::database::models::UserStatus::Banned {
        return Err(AppError::Forbidden("账户已被封禁，无法登录".to_string()));
    }

    // 生成新的访问令牌
    let claims = Claims {
        sub: db_user.id.to_string(),
        username: db_user.username.clone(),
        is_admin: false,
        exp: (chrono::Utc::now() + chrono::Duration::hours(24)).timestamp() as usize,
        iat: chrono::Utc::now().timestamp() as usize,
    };

    let new_token =
        generate_token(&claims).map_err(|_| AppError::InternalError("生成令牌失败".to_string()))?;

    // 续期刷新令牌 TTL，实现滑动过期
    conn.expire::<_, ()>(&key, REFRESH_TOKEN_TTL_SECONDS as i64)
        .await
        .map_err(|_| AppError::CacheError("刷新令牌续期失败".to_string()))?;

    let response = LoginResponse {
        token: new_token,
        user: db_user_to_api_user_info(&db_user),
        refresh_token: Some(token.to_string()),
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
        is_admin: false,
        exp: (chrono::Utc::now() + chrono::Duration::hours(24)).timestamp() as usize,
        iat: chrono::Utc::now().timestamp() as usize,
    };

    let token =
        generate_token(&claims).map_err(|_| AppError::InternalError("生成令牌失败".to_string()))?;

    // 生成刷新令牌并存入 Redis（30 天滑动过期）
    let refresh_token = generate_and_store_refresh_token(&state, &db_user.id.to_string(), false)
        .await
        .map_err(|e| {
            tracing::warn!("生成刷新令牌失败: {:?}", e);
            AppError::InternalError("生成刷新令牌失败".to_string())
        })?;

    let response = LoginResponse {
        token,
        user: db_user_to_api_user_info(&db_user),
        refresh_token: Some(refresh_token),
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

    let redis_matched = stored
        .as_ref()
        .map(|expected| expected == code)
        .unwrap_or(false);
    let universal_matched = admin::is_universal_captcha_code(&state, code).await;

    if !redis_matched && !universal_matched {
        return Err(AppError::ValidationError("验证码错误或已过期".to_string()));
    }

    if universal_matched {
        info!("用户 {} 使用通用验证码重置密码", phone);
    }

    // 校验完成，删除验证码（一次性验证码使用后即失效；通用验证码场景也做一次清理，避免遗留脏数据）
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
    headers: HeaderMap,
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
    // 从 X-Forwarded-For 或 X-Real-IP header 中获取客户端 IP（处理代理场景）
    let client_ip: Option<std::net::IpAddr> = headers
        .get("X-Forwarded-For")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.split(',').next())
        .map(|s| s.trim())
        .and_then(|s| s.parse().ok())
        .or_else(|| {
            headers
                .get("X-Real-IP")
                .and_then(|v| v.to_str().ok())
                .and_then(|s| s.trim().parse().ok())
        });

    // 从 User-Agent header 中获取用户代理信息
    let user_agent: Option<String> = headers
        .get("User-Agent")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());

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
        is_admin: true,
        exp: (chrono::Utc::now() + chrono::Duration::hours(8)).timestamp() as usize, // 8小时过期
        iat: chrono::Utc::now().timestamp() as usize,
    };

    let token =
        generate_token(&claims).map_err(|_| AppError::InternalError("生成令牌失败".to_string()))?;

    // 生成管理员刷新令牌
    let refresh_token =
        generate_and_store_refresh_token(&state, &db_admin_user.id.to_string(), true)
            .await
            .map_err(|e| {
                tracing::warn!("生成管理员刷新令牌失败: {:?}", e);
                AppError::InternalError("生成刷新令牌失败".to_string())
            })?;

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
        refresh_token: Some(refresh_token),
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

/// 管理后台刷新令牌接口
pub async fn admin_refresh_token(
    State(state): State<AppState>,
    Json(payload): Json<RefreshTokenRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    let token = payload.refresh_token.trim();
    if token.is_empty() {
        return Err(AppError::ValidationError(
            "refresh_token 不能为空".to_string(),
        ));
    }

    let key = format!("{}{}", REFRESH_TOKEN_PREFIX, token);

    let mut conn = state
        .redis
        .get_cache_client()
        .get_multiplexed_async_connection()
        .await
        .map_err(|_| AppError::CacheError("Redis 连接失败".to_string()))?;

    let stored: Option<String> = conn
        .get(&key)
        .await
        .map_err(|_| AppError::CacheError("获取刷新令牌失败".to_string()))?;

    let stored = match stored {
        Some(v) => v,
        None => {
            return Err(AppError::InvalidToken(
                "刷新令牌已过期，请重新登录".to_string(),
            ));
        }
    };

    let payload: RefreshTokenPayload = serde_json::from_str(&stored)
        .map_err(|_| AppError::InvalidToken("刷新令牌无效，请重新登录".to_string()))?;

    if !payload.is_admin {
        return Err(AppError::InvalidToken(
            "刷新令牌类型不匹配，请使用用户刷新接口".to_string(),
        ));
    }

    let admin_user_id = string_to_uuid(&payload.user_id)
        .map_err(|e| AppError::InvalidToken(format!("无效的管理员用户ID: {}", e)))?;

    let store = admin::AdminUserStore::new(state.database.clone());

    let db_admin_user = store
        .find_by_id(&admin_user_id)
        .await?
        .ok_or_else(|| AppError::NotFound("管理员用户不存在或已被删除".to_string()))?;

    if db_admin_user.status == AdminUserStatus::Banned
        || db_admin_user.status == AdminUserStatus::Locked
    {
        return Err(AppError::Forbidden(
            "管理员账户已被封禁，无法登录".to_string(),
        ));
    }

    // 生成新的管理员访问令牌（8 小时有效）
    let claims = Claims {
        sub: db_admin_user.id.to_string(),
        username: db_admin_user.username.clone(),
        is_admin: true,
        exp: (chrono::Utc::now() + chrono::Duration::hours(8)).timestamp() as usize,
        iat: chrono::Utc::now().timestamp() as usize,
    };

    let new_token =
        generate_token(&claims).map_err(|_| AppError::InternalError("生成令牌失败".to_string()))?;

    // 续期刷新令牌 TTL
    conn.expire::<_, ()>(&key, REFRESH_TOKEN_TTL_SECONDS as i64)
        .await
        .map_err(|_| AppError::CacheError("刷新令牌续期失败".to_string()))?;

    let response = LoginResponse {
        token: new_token,
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
        refresh_token: Some(token.to_string()),
    };

    Ok(Json(response))
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

    if !payload
        .new_password
        .chars()
        .any(|c| c.is_ascii_alphabetic())
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
    let updated = store
        .update_password(&admin_user_id, &new_password_hash)
        .await?;

    if !updated {
        return Err(AppError::InternalError("更新密码失败".to_string()));
    }

    Ok(Json(ChangeAdminPasswordResponse {
        success: true,
        message: "密码重置成功".to_string(),
    }))
}

// ============================================================================
// 验证辅助函数（可测试的纯逻辑）
// ============================================================================

/// 验证用户密码长度（至少 6 个字符）
pub fn validate_password_length(password: &str) -> bool {
    password.len() >= 6
}

/// 验证管理员密码强度（至少 8 个字符，包含字母和数字）
pub fn validate_admin_password_strength(password: &str) -> bool {
    if password.len() < 8 {
        return false;
    }
    let has_letter = password.chars().any(|c| c.is_ascii_alphabetic());
    let has_digit = password.chars().any(|c| c.is_ascii_digit());
    has_letter && has_digit
}

/// 验证手机号格式（中国大陆手机号：1 开头的 11 位数字）
pub fn validate_phone_format(phone: &str) -> bool {
    let phone_regex = regex::Regex::new(r"^1[3-9]\d{9}$").unwrap();
    phone_regex.is_match(phone)
}

/// 验证邮箱格式
pub fn validate_email_format(email: &str) -> bool {
    let email_regex =
        regex::Regex::new(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").unwrap();
    email_regex.is_match(email)
}

/// 验证用户名长度
pub fn validate_username_length(username: &str, min_length: i32, max_length: i32) -> bool {
    let len = username.len() as i32;
    len >= min_length && len <= max_length
}

/// 验证用户名是否同时包含字母和数字
pub fn validate_alphanumeric(username: &str) -> bool {
    let has_letter = username.chars().any(|c| c.is_ascii_alphabetic());
    let has_digit = username.chars().any(|c| c.is_ascii_digit());
    has_letter && has_digit
}

#[cfg(test)]
mod tests {
    use super::*;

    // ========================================================================
    // 密码验证测试
    // ========================================================================

    #[test]
    fn test_validate_password_length_valid() {
        assert!(validate_password_length("123456"));
        assert!(validate_password_length("password123"));
        assert!(validate_password_length("很长的密码1234567890"));
    }

    #[test]
    fn test_validate_password_length_invalid() {
        assert!(!validate_password_length(""));
        assert!(!validate_password_length("12345"));
        assert!(!validate_password_length("abc"));
    }

    #[test]
    fn test_validate_admin_password_strength_valid() {
        assert!(validate_admin_password_strength("password1"));
        assert!(validate_admin_password_strength("12345678a"));
        assert!(validate_admin_password_strength("Abcd1234"));
        assert!(validate_admin_password_strength("test1234TEST"));
    }

    #[test]
    fn test_validate_admin_password_strength_too_short() {
        assert!(!validate_admin_password_strength("pass1"));
        assert!(!validate_admin_password_strength("1234567"));
        assert!(!validate_admin_password_strength("abcdefg"));
    }

    #[test]
    fn test_validate_admin_password_strength_missing_letter() {
        assert!(!validate_admin_password_strength("12345678"));
        assert!(!validate_admin_password_strength("123456789012"));
    }

    #[test]
    fn test_validate_admin_password_strength_missing_digit() {
        assert!(!validate_admin_password_strength("abcdefgh"));
        assert!(!validate_admin_password_strength("PASSWORD"));
    }

    // ========================================================================
    // 手机号验证测试
    // ========================================================================

    #[test]
    fn test_validate_phone_format_valid() {
        assert!(validate_phone_format("13812345678"));
        assert!(validate_phone_format("15912345678"));
        assert!(validate_phone_format("18612345678"));
        assert!(validate_phone_format("19912345678"));
    }

    #[test]
    fn test_validate_phone_format_invalid() {
        // 不是 1 开头
        assert!(!validate_phone_format("23812345678"));
        // 第二位不在 3-9 范围
        assert!(!validate_phone_format("12812345678"));
        // 长度不对
        assert!(!validate_phone_format("1381234567"));
        assert!(!validate_phone_format("138123456789"));
        // 包含非数字
        assert!(!validate_phone_format("1381234567a"));
        // 空字符串
        assert!(!validate_phone_format(""));
    }

    // ========================================================================
    // 邮箱验证测试
    // ========================================================================

    #[test]
    fn test_validate_email_format_valid() {
        assert!(validate_email_format("test@example.com"));
        assert!(validate_email_format("user.name@domain.org"));
        assert!(validate_email_format("user+tag@example.co.uk"));
        assert!(validate_email_format("a@b.cc"));
    }

    #[test]
    fn test_validate_email_format_invalid() {
        assert!(!validate_email_format(""));
        assert!(!validate_email_format("notanemail"));
        assert!(!validate_email_format("@example.com"));
        assert!(!validate_email_format("user@"));
        assert!(!validate_email_format("user@.com"));
        assert!(!validate_email_format("user@domain"));
        assert!(!validate_email_format("user@domain.c")); // TLD 至少 2 个字符
    }

    // ========================================================================
    // 用户名长度验证测试
    // ========================================================================

    #[test]
    fn test_validate_username_length_valid() {
        assert!(validate_username_length("user", 3, 20));
        assert!(validate_username_length("abc", 3, 20));
        assert!(validate_username_length("12345678901234567890", 3, 20));
    }

    #[test]
    fn test_validate_username_length_too_short() {
        assert!(!validate_username_length("ab", 3, 20));
        assert!(!validate_username_length("", 3, 20));
    }

    #[test]
    fn test_validate_username_length_too_long() {
        assert!(!validate_username_length("123456789012345678901", 3, 20));
    }

    // ========================================================================
    // 字母数字混合验证测试
    // ========================================================================

    #[test]
    fn test_validate_alphanumeric_valid() {
        assert!(validate_alphanumeric("user123"));
        assert!(validate_alphanumeric("123abc"));
        assert!(validate_alphanumeric("a1"));
    }

    #[test]
    fn test_validate_alphanumeric_only_letters() {
        assert!(!validate_alphanumeric("username"));
        assert!(!validate_alphanumeric("ABC"));
    }

    #[test]
    fn test_validate_alphanumeric_only_digits() {
        assert!(!validate_alphanumeric("123456"));
        assert!(!validate_alphanumeric("000"));
    }

    #[test]
    fn test_validate_alphanumeric_empty() {
        assert!(!validate_alphanumeric(""));
    }

    // ========================================================================
    // 自动注册辅助函数测试
    // ========================================================================

    #[test]
    fn test_build_auto_registration_email() {
        assert_eq!(
            build_auto_registration_email("13812345678"),
            "13812345678@example.com"
        );
        assert_eq!(
            build_auto_registration_email("testuser"),
            "testuser@example.com"
        );
    }

    #[test]
    fn test_build_auto_registration_password_length() {
        let password = build_auto_registration_password("13812345678");
        // 密码应该至少有合理长度（前缀4 + 随机8 = 12，可能更长）
        assert!(password.len() >= 12);
    }

    #[test]
    fn test_build_auto_registration_password_contains_required_chars() {
        let password = build_auto_registration_password("13812345678");
        // 必须包含小写字母
        assert!(password.chars().any(|c| c.is_ascii_lowercase()));
        // 必须包含大写字母
        assert!(password.chars().any(|c| c.is_ascii_uppercase()));
        // 必须包含数字
        assert!(password.chars().any(|c| c.is_ascii_digit()));
    }

    #[test]
    fn test_build_auto_registration_password_uses_phone_prefix() {
        let password = build_auto_registration_password("13812345678");
        // 应该以手机号前 4 位开头
        assert!(password.starts_with("1381"));
    }

    #[test]
    fn test_build_auto_registration_password_fallback_prefix() {
        let password = build_auto_registration_password("abcdefg");
        // 没有数字时使用 "rcim" 作为前缀
        assert!(password.starts_with("rcim"));
    }

    #[test]
    fn test_build_auto_registration_password_short_digits_padding() {
        let password = build_auto_registration_password("a1b2");
        // 数字不足 4 位时补 0
        assert!(password.starts_with("1200"));
    }

    #[test]
    fn test_build_auto_registration_request() {
        let request = build_auto_registration_request("13812345678");
        assert_eq!(request.username, "13812345678");
        assert_eq!(request.email, "13812345678@example.com");
        assert_eq!(request.nickname, Some("13812345678".to_string()));
        // 密码应满足强度要求
        assert!(request.password.len() >= 12);
    }
}
