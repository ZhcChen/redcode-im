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
fn i18n_missing_key_fallback_to_message_key() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let message = localizer.localize("en-US", "common.missing_key_for_test", None);
    assert_eq!(message, "common.missing_key_for_test");
}

#[tokio::test]
async fn i18n_error_response_contains_protocol_fields() {
    let response = AppError::TokenExpired.into_response();
    let body = read_body_json(response.into_body()).await;

    assert!(body.get("code").is_some(), "missing code");
    assert!(body.get("message_key").is_some(), "missing message_key");
    assert!(body.get("message").is_some(), "missing message");
    assert!(
        body.get("message_params").is_some(),
        "missing message_params"
    );
    assert!(body.get("details").is_some(), "missing details");
}

#[tokio::test]
async fn i18n_error_response_keeps_custom_payload_message() {
    let response = AppError::Unauthorized("自定义错误文案".to_string()).into_response();
    let body = read_body_json(response.into_body()).await;
    assert_eq!(body["message"], "自定义错误文案");
}

#[tokio::test]
async fn i18n_error_response_uses_fallback_locale_message_for_empty_payload() {
    let response = AppError::Unauthorized(String::new()).into_response();
    let body = read_body_json(response.into_body()).await;
    assert_eq!(body["message_key"], "auth.unauthorized");
    assert_eq!(body["message"], "未授权，请先登录");
}

async fn read_body_json(body: Body) -> Value {
    let bytes = body
        .collect()
        .await
        .expect("collect response body")
        .to_bytes();
    serde_json::from_slice(&bytes).expect("parse json body")
}
