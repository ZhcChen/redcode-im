use crate::models::Claims;
use axum::{
    extract::Request,
    http::{header, StatusCode},
    middleware::Next,
    response::Response,
};
use bcrypt::{hash, verify, DEFAULT_COST};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use std::env;

const MIN_PASSWORD_HASH_COST: u32 = 4;
const MAX_PASSWORD_HASH_COST: u32 = 14;

// JWT 密钥，在生产环境中应该从环境变量获取
fn get_jwt_secret() -> String {
    env::var("JWT_SECRET").unwrap_or_else(|_| "your-secret-key".to_string())
}

pub fn password_hash_cost() -> u32 {
    let primary = env::var("BCRYPT_COST").ok();
    let alias = env::var("PASSWORD_HASH_COST").ok();
    parse_password_hash_cost(primary.as_deref().or(alias.as_deref()))
}

fn parse_password_hash_cost(raw: Option<&str>) -> u32 {
    raw.and_then(|value| value.trim().parse::<u32>().ok())
        .filter(|cost| (MIN_PASSWORD_HASH_COST..=MAX_PASSWORD_HASH_COST).contains(cost))
        .unwrap_or(DEFAULT_COST)
}

// 密码哈希
pub fn hash_password(password: &str) -> Result<String, bcrypt::BcryptError> {
    hash(password, password_hash_cost())
}

// 验证密码
pub fn verify_password(password: &str, hash: &str) -> Result<bool, bcrypt::BcryptError> {
    verify(password, hash)
}

// 生成 JWT Token（直接使用 Claims）
pub fn generate_token(claims: &Claims) -> Result<String, jsonwebtoken::errors::Error> {
    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(get_jwt_secret().as_ref()),
    )
}

// 验证 JWT Token
pub fn verify_token(token: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
    decode::<Claims>(
        token,
        &DecodingKey::from_secret(get_jwt_secret().as_ref()),
        &Validation::default(),
    )
    .map(|data| data.claims)
}

// 认证中间件
pub async fn auth_middleware(mut request: Request, next: Next) -> Result<Response, StatusCode> {
    let auth_header = request
        .headers()
        .get(header::AUTHORIZATION)
        .and_then(|header| header.to_str().ok());

    if let Some(auth_header) = auth_header {
        if let Some(token) = auth_header.strip_prefix("Bearer ") {
            match verify_token(token) {
                Ok(claims) => {
                    // 将用户信息添加到请求扩展中
                    request.extensions_mut().insert(claims);
                    return Ok(next.run(request).await);
                }
                Err(_) => return Err(StatusCode::UNAUTHORIZED),
            }
        }
    }

    Err(StatusCode::UNAUTHORIZED)
}

/// 管理后台路由鉴权中间件（要求 is_admin=true）
pub async fn admin_only_middleware(request: Request, next: Next) -> Result<Response, StatusCode> {
    let is_admin = request
        .extensions()
        .get::<Claims>()
        .map(|claims| claims.is_admin)
        .unwrap_or(false);

    if !is_admin {
        return Err(StatusCode::FORBIDDEN);
    }

    Ok(next.run(request).await)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_password_hash_cost_uses_default_for_missing_or_invalid_values() {
        assert_eq!(parse_password_hash_cost(None), DEFAULT_COST);
        assert_eq!(parse_password_hash_cost(Some("")), DEFAULT_COST);
        assert_eq!(parse_password_hash_cost(Some("abc")), DEFAULT_COST);
        assert_eq!(parse_password_hash_cost(Some("3")), DEFAULT_COST);
        assert_eq!(parse_password_hash_cost(Some("15")), DEFAULT_COST);
    }

    #[test]
    fn parse_password_hash_cost_accepts_safe_range() {
        assert_eq!(parse_password_hash_cost(Some("4")), 4);
        assert_eq!(parse_password_hash_cost(Some("8")), 8);
        assert_eq!(parse_password_hash_cost(Some("14")), 14);
    }
}
