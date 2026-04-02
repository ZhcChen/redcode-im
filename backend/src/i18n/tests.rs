use axum::{body::Body, response::IntoResponse};
use http_body_util::BodyExt;
use serde_json::Value;
use std::collections::BTreeMap;

use crate::error::AppError;
use crate::handlers::message::message_cache_error;
use crate::i18n::{
    catalog::Catalog,
    locale::{negotiate_locale, normalize_locale_tag, DEFAULT_LOCALE},
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
fn i18n_normalize_locale_tag_canonicalizes_supported_variants() {
    assert_eq!(normalize_locale_tag(Some("en")), "en-US");
    assert_eq!(normalize_locale_tag(Some("en_GB")), "en-US");
    assert_eq!(normalize_locale_tag(Some("zh")), "zh-CN");
    assert_eq!(normalize_locale_tag(Some("fr-FR")), DEFAULT_LOCALE);
    assert_eq!(normalize_locale_tag(None), DEFAULT_LOCALE);
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

#[test]
fn i18n_user_catalog_loads_avatar_tail_keys() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    let content_type_params =
        BTreeMap::from([("content_type".to_string(), "application/pdf".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "user.avatar_content_type_unsupported",
            Some(&content_type_params),
        ),
        "不支持的文件类型：application/pdf"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "user.avatar_content_type_unsupported",
            Some(&content_type_params),
        ),
        "Unsupported avatar content type: application/pdf."
    );

    let size_params = BTreeMap::from([("max_mb".to_string(), "10".to_string())]);
    assert_eq!(
        localizer.localize("zh-CN", "user.avatar_size_exceeded", Some(&size_params)),
        "文件大小超出限制，最大允许10MB"
    );
    assert_eq!(
        localizer.localize("en-US", "user.avatar_size_exceeded", Some(&size_params)),
        "Avatar file size exceeds the limit. Maximum allowed is 10 MB."
    );

    assert_eq!(
        localizer.localize("zh-CN", "user.avatar_not_set", None),
        "尚未设置头像"
    );
    assert_eq!(
        localizer.localize("en-US", "user.target_avatar_not_set", None),
        "This user has not set an avatar yet."
    );
}

#[test]
fn i18n_settings_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "settings.privacy_policy_content_required", None),
        "隐私协议内容不能为空"
    );
    assert_eq!(
        localizer.localize("en-US", "settings.user_agreement_content_required", None),
        "User agreement content cannot be empty."
    );
    assert_eq!(
        localizer.localize("zh-CN", "settings.account_validation_rule_required", None),
        "至少需要启用一种校验规则"
    );
    assert_eq!(
        localizer.localize("en-US", "settings.account_min_length_gt_max_length", None),
        "Minimum account length cannot be greater than maximum length."
    );
    assert_eq!(
        localizer.localize("zh-CN", "settings.privacy_policy_fallback_title", None),
        "隐私协议"
    );
    assert_eq!(
        localizer.localize("en-US", "settings.user_agreement_fallback_title", None),
        "User Agreement"
    );
    assert_eq!(
        localizer.localize("zh-CN", "settings.privacy_policy_fallback_content", None),
        "<p>隐私协议内容尚未配置。</p>"
    );
    assert_eq!(
        localizer.localize("en-US", "settings.user_agreement_fallback_content", None),
        "<p>User agreement content has not been configured yet.</p>"
    );
}

#[test]
fn i18n_settings_catalog_interpolates_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    let app_name_params = BTreeMap::from([("max_length".to_string(), "50".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "settings.app_name_too_long",
            Some(&app_name_params)
        ),
        "应用名称不能超过50个字符"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "settings.app_name_too_long",
            Some(&app_name_params)
        ),
        "App name cannot exceed 50 characters."
    );

    let length_params = BTreeMap::from([
        ("min_allowed".to_string(), "3".to_string()),
        ("max_allowed".to_string(), "50".to_string()),
    ]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "settings.account_length_range_invalid",
            Some(&length_params),
        ),
        "长度限制范围必须在 3-50 之间"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "settings.account_length_range_invalid",
            Some(&length_params),
        ),
        "Account length must be between 3 and 50 characters."
    );
}

#[test]
fn i18n_message_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    assert_eq!(
        localizer.localize("zh-CN", "message.search_query_required", None),
        "搜索内容不能为空"
    );
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "message.default_storage_provider_invalid_config",
            None
        ),
        "默认存储提供商配置无效，请联系管理员"
    );
    assert_eq!(
        localizer.localize("en-US", "message.search_query_required", None),
        "Search query cannot be empty."
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "message.default_storage_provider_invalid_config",
            None
        ),
        "Default storage provider configuration is invalid. Please contact an administrator."
    );

    assert_eq!(
        localizer.localize("zh-CN", "message.content_required", None),
        "消息内容不能为空"
    );
    assert_eq!(
        localizer.localize("en-US", "message.content_required", None),
        "Message content cannot be empty."
    );

    assert_eq!(
        localizer.localize("zh-CN", "message.send_rate_limit_cache_failed", None),
        "消息发送限流暂时不可用，请稍后重试"
    );
    assert_eq!(
        localizer.localize("en-US", "message.send_rate_limit_cache_failed", None),
        "Message send rate limiting is temporarily unavailable. Please try again later."
    );
}

#[test]
fn i18n_message_catalog_interpolates_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([
        ("message_type".to_string(), "unknown".to_string()),
        ("max".to_string(), "200".to_string()),
    ]);

    assert_eq!(
        localizer.localize(
            "zh-CN",
            "message.search_message_type_invalid",
            Some(&params)
        ),
        "无效的消息类型：unknown"
    );
    assert_eq!(
        localizer.localize("en-US", "message.search_query_too_long", Some(&params)),
        "Search query is too long. Maximum allowed is 200 characters."
    );

    let provider_params = BTreeMap::from([("provider_type".to_string(), "minio".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "message.default_storage_provider_unsupported",
            Some(&provider_params)
        ),
        "不支持的默认存储提供商类型：minio"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "message.default_storage_provider_unsupported",
            Some(&provider_params)
        ),
        "Unsupported default storage provider type: minio."
    );
}

#[test]
fn i18n_admin_storage_bucket_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "admin.storage_test_bucket_name_required", None),
        "bucket 名称不能为空"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.storage_test_bucket_name_required", None),
        "Bucket name is required."
    );
}

#[test]
fn i18n_admin_storage_bucket_catalog_interpolates_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let count_params = BTreeMap::from([("count".to_string(), "2".to_string())]);
    let bucket_params = BTreeMap::from([("bucket_name".to_string(), "demo-bucket".to_string())]);
    let reason_params = BTreeMap::from([("reason".to_string(), "boom".to_string())]);

    assert_eq!(
        localizer.localize(
            "zh-CN",
            "admin.storage_test_list_buckets_success",
            Some(&count_params)
        ),
        "成功获取 2 个 bucket"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.storage_test_create_bucket_success",
            Some(&bucket_params)
        ),
        "Bucket created successfully: demo-bucket"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.storage_test_list_buckets_failed",
            Some(&reason_params)
        ),
        "Failed to list buckets: boom"
    );
}

#[test]
fn i18n_admin_storage_test_catalog_interpolates_reason_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let reason_params = BTreeMap::from([("reason".to_string(), "boom".to_string())]);
    let provider_params = BTreeMap::from([("provider_type".to_string(), "aliyun_oss".to_string())]);

    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.storage_test_upload_decode_failed",
            Some(&reason_params)
        ),
        "Failed to decode file content: boom"
    );
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "admin.storage_test_upload_signature_failed",
            Some(&reason_params)
        ),
        "生成直传签名失败: boom"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.storage_test_multipart_initiate_failed",
            Some(&reason_params)
        ),
        "Failed to initialize multipart upload: boom"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.storage_test_download_url_failed",
            Some(&reason_params)
        ),
        "Failed to generate download URL: boom"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.storage_test_cors_get_failed",
            Some(&reason_params)
        ),
        "Failed to fetch CORS rules: boom"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.storage_test_cors_set_failed",
            Some(&reason_params)
        ),
        "Failed to update CORS rules: boom"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.storage_test_delete_failed",
            Some(&reason_params)
        ),
        "Delete failed: boom"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.storage_test_exists_failed",
            Some(&reason_params)
        ),
        "Failed to check file existence: boom"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.storage_provider_type_unsupported",
            Some(&provider_params)
        ),
        "Unsupported storage provider type: aliyun_oss."
    );
}

#[test]
fn i18n_admin_storage_test_catalog_loads_reuse_keys() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "admin.storage_test_upload_signature_reused", None),
        "复用已上传的测试文件，未生成新的直传签名"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.storage_test_multipart_reused", None),
        "An existing uploaded object was reused. No re-upload is required."
    );
}

#[test]
fn i18n_message_catalog_loads_task_4c_error_keys_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "message.list_cursor_conflict", None),
        "before_id 和 since_id 不能同时传入"
    );
    assert_eq!(
        localizer.localize("en-US", "message.list_cursor_conflict", None),
        "before_id and since_id cannot be provided together."
    );

    assert_eq!(
        localizer.localize("zh-CN", "message.delete_message_reload_failed", None),
        "删除消息后重新加载失败，请稍后重试"
    );
    assert_eq!(
        localizer.localize("en-US", "message.delete_message_reload_failed", None),
        "Failed to reload the message after deletion. Please try again later."
    );
    assert_eq!(
        localizer.localize("zh-CN", "message.reaction_message_deleted", None),
        "消息已删除，无法操作反应"
    );
    assert_eq!(
        localizer.localize("en-US", "message.reaction_message_deleted", None),
        "Message has been deleted and reactions are no longer available."
    );
}

#[test]
fn i18n_admin_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    assert_eq!(
        localizer.localize("zh-CN", "admin.ipinfo_token_name_required", None),
        "Token名称不能为空"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.ipinfo_token_name_required", None),
        "Token name is required."
    );
    assert_eq!(
        localizer.localize("zh-CN", "admin.ipinfo_token_not_found", None),
        "Token不存在"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.ipinfo_token_not_found", None),
        "Token was not found."
    );
    assert_eq!(
        localizer.localize("zh-CN", "admin.geolocation_ip_invalid", None),
        "IP地址格式无效"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.geolocation_ip_required", None),
        "IP address is required."
    );
    assert_eq!(
        localizer.localize("en-US", "admin.ip_geolocation_description", None),
        "Controls whether user IP geolocation resolution is enabled for admin analytics."
    );
    assert_eq!(
        localizer.localize("zh-CN", "admin.admin_user_status_invalid", None),
        "无效的状态参数"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.admin_user_required_fields_missing", None),
        "Username, email, and password are required."
    );
    assert_eq!(
        localizer.localize("en-US", "admin.admin_user_status_update_success", None),
        "Admin user status updated successfully."
    );
    assert_eq!(
        localizer.localize("en-US", "admin.insecure_bootstrap_disabled", None),
        "This endpoint is only for initialization/debugging and is disabled by default. Set ALLOW_INSECURE_ADMIN_BOOTSTRAP=true to enable it."
    );
    assert_eq!(
        localizer.localize("zh-CN", "admin.default_admin_already_exists", None),
        "管理员用户已存在，无需重复创建"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.user_id_invalid", None),
        "User ID is invalid."
    );
    assert_eq!(
        localizer.localize("zh-CN", "admin.user_not_found", None),
        "用户不存在"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.user_username_too_short", None),
        "Username must be at least 3 characters long."
    );
    assert_eq!(
        localizer.localize("zh-CN", "admin.user_status_invalid", None),
        "无效的用户状态"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.user_delete_success", None),
        "User deleted successfully."
    );
    assert_eq!(
        localizer.localize("en-US", "admin.role_name_required", None),
        "Role name is required."
    );
    assert_eq!(
        localizer.localize("zh-CN", "admin.file_batch_delete_ids_required", None),
        "请提供要删除的文件ID列表"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.storage_test_upload_content_required", None),
        "Please provide file content or choose a file to upload."
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.storage_test_download_url_success_cached",
            None
        ),
        "Download URL generated successfully (cached)."
    );
    assert_eq!(
        localizer.localize("en-US", "admin.storage_test_delete_success", None),
        "File deleted successfully."
    );
    assert_eq!(
        localizer.localize("en-US", "admin.storage_test_exists_false", None),
        "File does not exist."
    );

    assert_eq!(
        localizer.localize("zh-CN", "admin.log_cleanup_retention_days_invalid", None),
        "保留天数必须大于 0"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.log_cleanup_retention_days_invalid", None),
        "Retention days must be greater than 0."
    );
    let invalid_uuid_params = BTreeMap::from([("value".to_string(), "not-a-uuid".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "admin.push_log_query_uuid_invalid",
            Some(&invalid_uuid_params)
        ),
        "无效的 UUID: not-a-uuid"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.push_log_query_uuid_invalid",
            Some(&invalid_uuid_params)
        ),
        "Invalid UUID: not-a-uuid."
    );

    let params = BTreeMap::from([
        ("deleted_count".to_string(), "3".to_string()),
        ("retention_days".to_string(), "2".to_string()),
    ]);
    assert_eq!(
        localizer.localize("zh-CN", "admin.system_log_cleanup_success", Some(&params)),
        "成功删除 3 条日志，保留最近 2 天的日志"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.push_log_cleanup_success", Some(&params)),
        "Deleted 3 push logs successfully. Retained logs from the last 2 days."
    );
    let cleanup_params = BTreeMap::from([("cleaned_count".to_string(), "22".to_string())]);
    assert_eq!(
        localizer.localize("zh-CN", "admin.data_cleanup_failed", Some(&cleanup_params)),
        "数据清理失败，已清理 22 个表"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.data_cleanup_success", Some(&cleanup_params)),
        "Successfully cleaned data from 22 tables."
    );

    let user_create_params = BTreeMap::from([(
        "user_id".to_string(),
        "00000000-0000-0000-0000-000000000001".to_string(),
    )]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "admin.user_create_success",
            Some(&user_create_params)
        ),
        "用户创建成功，ID: 00000000-0000-0000-0000-000000000001"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.user_create_success",
            Some(&user_create_params)
        ),
        "User created successfully. ID: 00000000-0000-0000-0000-000000000001"
    );

    let file_delete_params = BTreeMap::from([("deleted_count".to_string(), "2".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "admin.file_batch_delete_success",
            Some(&file_delete_params)
        ),
        "成功删除 2 个文件"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.file_batch_delete_success",
            Some(&file_delete_params)
        ),
        "Deleted 2 files successfully."
    );
    assert_eq!(
        localizer.localize("zh-CN", "admin.storage_test_file_size_invalid", None),
        "file_size 必填且必须大于 0"
    );
    let cors_method_params = BTreeMap::from([("method".to_string(), "TRACE".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "admin.storage_test_cors_method_unsupported",
            Some(&cors_method_params)
        ),
        "不支持的跨域方法: TRACE，COS 仅允许 GET/PUT/POST/DELETE/HEAD"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.storage_test_cors_method_unsupported",
            Some(&cors_method_params)
        ),
        "Unsupported CORS method: TRACE. COS only allows GET/PUT/POST/DELETE/HEAD."
    );

    let admin_bootstrap_params = BTreeMap::from([
        ("username".to_string(), "admin".to_string()),
        ("password".to_string(), "admin123".to_string()),
    ]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "admin.default_admin_create_success",
            Some(&admin_bootstrap_params)
        ),
        "默认管理员用户创建成功，用户名: admin，密码: admin123"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.admin_password_reset_success",
            Some(&BTreeMap::from([(
                "password".to_string(),
                "admin123".to_string(),
            )]))
        ),
        "Admin password reset successfully. Password: admin123"
    );

    assert_eq!(
        localizer.localize("zh-CN", "admin.storage_provider_name_required", None),
        "提供商名称不能为空"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.storage_provider_id_invalid", None),
        "Storage provider ID is invalid."
    );

    let provider_params =
        BTreeMap::from([("provider_type".to_string(), "foo-storage".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "admin.storage_provider_type_unsupported",
            Some(&provider_params)
        ),
        "不支持的提供商类型: foo-storage"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.default_storage_provider_not_found", None),
        "Default file upload storage provider configuration was not found."
    );

    assert_eq!(
        localizer.localize("zh-CN", "admin.file_upload_audit_task_id_invalid", None),
        "无效的 task_id"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.file_upload_audit_provider_id_invalid", None),
        "provider_id is invalid."
    );
    assert_eq!(
        localizer.localize("en-US", "admin.file_upload_audit_task_not_found", None),
        "Audit task was not found."
    );
    assert_eq!(
        localizer.localize("en-US", "admin.file_upload_audit_requeue_success", None),
        "Requeued successfully."
    );

    let geolocation_params =
        BTreeMap::from([("reason".to_string(), "upstream timeout".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "admin.geolocation_api_test_failed",
            Some(&geolocation_params)
        ),
        "API测试失败: upstream timeout"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "admin.ip_geolocation_update_failed",
            Some(&geolocation_params)
        ),
        "Failed to update IP geolocation setting: upstream timeout"
    );
    assert_eq!(
        localizer.localize("zh-CN", "admin.admin_user_not_found", None),
        "管理员用户不存在"
    );
    assert_eq!(
        localizer.localize("zh-CN", "admin.active_nodes_fetch_failed", None),
        "获取节点信息失败，请稍后重试"
    );
    assert_eq!(
        localizer.localize("en-US", "admin.api_performance_stats_fetch_failed", None),
        "Failed to load API performance statistics. Please try again later."
    );
    assert_eq!(
        localizer.localize("zh-CN", "admin.admin_password_verify_failed", None),
        "密码验证失败，请稍后重试"
    );
}

#[test]
fn i18n_message_catalog_interpolates_task_4c_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    let reaction_params = BTreeMap::from([
        ("reaction_key".to_string(), "🔥".to_string()),
        ("supported".to_string(), "👍, ❤️, 😂".to_string()),
    ]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "message.reaction_key_unsupported",
            Some(&reaction_params)
        ),
        "不支持的反应类型：🔥。支持的类型：👍, ❤️, 😂"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "message.reaction_key_unsupported",
            Some(&reaction_params)
        ),
        "Unsupported reaction type: 🔥. Supported types: 👍, ❤️, 😂."
    );

    let max_params = BTreeMap::from([("max".to_string(), "10000".to_string())]);
    assert_eq!(
        localizer.localize("zh-CN", "message.edit_content_too_long", Some(&max_params)),
        "消息内容过长，最多 10000 个字符"
    );
    assert_eq!(
        localizer.localize("en-US", "message.edit_content_too_long", Some(&max_params)),
        "Message content is too long. Maximum allowed is 10000 characters."
    );
}

#[test]
fn i18n_message_catalog_loads_task_4d_complete_keyset_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    let zh_expectations = vec![
        (
            "message.clear_room_membership_required",
            "您不在当前房间，无法清除聊天记录",
        ),
        (
            "message.clear_room_not_found",
            "房间不存在，无法清除聊天记录",
        ),
        (
            "message.clear_group_owner_only",
            "仅群主可以清除群聊聊天记录",
        ),
        (
            "message.attachment_upload_room_membership_required",
            "您不在当前房间，无法上传附件",
        ),
        (
            "message.attachment_download_room_membership_required",
            "您不在当前房间，无法获取附件",
        ),
        (
            "message.attachment_commit_room_membership_required",
            "您不在当前房间，无法提交附件上传结果",
        ),
        (
            "message.attachment_signature_text_unsupported",
            "纯文本内容无需生成上传签名",
        ),
        (
            "message.attachment_multipart_text_unsupported",
            "纯文本内容无需分片上传",
        ),
        (
            "message.attachment_file_size_required",
            "file_size 必填且必须大于 0",
        ),
        (
            "message.attachment_file_size_exceeded_bytes",
            "文件大小超出限制：实际 {actual_size} 字节，最大允许 {max_size} 字节",
        ),
        (
            "message.attachment_multipart_session_create_failed",
            "初始化附件分片上传会话失败，请稍后重试",
        ),
        ("message.attachment_not_found", "附件不存在"),
        (
            "message.attachment_size_mismatch",
            "附件大小校验失败：期望 {expected_size} 字节，实际 {actual_size} 字节",
        ),
        (
            "message.attachment_hash_mismatch",
            "附件哈希校验失败，请重新上传",
        ),
        (
            "message.attachment_object_not_found",
            "对象存储中找不到该附件，请稍后重试",
        ),
        (
            "message.attachment_multipart_direct_upload_required",
            "文件大小必须超过 {threshold_size} 字节才能使用分片上传",
        ),
        (
            "message.attachment_multipart_plan_failed",
            "无法生成分片上传计划，请稍后重试",
        ),
        ("message.group_user_muted", "您已被禁言"),
        (
            "message.group_user_muted_until",
            "您已被禁言，预计 {until} 解除",
        ),
        ("message.group_user_muted_reason", "您已被禁言：{reason}"),
        (
            "message.group_user_muted_until_reason",
            "您已被禁言，预计 {until} 解除：{reason}",
        ),
        ("message.group_global_mute", "当前群聊已开启全体禁言"),
        (
            "message.group_global_mute_until",
            "当前群聊已开启全体禁言，预计 {until} 解除",
        ),
        (
            "message.group_global_mute_reason",
            "当前群聊已开启全体禁言：{reason}",
        ),
        (
            "message.group_global_mute_until_reason",
            "当前群聊已开启全体禁言，预计 {until} 解除：{reason}",
        ),
    ];

    for (key, value) in zh_expectations {
        assert_eq!(localizer.localize("zh-CN", key, None), value);
    }

    let en_expectations = vec![
        ("message.clear_room_membership_required", "You are not in this room and cannot clear chat history."),
        ("message.clear_room_not_found", "Room not found. Unable to clear history."),
        ("message.clear_group_owner_only", "Only the group owner can clear group chat history."),
        ("message.attachment_upload_room_membership_required", "You are not in this room and cannot upload attachments."),
        ("message.attachment_download_room_membership_required", "You are not in this room and cannot download attachments."),
        ("message.attachment_commit_room_membership_required", "You are not in this room and cannot commit attachment uploads."),
        ("message.attachment_signature_text_unsupported", "Text content does not require an upload signature."),
        ("message.attachment_multipart_text_unsupported", "Multipart upload is not supported for text content."),
        ("message.attachment_file_size_required", "file_size is required and must be greater than 0."),
        ("message.attachment_file_size_exceeded_bytes", "Attachment size exceeds the limit: actual {actual_size} bytes, maximum allowed {max_size} bytes."),
        ("message.attachment_multipart_session_create_failed", "Failed to initialize attachment multipart upload session. Please try again later."),
        ("message.attachment_not_found", "Attachment not found."),
        ("message.attachment_size_mismatch", "Attachment size mismatch: expected {expected_size} bytes, got {actual_size} bytes."),
        ("message.attachment_hash_mismatch", "Attachment hash mismatch. Please re-upload."),
        ("message.attachment_object_not_found", "Attachment object was not found in storage. Please try again later."),
        ("message.attachment_multipart_direct_upload_required", "File size must exceed {threshold_size} bytes to use multipart upload."),
        ("message.attachment_multipart_plan_failed", "Failed to plan multipart upload. Please try again later."),
        ("message.group_user_muted", "You have been muted."),
        (
            "message.group_user_muted_until",
            "You have been muted until {until}.",
        ),
        (
            "message.group_user_muted_reason",
            "You have been muted: {reason}.",
        ),
        (
            "message.group_user_muted_until_reason",
            "You have been muted until {until}: {reason}.",
        ),
        ("message.group_global_mute", "This group is currently under global mute."),
        (
            "message.group_global_mute_until",
            "This group is currently under global mute until {until}.",
        ),
        (
            "message.group_global_mute_reason",
            "This group is currently under global mute: {reason}.",
        ),
        (
            "message.group_global_mute_until_reason",
            "This group is currently under global mute until {until}: {reason}.",
        ),
    ];

    for (key, value) in en_expectations {
        assert_eq!(localizer.localize("en-US", key, None), value);
    }
}

#[test]
fn i18n_message_catalog_interpolates_task_4d_params_extended() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let exceeded_params = BTreeMap::from([
        ("actual_size".to_string(), "5000".to_string()),
        ("max_size".to_string(), "4096".to_string()),
    ]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "message.attachment_file_size_exceeded_bytes",
            Some(&exceeded_params),
        ),
        "文件大小超出限制：实际 5000 字节，最大允许 4096 字节"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "message.attachment_file_size_exceeded_bytes",
            Some(&exceeded_params),
        ),
        "Attachment size exceeds the limit: actual 5000 bytes, maximum allowed 4096 bytes."
    );

    let mismatch_params = BTreeMap::from([
        ("expected_size".to_string(), "4096".to_string()),
        ("actual_size".to_string(), "5000".to_string()),
    ]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "message.attachment_size_mismatch",
            Some(&mismatch_params)
        ),
        "附件大小校验失败：期望 4096 字节，实际 5000 字节"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "message.attachment_size_mismatch",
            Some(&mismatch_params)
        ),
        "Attachment size mismatch: expected 4096 bytes, got 5000 bytes."
    );

    let threshold_params = BTreeMap::from([("threshold_size".to_string(), "5242880".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "message.attachment_multipart_direct_upload_required",
            Some(&threshold_params),
        ),
        "文件大小必须超过 5242880 字节才能使用分片上传"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "message.attachment_multipart_direct_upload_required",
            Some(&threshold_params),
        ),
        "File size must exceed 5242880 bytes to use multipart upload."
    );

    let muted_params = BTreeMap::from([
        ("until".to_string(), "2026-04-02T08:00:00+00:00".to_string()),
        ("reason".to_string(), "刷屏".to_string()),
    ]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "message.group_user_muted_until_reason",
            Some(&muted_params),
        ),
        "您已被禁言，预计 2026-04-02T08:00:00+00:00 解除：刷屏"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "message.group_user_muted_until_reason",
            Some(&muted_params),
        ),
        "You have been muted until 2026-04-02T08:00:00+00:00: 刷屏."
    );

    let global_mute_params = BTreeMap::from([
        ("until".to_string(), "2026-04-02T09:30:00+00:00".to_string()),
        ("reason".to_string(), "maintenance".to_string()),
    ]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "message.group_global_mute_until_reason",
            Some(&global_mute_params),
        ),
        "当前群聊已开启全体禁言，预计 2026-04-02T09:30:00+00:00 解除：maintenance"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "message.group_global_mute_until_reason",
            Some(&global_mute_params),
        ),
        "This group is currently under global mute until 2026-04-02T09:30:00+00:00: maintenance."
    );
}

#[test]
fn i18n_group_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "group.owner_cannot_be_removed", None),
        "无法移除群主"
    );
    assert_eq!(
        localizer.localize("en-US", "group.owner_cannot_be_removed", None),
        "The group owner cannot be removed."
    );
    assert_eq!(
        localizer.localize("zh-CN", "group.not_found", None),
        "群组不存在"
    );
    assert_eq!(
        localizer.localize("en-US", "group.not_found", None),
        "Group not found."
    );
}

#[test]
fn i18n_group_catalog_interpolates_member_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    let invalid_user_params = BTreeMap::from([("user_id".to_string(), "not-a-uuid".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "group.member_id_invalid",
            Some(&invalid_user_params)
        ),
        "无效的用户ID: not-a-uuid"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "group.member_id_invalid",
            Some(&invalid_user_params)
        ),
        "User ID is invalid: not-a-uuid."
    );

    let remaining_params = BTreeMap::from([("remaining_slots".to_string(), "3".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "group.member_add_limit_exceeded",
            Some(&remaining_params),
        ),
        "可添加成员数量超出上限，仅剩 3 个名额"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "group.member_add_limit_exceeded",
            Some(&remaining_params),
        ),
        "Adding members exceeds the group limit. Only 3 slots remain."
    );
}

#[test]
fn i18n_version_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "version.channel_required", None),
        "channel 不能为空"
    );
    assert_eq!(
        localizer.localize("en-US", "version.channel_required", None),
        "channel is required."
    );
    assert_eq!(
        localizer.localize("zh-CN", "version.no_available_release", None),
        "暂无可用版本"
    );
    assert_eq!(
        localizer.localize("en-US", "version.no_available_release", None),
        "No available version right now."
    );
}

#[test]
fn i18n_version_catalog_interpolates_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    let platform_params = BTreeMap::from([
        ("platform".to_string(), "symbian".to_string()),
        (
            "supported_platforms".to_string(),
            "windows, macos, ios, android, linux".to_string(),
        ),
    ]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "version.platform_unsupported",
            Some(&platform_params)
        ),
        "不支持的平台: symbian。支持的平台: windows, macos, ios, android, linux"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "version.platform_unsupported",
            Some(&platform_params)
        ),
        "Unsupported platform: symbian. Supported platforms: windows, macos, ios, android, linux."
    );

    let provider_params = BTreeMap::from([("provider_type".to_string(), "minio".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "version.default_storage_provider_unsupported",
            Some(&provider_params),
        ),
        "不支持的默认存储提供商类型: minio"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "version.default_storage_provider_unsupported",
            Some(&provider_params),
        ),
        "Unsupported default storage provider type: minio."
    );
}

#[test]
fn i18n_version_catalog_loads_tail_keys_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "version.version_id_invalid", None),
        "无效的版本 ID"
    );
    assert_eq!(
        localizer.localize("en-US", "version.version_id_invalid", None),
        "Version ID is invalid."
    );
    assert_eq!(
        localizer.localize("zh-CN", "version.app_version_id_invalid", None),
        "无效的 app_version_id"
    );
    assert_eq!(
        localizer.localize("en-US", "version.app_version_id_invalid", None),
        "app_version_id is invalid."
    );
    assert_eq!(
        localizer.localize("zh-CN", "version.package_version_not_found", None),
        "绑定的整包版本不存在"
    );
    assert_eq!(
        localizer.localize("en-US", "version.rollout_percentage_invalid", None),
        "rollout_percentage must be between 0 and 100."
    );
}

#[test]
fn i18n_version_catalog_interpolates_tail_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([
        ("expected".to_string(), "1024".to_string()),
        ("actual".to_string(), "2048".to_string()),
    ]);

    assert_eq!(
        localizer.localize("zh-CN", "version.package_size_mismatch", Some(&params)),
        "安装包大小校验失败：期望 1024 字节，实际 2048 字节"
    );
    assert_eq!(
        localizer.localize("en-US", "version.patch_size_mismatch", Some(&params)),
        "Patch size mismatch: expected 1024 bytes, got 2048 bytes."
    );
}

#[test]
fn i18n_version_catalog_loads_multipart_plan_tail_keys() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "version.file_size_invalid", None),
        "file_size 必须大于 0"
    );
    assert_eq!(
        localizer.localize("en-US", "version.multipart_plan_failed", None),
        "Failed to generate the version multipart upload plan. Please try again later."
    );
}

#[test]
fn i18n_version_catalog_interpolates_multipart_threshold_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([("threshold_size".to_string(), "5242880".to_string())]);

    assert_eq!(
        localizer.localize(
            "zh-CN",
            "version.multipart_direct_upload_required",
            Some(&params)
        ),
        "文件大小不超过 5242880 字节，请使用单文件直传"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "version.multipart_direct_upload_required",
            Some(&params)
        ),
        "Files no larger than 5242880 bytes must use direct upload instead of multipart upload."
    );
}

#[test]
fn i18n_room_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "room.name_required", None),
        "房间名称不能为空"
    );
    assert_eq!(
        localizer.localize("en-US", "room.membership_required", None),
        "You are not a member of this room."
    );
    assert_eq!(
        localizer.localize("zh-CN", "room.new_owner_same_as_current", None),
        "新群主必须与当前群主不同"
    );
    assert_eq!(
        localizer.localize("zh-CN", "room.favorite_default_name", None),
        "收藏夹"
    );
    assert_eq!(
        localizer.localize("en-US", "room.favorite_default_name", None),
        "Favorites"
    );
    assert_eq!(
        localizer.localize("zh-CN", "room.favorite_default_description", None),
        "保存重要消息、文件与提醒的私人收藏夹"
    );
    assert_eq!(
        localizer.localize("en-US", "room.favorite_default_description", None),
        "A private favorites room for saving important messages, files, and reminders."
    );
}

#[test]
fn i18n_room_catalog_interpolates_member_id_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([("user_id".to_string(), "not-a-uuid".to_string())]);

    assert_eq!(
        localizer.localize("zh-CN", "room.member_id_invalid", Some(&params)),
        "无效的成员 ID: not-a-uuid"
    );
    assert_eq!(
        localizer.localize("en-US", "room.member_id_invalid", Some(&params)),
        "Member ID is invalid: not-a-uuid."
    );
}

#[test]
fn i18n_room_catalog_loads_avatar_tail_keys_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "room.avatar_image_only", None),
        "仅允许上传图片文件"
    );
    assert_eq!(
        localizer.localize("en-US", "room.avatar_manage_forbidden", None),
        "Only the room owner or an admin can upload the avatar."
    );
    assert_eq!(
        localizer.localize("en-US", "room.avatar_object_key_invalid", None),
        "Invalid room avatar object key."
    );
}

#[test]
fn i18n_room_catalog_interpolates_avatar_tail_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let size_params = BTreeMap::from([("max_mb".to_string(), "5".to_string())]);
    let mismatch_params = BTreeMap::from([
        ("expected".to_string(), "1024".to_string()),
        ("actual".to_string(), "2048".to_string()),
    ]);

    assert_eq!(
        localizer.localize("zh-CN", "room.avatar_size_exceeded", Some(&size_params)),
        "文件大小超出限制，最大允许5MB"
    );
    assert_eq!(
        localizer.localize("en-US", "room.avatar_size_mismatch", Some(&mismatch_params)),
        "Room avatar size mismatch: expected 1024 bytes, got 2048 bytes."
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
async fn i18n_error_response_message_cache_override_keeps_protocol_and_masks_details() {
    let error = message_cache_error("message.send_rate_limit_cache_failed", "redis incr failed");
    let body = read_body_json(error.into_response().into_body()).await;

    assert_eq!(body["code"], 50201);
    assert_eq!(body["message_key"], "message.send_rate_limit_cache_failed");
    assert_eq!(body["message"], "消息发送限流暂时不可用，请稍后重试");
    assert_eq!(body["message_params"], Value::Null);
    assert_eq!(body["details"], Value::Null);
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

#[tokio::test]
async fn i18n_error_response_group_member_id_invalid_uses_params_and_localized_message() {
    let params = BTreeMap::from([("user_id".to_string(), "not-a-uuid".to_string())]);
    let response = AppError::ValidationError(String::new())
        .with_message_key_and_params("group.member_id_invalid", Some(params.clone()))
        .into_response();
    let body = read_body_json(response.into_body()).await;

    assert_eq!(body["code"], 42201);
    assert_eq!(body["message_key"], "group.member_id_invalid");
    assert_eq!(body["message"], "无效的用户ID: not-a-uuid");
    assert_eq!(body["message_params"]["user_id"], params["user_id"]);
    assert_eq!(body["details"], Value::Null);
}

#[tokio::test]
async fn i18n_error_response_version_platform_unsupported_uses_params_and_localized_message() {
    let params = BTreeMap::from([
        ("platform".to_string(), "symbian".to_string()),
        (
            "supported_platforms".to_string(),
            "windows, macos, ios, android, linux".to_string(),
        ),
    ]);
    let response = AppError::ValidationError(String::new())
        .with_message_key_and_params("version.platform_unsupported", Some(params.clone()))
        .into_response();
    let body = read_body_json(response.into_body()).await;

    assert_eq!(body["code"], 42201);
    assert_eq!(body["message_key"], "version.platform_unsupported");
    assert_eq!(
        body["message"],
        "不支持的平台: symbian。支持的平台: windows, macos, ios, android, linux"
    );
    assert_eq!(body["message_params"]["platform"], params["platform"]);
    assert_eq!(
        body["message_params"]["supported_platforms"],
        params["supported_platforms"]
    );
    assert_eq!(body["details"], Value::Null);
}

#[tokio::test]
async fn i18n_error_response_room_member_id_invalid_uses_params_and_localized_message() {
    let params = BTreeMap::from([("user_id".to_string(), "not-a-uuid".to_string())]);
    let response = AppError::ValidationError(String::new())
        .with_message_key_and_params("room.member_id_invalid", Some(params.clone()))
        .into_response();
    let body = read_body_json(response.into_body()).await;

    assert_eq!(body["code"], 42201);
    assert_eq!(body["message_key"], "room.member_id_invalid");
    assert_eq!(body["message"], "无效的成员 ID: not-a-uuid");
    assert_eq!(body["message_params"]["user_id"], params["user_id"]);
    assert_eq!(body["details"], Value::Null);
}

#[test]
fn i18n_upload_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    assert_eq!(
        localizer.localize("zh-CN", "upload.invalid_session_id", None),
        "无效的 session_id"
    );
    assert_eq!(
        localizer.localize("en-US", "upload.invalid_session_id", None),
        "session_id is invalid."
    );
    assert_eq!(
        localizer.localize("zh-CN", "upload.multipart_file_size_invalid", None),
        "file_size 必须大于 0"
    );
    assert_eq!(
        localizer.localize("en-US", "upload.multipart_plan_failed", None),
        "Failed to plan multipart upload. Please try again later."
    );
}

#[test]
fn i18n_upload_catalog_interpolates_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([
        ("expected".to_string(), "4".to_string()),
        ("actual".to_string(), "2".to_string()),
    ]);
    assert_eq!(
        localizer.localize("zh-CN", "upload.part_count_incomplete", Some(&params)),
        "分片数量不完整：期望 4 个，实际 2 个"
    );
    assert_eq!(
        localizer.localize("en-US", "upload.part_count_incomplete", Some(&params)),
        "Incomplete parts list: expected 4 parts, got 2."
    );

    let threshold_params = BTreeMap::from([("threshold_size".to_string(), "5242880".to_string())]);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "upload.multipart_direct_upload_required",
            Some(&threshold_params)
        ),
        "文件大小不超过 5242880 字节，请使用单文件直传"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "upload.multipart_direct_upload_required",
            Some(&threshold_params)
        ),
        "File size must exceed 5242880 bytes to use multipart upload."
    );
}

#[test]
fn i18n_upload_catalog_loads_cleanup_storage_provider_key() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "upload.storage_provider_inactive_for_cleanup",
            None
        ),
        "存储提供商未启用，无法执行清理任务"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "upload.storage_provider_inactive_for_cleanup",
            None
        ),
        "Storage provider is inactive and file upload cleanup cannot continue."
    );
}

#[test]
fn i18n_storage_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "storage.object_head_unsupported", None),
        "当前存储提供商不支持对象元数据查询"
    );
    assert_eq!(
        localizer.localize("en-US", "storage.download_url_unsupported", None),
        "The current storage provider does not support generating download URLs."
    );
    assert_eq!(
        localizer.localize(
            "zh-CN",
            "storage.bucket_name_required_for_tencent_cos",
            None
        ),
        "腾讯云COS需要配置bucket_name"
    );
}

#[test]
fn i18n_common_catalog_loads_uuid_invalid_key() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "common.uuid_invalid", None),
        "无效的 UUID"
    );
    assert_eq!(
        localizer.localize("en-US", "common.uuid_invalid", None),
        "Invalid UUID."
    );
}

#[test]
fn i18n_storage_catalog_interpolates_provider_type_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([("provider_type".to_string(), "minio".to_string())]);

    assert_eq!(
        localizer.localize("zh-CN", "storage.provider_type_unsupported", Some(&params)),
        "不支持的存储提供商类型: minio"
    );
    assert_eq!(
        localizer.localize("en-US", "storage.provider_type_unsupported", Some(&params)),
        "Unsupported storage provider type: minio."
    );
}

#[test]
fn i18n_common_admin_and_upload_storage_tail_catalogs_are_loaded() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "common.http_client_create_failed", None),
        "创建 HTTP 客户端失败"
    );
    assert_eq!(
        localizer.localize("en-US", "common.http_client_create_failed", None),
        "Failed to create HTTP client."
    );
    assert_eq!(
        localizer.localize("zh-CN", "admin.storage_provider_bucket_required", None),
        "存储提供商未配置 bucket_name"
    );
    assert_eq!(
        localizer.localize("en-US", "upload.object_not_found", None),
        "Object was not found in storage."
    );
}

#[test]
fn i18n_upload_storage_tail_catalog_interpolates_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([("reason".to_string(), "boom".to_string())]);

    assert_eq!(
        localizer.localize("zh-CN", "upload.audit_claim_failed", Some(&params)),
        "认领审核任务失败: boom"
    );
    assert_eq!(
        localizer.localize("en-US", "upload.audit_submit_failed", Some(&params)),
        "Failed to submit audit job: boom"
    );
    assert_eq!(
        localizer.localize("zh-CN", "upload.multipart_init_failed", Some(&params)),
        "初始化分片上传失败: boom"
    );
    assert_eq!(
        localizer.localize("en-US", "upload.object_upload_failed", Some(&params)),
        "Failed to upload object: boom"
    );
    assert_eq!(
        localizer.localize("zh-CN", "upload.object_delete_failed", Some(&params)),
        "删除对象失败: boom"
    );
    assert_eq!(
        localizer.localize("en-US", "upload.object_exists_check_failed", Some(&params)),
        "Failed to check object existence: boom"
    );
    assert_eq!(
        localizer.localize("zh-CN", "upload.object_head_failed", Some(&params)),
        "获取对象元数据失败: boom"
    );
}

#[test]
fn i18n_upload_storage_object_key_catalog_is_loaded() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "upload.object_key_required", None),
        "文件路径（key）不能为空"
    );
    assert_eq!(
        localizer.localize("en-US", "upload.object_key_required", None),
        "File path (key) is required."
    );
}

#[test]
fn i18n_feedback_upload_policy_and_room_tail_catalogs_are_loaded() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "feedback.content_required", None),
        "反馈内容不能为空"
    );
    assert_eq!(
        localizer.localize("en-US", "upload_policy.audio_only_rule_locked", None),
        "Modifying the audio_only rule is not supported in the current version."
    );
    assert_eq!(
        localizer.localize("en-US", "room.room_id_invalid", None),
        "Room ID is invalid."
    );
}

#[test]
fn i18n_upload_policy_tail_catalog_interpolates_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([("reason".to_string(), "boom".to_string())]);

    assert_eq!(
        localizer.localize("zh-CN", "upload_policy.serialize_failed", Some(&params)),
        "序列化 upload policy 失败: boom"
    );
    assert_eq!(
        localizer.localize("en-US", "upload_policy.serialize_failed", Some(&params)),
        "Failed to serialize upload policy: boom"
    );
}

#[test]
fn i18n_emoji_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    assert_eq!(
        localizer.localize("zh-CN", "emoji.pack_name_required", None),
        "贴纸名称不能为空"
    );
    assert_eq!(
        localizer.localize("en-US", "emoji.pack_name_required", None),
        "Pack name is required."
    );
    assert_eq!(
        localizer.localize("zh-CN", "emoji.object_key_required", None),
        "object_key 不能为空"
    );
    assert_eq!(
        localizer.localize("en-US", "emoji.object_key_required", None),
        "object_key is required."
    );
}

#[test]
fn i18n_report_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    assert_eq!(
        localizer.localize("zh-CN", "report.content_type_required", None),
        "content_type 不能为空"
    );
    assert_eq!(
        localizer.localize("en-US", "report.content_type_required", None),
        "content_type is required."
    );
}

#[test]
fn i18n_report_catalog_interpolates_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([("max_mb".to_string(), "5".to_string())]);
    assert_eq!(
        localizer.localize("zh-CN", "report.attachment_size_exceeded", Some(&params)),
        "截图大小超出限制，最大允许5MB"
    );
    assert_eq!(
        localizer.localize("en-US", "report.attachment_size_exceeded", Some(&params)),
        "Attachment size exceeds the limit. Maximum allowed is 5 MB."
    );
}

#[test]
fn i18n_push_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    assert_eq!(
        localizer.localize("zh-CN", "push.device_token_invalid", None),
        "device_token 无效"
    );
    assert_eq!(
        localizer.localize("en-US", "push.device_token_invalid", None),
        "device_token is invalid."
    );
}

#[test]
fn i18n_push_catalog_interpolates_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([("provider".to_string(), "apns".to_string())]);
    assert_eq!(
        localizer.localize("zh-CN", "push.provider_unsupported", Some(&params)),
        "暂不支持的 provider: apns"
    );
    assert_eq!(
        localizer.localize("en-US", "push.provider_unsupported", Some(&params)),
        "Unsupported provider for now: apns."
    );
}

#[test]
fn i18n_push_catalog_loads_notification_copy_keys() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    assert_eq!(
        localizer.localize("zh-CN", "push.preview_image", None),
        "[图片]"
    );
    assert_eq!(
        localizer.localize("en-US", "push.preview_file", None),
        "[File]"
    );
    assert_eq!(
        localizer.localize("zh-CN", "push.friend_request_title", None),
        "新的好友请求"
    );
    assert_eq!(
        localizer.localize("en-US", "push.preview_fallback", None),
        "[New message]"
    );
    assert_eq!(
        localizer.localize("zh-CN", "push.group_event_dissolved_title", None),
        "群聊已解散"
    );
    assert_eq!(
        localizer.localize("en-US", "push.group_event_kicked_title", None),
        "Removed from group"
    );
    assert_eq!(
        localizer.localize("zh-CN", "push.group_room_fallback", None),
        "群聊"
    );
    assert_eq!(
        localizer.localize("en-US", "push.group_room_fallback", None),
        "Group chat"
    );
}

#[test]
fn i18n_push_catalog_interpolates_friend_request_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([
        ("requester_name".to_string(), "Alice".to_string()),
        ("message".to_string(), "Hello".to_string()),
    ]);
    assert_eq!(
        localizer.localize("zh-CN", "push.friend_request_body_default", Some(&params)),
        "Alice 想添加你为好友"
    );
    assert_eq!(
        localizer.localize(
            "en-US",
            "push.friend_request_body_with_message",
            Some(&params),
        ),
        "Alice: Hello"
    );
}

#[test]
fn i18n_e2ee_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    assert_eq!(
        localizer.localize("zh-CN", "e2ee.target_user_not_initialized", None),
        "目标用户未初始化 E2EE"
    );
    assert_eq!(
        localizer.localize("en-US", "e2ee.target_user_not_initialized", None),
        "Target user has not initialized E2EE."
    );
}

#[test]
fn i18n_e2ee_catalog_interpolates_params() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);
    let params = BTreeMap::from([("field".to_string(), "identity_key".to_string())]);
    assert_eq!(
        localizer.localize("zh-CN", "e2ee.field_base64_decode_failed", Some(&params)),
        "identity_key base64 解码失败"
    );
    assert_eq!(
        localizer.localize("en-US", "e2ee.field_base64_decode_failed", Some(&params)),
        "identity_key base64 decode failed."
    );
}

#[test]
fn i18n_chat_history_catalog_is_loaded_for_both_locales() {
    let localizer = Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE);

    assert_eq!(
        localizer.localize("zh-CN", "chat_history.unknown_user", None),
        "未知用户"
    );
    assert_eq!(
        localizer.localize("en-US", "chat_history.unknown_user", None),
        "Unknown user"
    );
    assert_eq!(
        localizer.localize("zh-CN", "chat_history.unnamed_room", None),
        "未命名房间"
    );
    assert_eq!(
        localizer.localize("en-US", "chat_history.unnamed_room", None),
        "Unnamed room"
    );
}

async fn read_body_json(body: Body) -> Value {
    let bytes = body
        .collect()
        .await
        .expect("collect response body")
        .to_bytes();
    serde_json::from_slice(&bytes).expect("parse json body")
}
