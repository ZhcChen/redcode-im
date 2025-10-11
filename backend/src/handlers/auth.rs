use axum::{
    extract::Request,
    http::StatusCode,
    response::Json,
};
use crate::models::{CreateUserRequest, LoginRequest, LoginResponse, UserInfo};
use crate::auth::{hash_password, verify_password, generate_token};
use crate::storage::USER_STORAGE;
use tracing::info;

pub async fn register(
    Json(payload): Json<CreateUserRequest>,
) -> Result<Json<UserInfo>, (StatusCode, String)> {
    // 基础验证
    if payload.username.len() < 3 {
        return Err((StatusCode::BAD_REQUEST, "Username must be at least 3 characters".to_string()));
    }

    if payload.password.len() < 6 {
        return Err((StatusCode::BAD_REQUEST, "Password must be at least 6 characters".to_string()));
    }

    if !payload.email.contains('@') {
        return Err((StatusCode::BAD_REQUEST, "Invalid email format".to_string()));
    }

    // 哈希密码
    let password_hash = match hash_password(&payload.password) {
        Ok(hash) => hash,
        Err(e) => {
            tracing::error!("Failed to hash password: {}", e);
            return Err((StatusCode::INTERNAL_SERVER_ERROR, "Failed to process password".to_string()));
        }
    };

    // 创建用户
    let user = match USER_STORAGE.create_user(payload, password_hash).await {
        Ok(user) => {
            info!("User registered successfully: {}", user.username);
            user
        }
        Err(e) => {
            return Err((StatusCode::CONFLICT, e));
        }
    };

    Ok(Json(UserInfo::from(user)))
}

pub async fn login(
    Json(payload): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, (StatusCode, String)> {
    // 查找用户
    let user = match USER_STORAGE.find_by_username(&payload.username).await {
        Some(user) => user,
        None => return Err((StatusCode::UNAUTHORIZED, "Invalid username or password".to_string())),
    };

    // 验证密码
    match verify_password(&payload.password, &user.password_hash) {
        Ok(true) => {
            info!("User logged in successfully: {}", user.username);
        }
        Ok(false) | Err(_) => {
            return Err((StatusCode::UNAUTHORIZED, "Invalid username or password".to_string()));
        }
    }

    // 生成 JWT token
    let token = match generate_token(&user) {
        Ok(token) => token,
        Err(e) => {
            tracing::error!("Failed to generate token: {}", e);
            return Err((StatusCode::INTERNAL_SERVER_ERROR, "Failed to generate token".to_string()));
        }
    };

    let response = LoginResponse {
        token,
        user: UserInfo::from(user),
    };

    Ok(Json(response))
}

pub async fn get_current_user(
    request: Request,
) -> Result<Json<UserInfo>, StatusCode> {
    let user = crate::auth::get_current_user(&request)
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // 在实际应用中需要从数据库获取完整用户信息
    Ok(Json(UserInfo {
        id: user.sub.clone(),
        username: user.username.clone(),
        email: "".to_string(),
        nickname: None,
        avatar_url: None,
        status: crate::models::UserStatus::Active,
    }))
}