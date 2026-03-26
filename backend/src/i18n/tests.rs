use axum::{body::Body, response::IntoResponse};
use http_body_util::BodyExt;
use serde_json::Value;
use std::collections::BTreeMap;

use crate::error::AppError;
use crate::i18n::{
    catalog::Catalog,
    locale::{negotiate_locale, DEFAULT_LOCALE},
    localizer::Localizer,
};

#[test]
fn i18n_accept_language_exact_match() {
    let locale = negotiate_locale(Some("en-US,en;q=0.9"));
    assert_eq!(locale, "en-US");
}

#[test]
fn i18n_accept_language_family_fallback() {
    let locale = negotiate_locale(Some("en-GB,en;q=0.8"));
    assert_eq!(locale, "en-US");
}

#[test]
fn i18n_accept_language_default_to_zh_cn() {
    let locale = negotiate_locale(Some("fr-FR,fr;q=0.9"));
    assert_eq!(locale, DEFAULT_LOCALE);
}

#[test]
fn i18n_accept_language_ignores_q_zero_candidate() {
    let locale = negotiate_locale(Some("en-US;q=0"));
    assert_eq!(locale, DEFAULT_LOCALE);
}

#[test]
fn i18n_accept_language_ignores_invalid_q_value() {
    let locale = negotiate_locale(Some("en-US;q=abc"));
    assert_eq!(locale, DEFAULT_LOCALE);
}

#[test]
fn i18n_missing_key_fallback_to_message_key() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let message = localizer.localize("en-US", "common.missing_key_for_test", None);
    assert_eq!(message, "common.missing_key_for_test");
}

#[test]
fn i18n_english_message_localization() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let message = localizer.localize_by_header(Some("en-US"), "auth.token_expired", None);
    assert_eq!(message, "Token expired. Please sign in again.");
}

#[test]
fn i18n_auth_catalog_is_loaded_for_english_locale() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let message = localizer.localize("en-US", "auth.refresh_token_required", None);
    assert_eq!(message, "Refresh token is required.");
}

#[test]
fn i18n_auth_catalog_interpolates_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([
        ("min".to_string(), "3".to_string()),
        ("max".to_string(), "20".to_string()),
    ]);
    let message = localizer.localize("zh-CN", "auth.username_length_invalid", Some(&params));
    assert_eq!(message, "用户名长度必须在 3 到 20 个字符之间");
}

#[test]
fn i18n_auth_catalog_loads_new_auth_keys() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    assert_eq!(
        localizer.localize("zh-CN", "auth.username_already_exists", None),
        "用户名已被使用"
    );
    assert_eq!(
        localizer.localize("en-US", "auth.admin_password_update_failed", None),
        "Failed to update admin password. Please try again later."
    );
}

#[test]
fn i18n_friend_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    assert_eq!(
        localizer.localize("zh-CN", "friend.cannot_add_self", None),
        "不能添加自己为好友"
    );
    assert_eq!(
        localizer.localize("en-US", "friend.cannot_add_self", None),
        "You cannot add yourself as a friend."
    );
}

#[test]
fn i18n_friend_catalog_interpolates_direction_and_status_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let direction_params = BTreeMap::from([("direction".to_string(), "sideways".to_string())]);
    assert_eq!(
        localizer.localize("en-US", "friend.direction_invalid", Some(&direction_params),),
        "Unsupported direction parameter: sideways."
    );

    let status_params = BTreeMap::from([("status".to_string(), "paused".to_string())]);
    assert_eq!(
        localizer.localize("zh-CN", "friend.status_invalid", Some(&status_params)),
        "不支持的 status 参数：paused"
    );
}

#[test]
fn i18n_user_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    assert_eq!(
        localizer.localize("zh-CN", "user.current_user_not_found", None),
        "当前用户不存在"
    );
    assert_eq!(
        localizer.localize("en-US", "user.current_user_not_found", None),
        "Current user was not found."
    );
}

#[test]
fn i18n_user_catalog_interpolates_avatar_size_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([
        ("expected_size".to_string(), "1024".to_string()),
        ("actual_size".to_string(), "2048".to_string()),
    ]);
    assert_eq!(
        localizer.localize("zh-CN", "user.avatar_size_mismatch", Some(&params)),
        "头像大小校验失败：期望 1024 字节，实际 2048 字节"
    );
    assert_eq!(
        localizer.localize("en-US", "user.avatar_size_mismatch", Some(&params)),
        "Avatar size mismatch: expected 1024 bytes, got 2048 bytes."
    );
}

#[tokio::test]
async fn i18n_error_response_contains_expected_protocol_values() {
    let response = AppError::TokenExpired.into_response();
    let body = read_body_json(response.into_body()).await;

    assert_eq!(body["code"], 40003);
    assert_eq!(body["message_key"], "auth.token_expired");
    assert_eq!(body["message"], "令牌已过期，请重新登录");
    assert_eq!(body["message_params"], Value::Null);
    assert_eq!(body["details"], Value::Null);
}

#[tokio::test]
async fn i18n_error_response_keeps_custom_payload_message() {
    let response = AppError::Unauthorized("自定义错误文案".to_string()).into_response();
    let body = read_body_json(response.into_body()).await;
    assert_eq!(body["message_key"], "auth.unauthorized");
    assert_eq!(body["message"], "自定义错误文案");
    assert_eq!(body["details"], "自定义错误文案");
}

#[tokio::test]
async fn i18n_error_response_uses_fallback_locale_message_for_empty_payload() {
    let response = AppError::Unauthorized(String::new()).into_response();
    let body = read_body_json(response.into_body()).await;
    assert_eq!(body["message_key"], "auth.unauthorized");
    assert_eq!(body["message"], "未授权，请先登录");
    assert_eq!(body["details"], Value::Null);
}

#[tokio::test]
async fn i18n_error_response_suppresses_details_for_database_error() {
    let response =
        AppError::DatabaseError(sqlx::Error::Protocol("db err".to_string())).into_response();
    let body = read_body_json(response.into_body()).await;
    assert_eq!(body["message_key"], "common.database_error");
    assert_eq!(body["message"], "数据库错误");
    assert_eq!(body["details"], Value::Null);
}

#[tokio::test]
async fn i18n_error_response_suppresses_details_for_internal_error() {
    let response = AppError::InternalError("sensitive stack".to_string()).into_response();
    let body = read_body_json(response.into_body()).await;
    assert_eq!(body["message_key"], "common.internal_error");
    assert_eq!(body["message"], "服务器内部错误");
    assert_eq!(body["details"], Value::Null);
}

#[tokio::test]
async fn i18n_error_response_suppresses_sensitive_payload_for_service_unavailable() {
    let response = AppError::ServiceUnavailable("upstream raw body".to_string()).into_response();
    let body = read_body_json(response.into_body()).await;
    assert_eq!(body["message_key"], "common.service_unavailable");
    assert_eq!(body["message"], "服务不可用");
    assert_eq!(body["details"], Value::Null);
}

#[tokio::test]
async fn i18n_error_response_rate_limit_keys_are_merged() {
    let too_many = read_body_json(AppError::TooManyRequests.into_response().into_body()).await;
    let rate_limit = read_body_json(
        AppError::RateLimitExceeded(String::new())
            .into_response()
            .into_body(),
    )
    .await;
    assert_eq!(too_many["message_key"], "common.too_many_requests");
    assert_eq!(rate_limit["message_key"], "common.too_many_requests");
}

#[tokio::test]
async fn i18n_error_response_friend_request_not_found_uses_params_and_localized_message() {
    let params = BTreeMap::from([(
        "request_id".to_string(),
        "550e8400-e29b-41d4-a716-446655440000".to_string(),
    )]);
    let response = AppError::NotFound(String::new())
        .with_message_key_and_params("friend.request_not_found", Some(params.clone()))
        .into_response();
    let body = read_body_json(response.into_body()).await;

    assert_eq!(body["code"], 40401);
    assert_eq!(body["message_key"], "friend.request_not_found");
    assert_eq!(
        body["message"],
        "好友请求 550e8400-e29b-41d4-a716-446655440000 不存在"
    );
    assert_eq!(body["message_params"]["request_id"], params["request_id"]);
    assert_eq!(body["details"], Value::Null);
}

async fn read_body_json(body: Body) -> Value {
    let bytes = body
        .collect()
        .await
        .expect("collect response body")
        .to_bytes();
    serde_json::from_slice(&bytes).expect("parse json body")
}
