//! SettingsStore 测试
//!
//! 覆盖验证码设置、通用设置、用户账号限制等功能。
//!
//! 注意：由于 settings 表是全局配置，测试使用唯一 key 避免冲突。

use super::common::setup_test_db;
use redcode_im_backend::database::settings_store::SettingsStore;
use uuid::Uuid;

// ============================================================================
// 验证码设置测试
// ============================================================================

#[tokio::test]
async fn test_get_captcha_setting() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    // 获取验证码设置（可能已存在，也可能返回默认值）
    let result = store.get_captcha_setting().await;
    assert!(result.is_ok(), "获取验证码设置应成功");
}

#[tokio::test]
async fn test_upsert_captcha_setting() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    // 使用唯一验证码避免冲突
    let unique_code = format!("CODE_{}", Uuid::new_v4().simple());
    let unique_desc = format!("测试验证码_{}", Uuid::new_v4().simple());

    // 创建/更新验证码设置 (不传递 updated_by 避免外键约束问题)
    let result = store
        .upsert_captcha_setting(true, &unique_code, &unique_desc, true, None)
        .await;

    assert!(result.is_ok(), "更新验证码设置应成功: {:?}", result.err());
    let setting = result.unwrap();
    assert!(setting.enabled, "应该启用");
    assert_eq!(setting.captcha_code, unique_code);
    assert_eq!(setting.description, unique_desc);
    assert!(setting.require_captcha_for_login);
}

#[tokio::test]
async fn test_is_universal_captcha_code_valid() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    // 先设置万能验证码
    let unique_code = format!("UNIVERSAL_{}", Uuid::new_v4().simple());
    let _ = store
        .upsert_captcha_setting(true, &unique_code, "万能码测试", false, None)
        .await
        .unwrap();

    // 测试匹配（忽略大小写）
    let result = store.is_universal_captcha_code(&unique_code.to_lowercase()).await;
    assert!(result.is_ok());
    assert!(result.unwrap(), "应该匹配万能验证码");

    let result = store.is_universal_captcha_code(&unique_code.to_uppercase()).await;
    assert!(result.unwrap(), "大写应该匹配");
}

#[tokio::test]
async fn test_is_universal_captcha_code_disabled() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    // 设置但禁用万能验证码
    let unique_code = format!("DISABLED_{}", Uuid::new_v4().simple());
    let _ = store
        .upsert_captcha_setting(false, &unique_code, "禁用状态测试", false, None)
        .await
        .unwrap();

    let result = store.is_universal_captcha_code(&unique_code).await;
    assert!(result.is_ok());
    assert!(!result.unwrap(), "禁用状态不应匹配");
}

#[tokio::test]
async fn test_is_universal_captcha_code_empty_input() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    let result = store.is_universal_captcha_code("").await;
    assert!(result.is_ok());
    assert!(!result.unwrap(), "空输入不应匹配");

    let result = store.is_universal_captcha_code("   ").await;
    assert!(result.is_ok());
    assert!(!result.unwrap(), "空白输入不应匹配");
}

#[tokio::test]
async fn test_require_captcha_for_login() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    // 设置要求验证码登录
    let _ = store
        .upsert_captcha_setting(true, "LOGIN_TEST", "登录验证码测试", true, None)
        .await
        .unwrap();

    let result = store.require_captcha_for_login().await;
    assert!(result.is_ok());
    assert!(result.unwrap(), "应该要求验证码");
}

// ============================================================================
// 通用设置测试
// ============================================================================

#[tokio::test]
async fn test_get_general_setting_not_exists() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    // 使用唯一 key 确保不存在
    let nonexistent_key = format!("nonexistent_{}", Uuid::new_v4().simple());
    let result = store.get_general_setting(&nonexistent_key).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_none(), "不存在的设置应返回 None");
}

#[tokio::test]
async fn test_upsert_general_setting() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    // 使用唯一 key
    let key = format!("test_key_{}", Uuid::new_v4().simple());

    // 创建设置 (不传递 updated_by 避免外键约束问题)
    let result = store
        .upsert_general_setting(&key, "test_value", "测试描述", None)
        .await;

    assert!(result.is_ok(), "创建设置应成功: {:?}", result.err());
    let setting = result.unwrap();
    assert_eq!(setting.key, key);
    assert_eq!(setting.value, "test_value");
    assert_eq!(setting.description, "测试描述");

    // 更新设置
    let result = store
        .upsert_general_setting(&key, "updated_value", "更新描述", None)
        .await;

    assert!(result.is_ok());
    let setting = result.unwrap();
    assert_eq!(setting.value, "updated_value");
    assert_eq!(setting.description, "更新描述");
}

#[tokio::test]
async fn test_get_app_name() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    // get_app_name 应该总是返回一个值（默认或自定义）
    let result = store.get_app_name().await;
    assert!(result.is_ok());
    let app_name = result.unwrap();
    // 只验证返回非空字符串
    assert!(!app_name.is_empty(), "应用名称不应为空");
}

#[tokio::test]
async fn test_set_and_get_app_name() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    // 设置自定义应用名称
    let unique_name = format!("TestApp_{}", Uuid::new_v4().simple());
    let _ = store
        .upsert_general_setting("app_name", &unique_name, "测试应用名", None)
        .await
        .unwrap();

    let result = store.get_app_name().await;
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), unique_name);
}

// ============================================================================
// 用户账号限制设置测试
// ============================================================================

#[tokio::test]
async fn test_get_user_account_limit_setting() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    // 获取设置（可能是默认值或已配置的值）
    let result = store.get_user_account_limit_setting().await;
    assert!(result.is_ok(), "获取用户账号限制设置应成功");

    let setting = result.unwrap();
    // 验证字段类型正确，不验证具体值
    assert!(setting.min_length > 0, "最小长度应大于 0");
    assert!(setting.max_length >= setting.min_length, "最大长度应不小于最小长度");
}

#[tokio::test]
async fn test_update_user_account_limit_setting() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    // 使用随机值以区分不同测试运行
    let min_len = (rand::random::<i32>() % 10).abs() + 3;  // 3-12
    let max_len = min_len + 10;  // min + 10

    // 更新设置 (不传递 updated_by 避免外键约束问题)
    let result = store
        .update_user_account_limit_setting(
            false,   // enable_phone_validation
            true,    // enable_email_validation
            true,    // enable_length_validation
            min_len,
            max_len,
            true,    // enable_alphanumeric_validation
            None,
        )
        .await;

    assert!(result.is_ok(), "更新账号限制设置应成功: {:?}", result.err());
    let setting = result.unwrap();
    assert!(!setting.enable_phone_validation);
    assert!(setting.enable_email_validation);
    assert!(setting.enable_length_validation);
    assert_eq!(setting.min_length, min_len);
    assert_eq!(setting.max_length, max_len);
    assert!(setting.enable_alphanumeric_validation);
}

#[tokio::test]
async fn test_user_account_limit_setting_restore() {
    let test_db = setup_test_db().await;
    let store = SettingsStore::new(test_db.database());

    // 先更新为非默认值
    let _ = store
        .update_user_account_limit_setting(false, false, true, 6, 25, true, None)
        .await
        .unwrap();

    // 再恢复为默认值
    let result = store
        .update_user_account_limit_setting(true, false, false, 3, 20, false, None)
        .await;

    assert!(result.is_ok());
    let setting = result.unwrap();
    assert!(setting.enable_phone_validation);
    assert!(!setting.enable_email_validation);
    assert!(!setting.enable_length_validation);
}
