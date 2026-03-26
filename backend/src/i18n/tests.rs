use axum::{body::Body, response::IntoResponse};
use http_body_util::BodyExt;
use serde_json::Value;

use crate::error::AppError;
use crate::i18n::{
    catalog::Catalog,
    locale::{DEFAULT_LOCALE, negotiate_locale},
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
    let response = AppError::DatabaseError(sqlx::Error::Protocol("db err".to_string())).into_response();
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
    let rate_limit =
        read_body_json(AppError::RateLimitExceeded(String::new()).into_response().into_body())
            .await;
    assert_eq!(too_many["message_key"], "common.too_many_requests");
    assert_eq!(rate_limit["message_key"], "common.too_many_requests");
}

async fn read_body_json(body: Body) -> Value {
    let bytes = body
        .collect()
        .await
        .expect("collect response body")
        .to_bytes();
    serde_json::from_slice(&bytes).expect("parse json body")
}
