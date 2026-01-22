//! UserStore 测试
//!
//! 覆盖用户 CRUD、认证、搜索等功能。

use super::common::{setup_test_db, unique_email, unique_username};
use redcode_im_backend::database::models::{
    CreateUserRequest, LoginRequest, UpdateUserRequest, UserStatus,
};
use redcode_im_backend::database::user_store::UserStore;
use uuid::Uuid;

// ============================================================================
// 用户创建测试
// ============================================================================

#[tokio::test]
async fn test_create_user_success() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let username = unique_username();
    let email = unique_email();

    let request = CreateUserRequest {
        username: username.clone(),
        email: email.clone(),
        password: "password123".to_string(),
        nickname: Some("Test User".to_string()),
    };

    let result = store.create_user(request).await;
    assert!(result.is_ok(), "创建用户应该成功");

    let user = result.unwrap();
    assert_eq!(user.username, username);
    assert_eq!(user.email, email);
    assert_eq!(user.nickname, Some("Test User".to_string()));
    assert_eq!(user.status, UserStatus::Active);
    assert!(user.deleted_at.is_none());
}

#[tokio::test]
async fn test_create_user_duplicate_username() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let username = unique_username();

    let request1 = CreateUserRequest {
        username: username.clone(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: None,
    };

    let _ = store.create_user(request1).await.unwrap();

    let request2 = CreateUserRequest {
        username: username.clone(),
        email: unique_email(),
        password: "password456".to_string(),
        nickname: None,
    };

    let result = store.create_user(request2).await;
    assert!(result.is_err(), "重复用户名应该失败");
}

#[tokio::test]
async fn test_create_user_duplicate_email() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let email = unique_email();

    let request1 = CreateUserRequest {
        username: unique_username(),
        email: email.clone(),
        password: "password123".to_string(),
        nickname: None,
    };

    let _ = store.create_user(request1).await.unwrap();

    let request2 = CreateUserRequest {
        username: unique_username(),
        email: email.clone(),
        password: "password456".to_string(),
        nickname: None,
    };

    let result = store.create_user(request2).await;
    assert!(result.is_err(), "重复邮箱应该失败");
}

// ============================================================================
// 用户查询测试
// ============================================================================

#[tokio::test]
async fn test_find_by_id_exists() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let request = CreateUserRequest {
        username: unique_username(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: Some("Find Me".to_string()),
    };

    let created = store.create_user(request).await.unwrap();
    let found = store.find_by_id(&created.id).await.unwrap();

    assert!(found.is_some(), "应该找到用户");
    assert_eq!(found.unwrap().id, created.id);
}

#[tokio::test]
async fn test_find_by_id_not_exists() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let random_id = Uuid::new_v4();
    let found = store.find_by_id(&random_id).await.unwrap();

    assert!(found.is_none(), "不存在的用户应该返回 None");
}

#[tokio::test]
async fn test_find_by_username_exists() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let username = unique_username();
    let request = CreateUserRequest {
        username: username.clone(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: None,
    };

    let _ = store.create_user(request).await.unwrap();
    let found = store.find_by_username(&username).await.unwrap();

    assert!(found.is_some(), "应该找到用户");
    assert_eq!(found.unwrap().username, username);
}

#[tokio::test]
async fn test_find_by_id_deleted_user() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let request = CreateUserRequest {
        username: unique_username(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: None,
    };

    let created = store.create_user(request).await.unwrap();
    let deleted = store.delete_user(&created.id).await.unwrap();
    assert!(deleted, "删除应该成功");

    let found = store.find_by_id(&created.id).await.unwrap();
    assert!(found.is_none(), "已删除用户不应被查询到");
}

// ============================================================================
// 用户认证测试
// ============================================================================

#[tokio::test]
async fn test_authenticate_success() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let username = unique_username();
    let password = "correct_password123";

    let request = CreateUserRequest {
        username: username.clone(),
        email: unique_email(),
        password: password.to_string(),
        nickname: None,
    };

    let _ = store.create_user(request).await.unwrap();

    let login = LoginRequest {
        username: username.clone(),
        password: password.to_string(),
    };

    let result = store.authenticate(login).await.unwrap();
    assert!(result.is_some(), "正确密码应该认证成功");
    assert_eq!(result.unwrap().username, username);
}

#[tokio::test]
async fn test_authenticate_wrong_password() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let username = unique_username();

    let request = CreateUserRequest {
        username: username.clone(),
        email: unique_email(),
        password: "correct_password".to_string(),
        nickname: None,
    };

    let _ = store.create_user(request).await.unwrap();

    let login = LoginRequest {
        username: username.clone(),
        password: "wrong_password".to_string(),
    };

    let result = store.authenticate(login).await.unwrap();
    assert!(result.is_none(), "错误密码应该认证失败");
}

#[tokio::test]
async fn test_authenticate_user_not_found() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let login = LoginRequest {
        username: "nonexistent_user".to_string(),
        password: "any_password".to_string(),
    };

    let result = store.authenticate(login).await.unwrap();
    assert!(result.is_none(), "不存在的用户应该认证失败");
}

// ============================================================================
// 用户更新测试
// ============================================================================

#[tokio::test]
async fn test_update_user_nickname() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let request = CreateUserRequest {
        username: unique_username(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: Some("Old Name".to_string()),
    };

    let created = store.create_user(request).await.unwrap();

    let update = UpdateUserRequest {
        nickname: Some("New Name".to_string()),
        avatar_url: None,
        avatar_object_key: None,
        status: None,
    };

    let updated = store.update_user(&created.id, update).await.unwrap();
    assert!(updated.is_some(), "更新应该成功");
    assert_eq!(updated.unwrap().nickname, Some("New Name".to_string()));
}

#[tokio::test]
async fn test_update_user_avatar() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let request = CreateUserRequest {
        username: unique_username(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: None,
    };

    let created = store.create_user(request).await.unwrap();

    let update = UpdateUserRequest {
        nickname: None,
        avatar_url: Some("https://example.com/avatar.png".to_string()),
        avatar_object_key: Some("avatars/test.png".to_string()),
        status: None,
    };

    let updated = store.update_user(&created.id, update).await.unwrap();
    assert!(updated.is_some(), "更新应该成功");

    let user = updated.unwrap();
    assert_eq!(
        user.avatar_url,
        Some("https://example.com/avatar.png".to_string())
    );
    assert_eq!(
        user.avatar_object_key,
        Some("avatars/test.png".to_string())
    );
}

#[tokio::test]
async fn test_update_user_not_exists() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let random_id = Uuid::new_v4();
    let update = UpdateUserRequest {
        nickname: Some("New Name".to_string()),
        avatar_url: None,
        avatar_object_key: None,
        status: None,
    };

    let result = store.update_user(&random_id, update).await.unwrap();
    assert!(result.is_none(), "更新不存在的用户应该返回 None");
}

// ============================================================================
// 用户删除测试
// ============================================================================

#[tokio::test]
async fn test_delete_user_soft_delete() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let request = CreateUserRequest {
        username: unique_username(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: None,
    };

    let created = store.create_user(request).await.unwrap();
    let deleted = store.delete_user(&created.id).await.unwrap();

    assert!(deleted, "删除应该成功");

    let found = store.find_by_id_any_status(&created.id).await.unwrap();
    assert!(found.is_none(), "软删除后 find_by_id_any_status 也不应返回");
}

#[tokio::test]
async fn test_delete_user_not_exists() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let random_id = Uuid::new_v4();
    let deleted = store.delete_user(&random_id).await.unwrap();

    assert!(!deleted, "删除不存在的用户应该返回 false");
}

// ============================================================================
// 用户搜索测试
// ============================================================================

#[tokio::test]
async fn test_search_users_by_username() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let search_key = format!("searchable_{}", Uuid::new_v4().simple());
    let username = format!("{}_user", search_key);

    let request = CreateUserRequest {
        username: username.clone(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: None,
    };

    let created = store.create_user(request).await.unwrap();

    let other_user_id = Uuid::new_v4();
    let results = store
        .search_users(&search_key, 10, &other_user_id)
        .await
        .unwrap();

    assert!(!results.is_empty(), "应该找到用户");
    assert!(
        results.iter().any(|u| u.id == created.id),
        "搜索结果应该包含目标用户"
    );
}

#[tokio::test]
async fn test_search_users_excludes_self() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let search_key = format!("selftest_{}", Uuid::new_v4().simple());

    let request = CreateUserRequest {
        username: format!("{}_user", search_key),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: None,
    };

    let created = store.create_user(request).await.unwrap();

    let results = store
        .search_users(&search_key, 10, &created.id)
        .await
        .unwrap();

    assert!(
        !results.iter().any(|u| u.id == created.id),
        "搜索结果不应包含自己"
    );
}

// ============================================================================
// 用户存在性检查测试
// ============================================================================

#[tokio::test]
async fn test_username_exists_true() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let username = unique_username();
    let request = CreateUserRequest {
        username: username.clone(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: None,
    };

    let _ = store.create_user(request).await.unwrap();
    let exists = store.username_exists(&username).await.unwrap();

    assert!(exists, "已存在的用户名应该返回 true");
}

#[tokio::test]
async fn test_username_exists_false() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let exists = store
        .username_exists("nonexistent_user_xyz")
        .await
        .unwrap();

    assert!(!exists, "不存在的用户名应该返回 false");
}

#[tokio::test]
async fn test_email_exists_true() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let email = unique_email();
    let request = CreateUserRequest {
        username: unique_username(),
        email: email.clone(),
        password: "password123".to_string(),
        nickname: None,
    };

    let _ = store.create_user(request).await.unwrap();
    let exists = store.email_exists(&email).await.unwrap();

    assert!(exists, "已存在的邮箱应该返回 true");
}

// ============================================================================
// 批量查询测试
// ============================================================================

#[tokio::test]
async fn test_find_by_ids_multiple() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let mut ids = Vec::new();

    for i in 0..3 {
        let request = CreateUserRequest {
            username: format!("batch_user_{}_{}", i, Uuid::new_v4().simple()),
            email: unique_email(),
            password: "password123".to_string(),
            nickname: None,
        };

        let created = store.create_user(request).await.unwrap();
        ids.push(created.id);
    }

    let found = store.find_by_ids(&ids).await.unwrap();
    assert_eq!(found.len(), 3, "应该找到所有 3 个用户");
}

#[tokio::test]
async fn test_find_by_ids_empty() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let found = store.find_by_ids(&[]).await.unwrap();
    assert!(found.is_empty(), "空 ID 列表应该返回空结果");
}

#[tokio::test]
async fn test_find_by_ids_partial_exists() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let request = CreateUserRequest {
        username: unique_username(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: None,
    };

    let created = store.create_user(request).await.unwrap();

    let ids = vec![created.id, Uuid::new_v4(), Uuid::new_v4()];
    let found = store.find_by_ids(&ids).await.unwrap();

    assert_eq!(found.len(), 1, "只应找到存在的用户");
    assert_eq!(found[0].id, created.id);
}

// ============================================================================
// 密码更新测试
// ============================================================================

#[tokio::test]
async fn test_update_password_success() {
    let test_db = setup_test_db().await;
    let store = UserStore::new(test_db.database());

    let username = unique_username();
    let request = CreateUserRequest {
        username: username.clone(),
        email: unique_email(),
        password: "old_password".to_string(),
        nickname: None,
    };

    let created = store.create_user(request).await.unwrap();

    let new_hash =
        bcrypt::hash("new_password", bcrypt::DEFAULT_COST).expect("hash should succeed");
    let updated = store.update_password(&created.id, &new_hash).await.unwrap();

    assert!(updated, "密码更新应该成功");

    let login = LoginRequest {
        username: username.clone(),
        password: "new_password".to_string(),
    };

    let result = store.authenticate(login).await.unwrap();
    assert!(result.is_some(), "新密码应该能认证成功");
}
