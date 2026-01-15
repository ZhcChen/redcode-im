//! 数据库存储层集成测试
//!
//! 运行方式：
//! ```bash
//! # 确保数据库运行中
//! cargo test --test database_store_tests
//! ```

mod test_config;

use redcode_im_backend::database::friend_store::{FriendRequestDirection, FriendStore};
use redcode_im_backend::database::message_store::MessageStore;
use redcode_im_backend::database::models::{
    CreateUserRequest, FriendRequestStatus, LoginRequest, MessageType, RoomType, UpdateUserRequest,
    UserStatus,
};
use redcode_im_backend::database::room_store::RoomStore;
use redcode_im_backend::database::user_store::UserStore;
use redcode_im_backend::database::Database;
use sqlx::PgPool;
use test_config::{cleanup_test_db, setup_test_db};
use uuid::Uuid;

// ============================================================================
// UserStore 测试
// ============================================================================

mod user_store_tests {
    use super::*;

    fn unique_username() -> String {
        format!("testuser_{}", Uuid::new_v4().simple())
    }

    fn unique_email() -> String {
        format!("test_{}@example.com", Uuid::new_v4().simple())
    }

    // ------------------------------------------------------------------------
    // 用户创建测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_create_user_success() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

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

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_create_user_duplicate_username() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let username = unique_username();

        let request1 = CreateUserRequest {
            username: username.clone(),
            email: unique_email(),
            password: "password123".to_string(),
            nickname: None,
        };

        let _ = store.create_user(request1).await.unwrap();

        // 尝试创建同名用户
        let request2 = CreateUserRequest {
            username: username.clone(),
            email: unique_email(),
            password: "password456".to_string(),
            nickname: None,
        };

        let result = store.create_user(request2).await;
        assert!(result.is_err(), "重复用户名应该失败");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_create_user_duplicate_email() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let email = unique_email();

        let request1 = CreateUserRequest {
            username: unique_username(),
            email: email.clone(),
            password: "password123".to_string(),
            nickname: None,
        };

        let _ = store.create_user(request1).await.unwrap();

        // 尝试创建同邮箱用户
        let request2 = CreateUserRequest {
            username: unique_username(),
            email: email.clone(),
            password: "password456".to_string(),
            nickname: None,
        };

        let result = store.create_user(request2).await;
        assert!(result.is_err(), "重复邮箱应该失败");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 用户查询测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_find_by_id_exists() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

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

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_find_by_id_not_exists() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let random_id = Uuid::new_v4();
        let found = store.find_by_id(&random_id).await.unwrap();

        assert!(found.is_none(), "不存在的用户应该返回 None");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_find_by_username_exists() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

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

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_find_by_id_deleted_user() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let request = CreateUserRequest {
            username: unique_username(),
            email: unique_email(),
            password: "password123".to_string(),
            nickname: None,
        };

        let created = store.create_user(request).await.unwrap();

        // 删除用户
        let deleted = store.delete_user(&created.id).await.unwrap();
        assert!(deleted, "删除应该成功");

        // 查询已删除用户
        let found = store.find_by_id(&created.id).await.unwrap();
        assert!(found.is_none(), "已删除用户不应被查询到");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 用户认证测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_authenticate_success() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

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

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_authenticate_wrong_password() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

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

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_authenticate_user_not_found() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let login = LoginRequest {
            username: "nonexistent_user".to_string(),
            password: "any_password".to_string(),
        };

        let result = store.authenticate(login).await.unwrap();
        assert!(result.is_none(), "不存在的用户应该认证失败");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 用户更新测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_update_user_nickname() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

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

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_update_user_avatar() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

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

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_update_user_not_exists() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let random_id = Uuid::new_v4();
        let update = UpdateUserRequest {
            nickname: Some("New Name".to_string()),
            avatar_url: None,
            avatar_object_key: None,
            status: None,
        };

        let result = store.update_user(&random_id, update).await.unwrap();
        assert!(result.is_none(), "更新不存在的用户应该返回 None");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 用户删除测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_delete_user_soft_delete() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let request = CreateUserRequest {
            username: unique_username(),
            email: unique_email(),
            password: "password123".to_string(),
            nickname: None,
        };

        let created = store.create_user(request).await.unwrap();
        let deleted = store.delete_user(&created.id).await.unwrap();

        assert!(deleted, "删除应该成功");

        // 使用 any_status 查询确认是软删除
        let found = store.find_by_id_any_status(&created.id).await.unwrap();
        assert!(found.is_none(), "软删除后 find_by_id_any_status 也不应返回");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_delete_user_not_exists() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let random_id = Uuid::new_v4();
        let deleted = store.delete_user(&random_id).await.unwrap();

        assert!(!deleted, "删除不存在的用户应该返回 false");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 用户搜索测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_search_users_by_username() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

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

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_search_users_excludes_self() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let search_key = format!("selftest_{}", Uuid::new_v4().simple());

        let request = CreateUserRequest {
            username: format!("{}_user", search_key),
            email: unique_email(),
            password: "password123".to_string(),
            nickname: None,
        };

        let created = store.create_user(request).await.unwrap();

        // 搜索时排除自己
        let results = store
            .search_users(&search_key, 10, &created.id)
            .await
            .unwrap();

        assert!(
            !results.iter().any(|u| u.id == created.id),
            "搜索结果不应包含自己"
        );

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 用户存在性检查测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_username_exists_true() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

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

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_username_exists_false() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let exists = store
            .username_exists("nonexistent_user_xyz")
            .await
            .unwrap();

        assert!(!exists, "不存在的用户名应该返回 false");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_email_exists_true() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

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

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 批量查询测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_find_by_ids_multiple() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

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

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_find_by_ids_empty() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let found = store.find_by_ids(&[]).await.unwrap();
        assert!(found.is_empty(), "空 ID 列表应该返回空结果");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_find_by_ids_partial_exists() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

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

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 密码更新测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_update_password_success() {
        let test_db = setup_test_db().await;
        let store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let username = unique_username();
        let request = CreateUserRequest {
            username: username.clone(),
            email: unique_email(),
            password: "old_password".to_string(),
            nickname: None,
        };

        let created = store.create_user(request).await.unwrap();

        // 生成新密码哈希
        let new_hash =
            bcrypt::hash("new_password", bcrypt::DEFAULT_COST).expect("hash should succeed");
        let updated = store.update_password(&created.id, &new_hash).await.unwrap();

        assert!(updated, "密码更新应该成功");

        // 验证新密码能登录
        let login = LoginRequest {
            username: username.clone(),
            password: "new_password".to_string(),
        };

        let result = store.authenticate(login).await.unwrap();
        assert!(result.is_some(), "新密码应该能认证成功");

        cleanup_test_db(&test_db).await;
    }
}

// ============================================================================
// FriendStore 测试
// ============================================================================

mod friend_store_tests {
    use super::*;

    fn unique_username() -> String {
        format!("friend_test_{}", Uuid::new_v4().simple())
    }

    fn unique_email() -> String {
        format!("friend_{}@example.com", Uuid::new_v4().simple())
    }

    /// 创建测试用户的辅助函数
    async fn create_test_user(store: &UserStore) -> Uuid {
        let request = CreateUserRequest {
            username: unique_username(),
            email: unique_email(),
            password: "password123".to_string(),
            nickname: None,
        };
        store.create_user(request).await.unwrap().id
    }

    // ------------------------------------------------------------------------
    // 好友请求创建测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_create_request_success() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        let result = friend_store
            .create_request(user_a, user_b, Some("请求添加好友".to_string()))
            .await;

        assert!(result.is_ok(), "创建好友请求应该成功");

        let request = result.unwrap();
        assert_eq!(request.requester_id, user_a);
        assert_eq!(request.addressee_id, user_b);
        assert_eq!(request.status, FriendRequestStatus::Pending);
        assert_eq!(request.message, Some("请求添加好友".to_string()));

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_create_request_to_self() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_id = create_test_user(&user_store).await;

        let result = friend_store.create_request(user_id, user_id, None).await;

        assert!(result.is_err(), "不能向自己发送好友请求");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_create_request_pending_exists() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        // 第一次请求
        let _ = friend_store.create_request(user_a, user_b, None).await.unwrap();

        // 第二次请求应该失败
        let result = friend_store.create_request(user_a, user_b, None).await;
        assert!(result.is_err(), "已有待处理请求时应该失败");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 好友请求响应测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_respond_request_accept() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        let request = friend_store.create_request(user_a, user_b, None).await.unwrap();

        let result = friend_store
            .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
            .await;

        assert!(result.is_ok(), "接受好友请求应该成功");
        assert_eq!(result.unwrap().status, FriendRequestStatus::Accepted);

        // 验证好友关系已建立
        let friendships = friend_store.list_friendships(user_a).await.unwrap();
        assert!(!friendships.is_empty(), "应该建立好友关系");
        assert!(
            friendships.iter().any(|f| f.friend_user_id == user_b),
            "好友列表应该包含对方"
        );

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_respond_request_decline() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        let request = friend_store.create_request(user_a, user_b, None).await.unwrap();

        let result = friend_store
            .respond_request(request.id, user_b, FriendRequestStatus::Declined)
            .await;

        assert!(result.is_ok(), "拒绝好友请求应该成功");
        assert_eq!(result.unwrap().status, FriendRequestStatus::Declined);

        // 验证没有建立好友关系
        let friendships = friend_store.list_friendships(user_a).await.unwrap();
        assert!(
            !friendships.iter().any(|f| f.friend_user_id == user_b),
            "拒绝后不应建立好友关系"
        );

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_respond_request_not_addressee() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;
        let user_c = create_test_user(&user_store).await;

        let request = friend_store.create_request(user_a, user_b, None).await.unwrap();

        // user_c 无权处理
        let result = friend_store
            .respond_request(request.id, user_c, FriendRequestStatus::Accepted)
            .await;

        assert!(result.is_err(), "非接收者无权处理请求");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_respond_request_already_handled() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        let request = friend_store.create_request(user_a, user_b, None).await.unwrap();

        // 第一次处理
        let _ = friend_store
            .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
            .await
            .unwrap();

        // 再次处理应该失败
        let result = friend_store
            .respond_request(request.id, user_b, FriendRequestStatus::Declined)
            .await;

        assert!(result.is_err(), "已处理的请求不能再次处理");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 好友请求列表测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_list_requests_incoming() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        let _ = friend_store.create_request(user_a, user_b, None).await.unwrap();

        let incoming = friend_store
            .list_requests(user_b, Some(FriendRequestDirection::Incoming), None)
            .await
            .unwrap();

        assert!(!incoming.is_empty(), "应该有收到的请求");
        assert!(
            incoming.iter().any(|r| r.requester_id == user_a),
            "收到的请求应该来自 user_a"
        );

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_list_requests_outgoing() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        let _ = friend_store.create_request(user_a, user_b, None).await.unwrap();

        let outgoing = friend_store
            .list_requests(user_a, Some(FriendRequestDirection::Outgoing), None)
            .await
            .unwrap();

        assert!(!outgoing.is_empty(), "应该有发出的请求");
        assert!(
            outgoing.iter().any(|r| r.addressee_id == user_b),
            "发出的请求应该发给 user_b"
        );

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_list_requests_by_status() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        let _ = friend_store.create_request(user_a, user_b, None).await.unwrap();

        let pending = friend_store
            .list_requests(user_b, None, Some(FriendRequestStatus::Pending))
            .await
            .unwrap();

        assert!(!pending.is_empty(), "应该有待处理的请求");

        let accepted = friend_store
            .list_requests(user_b, None, Some(FriendRequestStatus::Accepted))
            .await
            .unwrap();

        // 新创建的请求不应该出现在 Accepted 列表中
        assert!(
            !accepted.iter().any(|r| r.requester_id == user_a && r.addressee_id == user_b),
            "新请求不应该在已接受列表中"
        );

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 好友关系测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_list_friendships() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        // 建立好友关系
        let request = friend_store.create_request(user_a, user_b, None).await.unwrap();
        let _ = friend_store
            .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
            .await
            .unwrap();

        // 双方都应该能看到好友
        let a_friends = friend_store.list_friendships(user_a).await.unwrap();
        let b_friends = friend_store.list_friendships(user_b).await.unwrap();

        assert!(
            a_friends.iter().any(|f| f.friend_user_id == user_b),
            "A 的好友列表应该包含 B"
        );
        assert!(
            b_friends.iter().any(|f| f.friend_user_id == user_a),
            "B 的好友列表应该包含 A"
        );

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_delete_friendship_success() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        // 建立好友关系
        let request = friend_store.create_request(user_a, user_b, None).await.unwrap();
        let _ = friend_store
            .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
            .await
            .unwrap();

        // 删除好友
        let deleted = friend_store.delete_friendship(user_a, user_b).await.unwrap();
        assert!(deleted, "删除好友应该成功");

        // 验证好友关系已删除
        let a_friends = friend_store.list_friendships(user_a).await.unwrap();
        assert!(
            !a_friends.iter().any(|f| f.friend_user_id == user_b),
            "删除后好友列表不应包含对方"
        );

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_delete_friendship_to_self() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_id = create_test_user(&user_store).await;

        let result = friend_store.delete_friendship(user_id, user_id).await;
        assert!(result.is_err(), "不能删除自己为好友");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_delete_friendship_not_friends() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        // 没有好友关系
        let deleted = friend_store.delete_friendship(user_a, user_b).await.unwrap();
        assert!(!deleted, "删除不存在的好友关系应该返回 false");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 好友备注测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_upsert_friend_remark_create() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        // 建立好友关系
        let request = friend_store.create_request(user_a, user_b, None).await.unwrap();
        let _ = friend_store
            .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
            .await
            .unwrap();

        // 设置备注
        let remark = friend_store
            .upsert_friend_remark(user_a, user_b, Some("我的好朋友".to_string()))
            .await
            .unwrap();

        assert_eq!(remark, Some("我的好朋友".to_string()));

        // 验证备注出现在好友列表
        let friends = friend_store.list_friendships(user_a).await.unwrap();
        let friend = friends.iter().find(|f| f.friend_user_id == user_b).unwrap();
        assert_eq!(friend.friend_remark, Some("我的好朋友".to_string()));

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_upsert_friend_remark_update() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        // 建立好友关系
        let request = friend_store.create_request(user_a, user_b, None).await.unwrap();
        let _ = friend_store
            .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
            .await
            .unwrap();

        // 设置初始备注
        let _ = friend_store
            .upsert_friend_remark(user_a, user_b, Some("初始备注".to_string()))
            .await
            .unwrap();

        // 更新备注
        let updated = friend_store
            .upsert_friend_remark(user_a, user_b, Some("更新后的备注".to_string()))
            .await
            .unwrap();

        assert_eq!(updated, Some("更新后的备注".to_string()));

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_upsert_friend_remark_clear() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        // 建立好友关系
        let request = friend_store.create_request(user_a, user_b, None).await.unwrap();
        let _ = friend_store
            .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
            .await
            .unwrap();

        // 设置备注
        let _ = friend_store
            .upsert_friend_remark(user_a, user_b, Some("备注".to_string()))
            .await
            .unwrap();

        // 清空备注
        let cleared = friend_store
            .upsert_friend_remark(user_a, user_b, Some("".to_string()))
            .await
            .unwrap();

        assert_eq!(cleared, None, "清空备注应该返回 None");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_upsert_friend_remark_not_friends() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;

        // 没有好友关系
        let result = friend_store
            .upsert_friend_remark(user_a, user_b, Some("备注".to_string()))
            .await;

        assert!(result.is_err(), "非好友无法设置备注");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 待处理请求计数测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_count_pending_incoming() {
        let test_db = setup_test_db().await;
        let user_store = UserStore::new(Database {
            pool: test_db.pool.clone(),
        });
        let friend_store = FriendStore::new(Database {
            pool: test_db.pool.clone(),
        });

        let user_a = create_test_user(&user_store).await;
        let user_b = create_test_user(&user_store).await;
        let user_c = create_test_user(&user_store).await;

        // 发送两个请求给 user_a
        let _ = friend_store.create_request(user_b, user_a, None).await.unwrap();
        let _ = friend_store.create_request(user_c, user_a, None).await.unwrap();

        let count = friend_store.count_pending_incoming(user_a).await.unwrap();
        assert!(count >= 2, "应该至少有 2 个待处理的收到请求");

        cleanup_test_db(&test_db).await;
    }
}

// ============================================================================
// RoomStore 测试
// ============================================================================

mod room_store_tests {
    use super::*;

    fn unique_username() -> String {
        format!("room_test_{}", Uuid::new_v4().simple())
    }

    fn unique_email() -> String {
        format!("room_{}@example.com", Uuid::new_v4().simple())
    }

    /// 创建测试用户的辅助函数
    async fn create_test_user(pool: &PgPool) -> Uuid {
        let store = UserStore::new(Database { pool: pool.clone() });
        let request = CreateUserRequest {
            username: unique_username(),
            email: unique_email(),
            password: "password123".to_string(),
            nickname: None,
        };
        store.create_user(request).await.unwrap().id
    }

    // ------------------------------------------------------------------------
    // 房间创建测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_create_room_group() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;

        let result = room_store
            .create_room(owner_id, "测试群组".to_string(), Some("描述".to_string()), Some(RoomType::Group))
            .await;

        assert!(result.is_ok(), "创建群组应该成功");

        let room = result.unwrap();
        assert_eq!(room.name, "测试群组");
        assert_eq!(room.description, Some("描述".to_string()));
        assert_eq!(room.room_type, RoomType::Group);
        assert_eq!(room.owner_id, owner_id);

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_create_room_with_members() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;
        let member1 = create_test_user(&test_db.pool).await;
        let member2 = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room_with_members(
                owner_id,
                "带成员群组".to_string(),
                None,
                Some(RoomType::Group),
                &[member1, member2],
            )
            .await
            .unwrap();

        // 验证成员已添加
        let member_ids = room_store.list_member_ids(room.id).await.unwrap();
        assert!(member_ids.contains(&owner_id), "群主应该在成员列表中");
        assert!(member_ids.contains(&member1), "成员1应该在列表中");
        assert!(member_ids.contains(&member2), "成员2应该在列表中");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_create_room_owner_auto_added() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room(owner_id, "自动添加群主".to_string(), None, None)
            .await
            .unwrap();

        let is_member = room_store.is_user_in_room(room.id, owner_id).await.unwrap();
        assert!(is_member, "创建者应该自动成为成员");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 私聊房间测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_ensure_private_room_create() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let user_a = create_test_user(&test_db.pool).await;
        let user_b = create_test_user(&test_db.pool).await;

        let room = room_store
            .ensure_private_room(user_a, user_b, "私聊".to_string())
            .await
            .unwrap();

        assert_eq!(room.room_type, RoomType::Private);
        assert!(room_store.is_user_in_room(room.id, user_a).await.unwrap());
        assert!(room_store.is_user_in_room(room.id, user_b).await.unwrap());

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_ensure_private_room_existing() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let user_a = create_test_user(&test_db.pool).await;
        let user_b = create_test_user(&test_db.pool).await;

        // 第一次创建
        let room1 = room_store
            .ensure_private_room(user_a, user_b, "私聊".to_string())
            .await
            .unwrap();

        // 第二次应该返回相同房间
        let room2 = room_store
            .ensure_private_room(user_a, user_b, "私聊".to_string())
            .await
            .unwrap();

        assert_eq!(room1.id, room2.id, "应该返回相同的房间");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_find_private_room_exists() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let user_a = create_test_user(&test_db.pool).await;
        let user_b = create_test_user(&test_db.pool).await;

        let created = room_store
            .ensure_private_room(user_a, user_b, "私聊".to_string())
            .await
            .unwrap();

        let found = room_store.find_private_room(user_a, user_b).await.unwrap();
        assert!(found.is_some(), "应该找到私聊房间");
        assert_eq!(found.unwrap().id, created.id);

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_find_private_room_not_exists() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let user_a = create_test_user(&test_db.pool).await;
        let user_b = create_test_user(&test_db.pool).await;

        let found = room_store.find_private_room(user_a, user_b).await.unwrap();
        assert!(found.is_none(), "不存在的私聊应该返回 None");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 成员管理测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_add_member_success() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;
        let new_member = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room(owner_id, "测试群".to_string(), None, None)
            .await
            .unwrap();

        let result = room_store.add_member(room.id, new_member, None).await;
        assert!(result.is_ok(), "添加成员应该成功");

        let is_member = room_store.is_user_in_room(room.id, new_member).await.unwrap();
        assert!(is_member, "新成员应该在房间中");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_remove_member_success() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;
        let member = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room_with_members(owner_id, "测试群".to_string(), None, None, &[member])
            .await
            .unwrap();

        let removed = room_store.remove_member(room.id, member).await.unwrap();
        assert!(removed, "移除成员应该成功");

        let is_member = room_store.is_user_in_room(room.id, member).await.unwrap();
        assert!(!is_member, "被移除的成员不应该在房间中");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_is_user_in_room_true() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room(owner_id, "测试群".to_string(), None, None)
            .await
            .unwrap();

        let is_member = room_store.is_user_in_room(room.id, owner_id).await.unwrap();
        assert!(is_member, "群主应该在房间中");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_is_user_in_room_false() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;
        let other_user = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room(owner_id, "测试群".to_string(), None, None)
            .await
            .unwrap();

        let is_member = room_store.is_user_in_room(room.id, other_user).await.unwrap();
        assert!(!is_member, "非成员不应该在房间中");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_list_member_ids() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;
        let member1 = create_test_user(&test_db.pool).await;
        let member2 = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room_with_members(owner_id, "测试群".to_string(), None, None, &[member1, member2])
            .await
            .unwrap();

        let member_ids = room_store.list_member_ids(room.id).await.unwrap();
        assert_eq!(member_ids.len(), 3, "应该有 3 个成员");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 房间查询测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_get_room_exists() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;

        let created = room_store
            .create_room(owner_id, "测试群".to_string(), None, None)
            .await
            .unwrap();

        let found = room_store.get_room(created.id).await;
        assert!(found.is_ok(), "应该找到房间");
        assert_eq!(found.unwrap().id, created.id);

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_list_user_rooms() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;

        // 创建多个房间
        let _ = room_store
            .create_room(owner_id, "群组1".to_string(), None, None)
            .await
            .unwrap();
        let _ = room_store
            .create_room(owner_id, "群组2".to_string(), None, None)
            .await
            .unwrap();

        let rooms = room_store.list_user_rooms(owner_id).await.unwrap();
        assert!(rooms.len() >= 2, "应该至少有 2 个房间");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 房间置顶测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_pin_room_for_user() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room(owner_id, "测试群".to_string(), None, None)
            .await
            .unwrap();

        let pin = room_store.pin_room_for_user(owner_id, room.id).await;
        assert!(pin.is_ok(), "置顶房间应该成功");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_unpin_room_for_user() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room(owner_id, "测试群".to_string(), None, None)
            .await
            .unwrap();

        let _ = room_store.pin_room_for_user(owner_id, room.id).await.unwrap();
        let unpinned = room_store.unpin_room_for_user(owner_id, room.id).await.unwrap();

        assert!(unpinned, "取消置顶应该成功");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 房间更新测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_update_room_name() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room(owner_id, "原名称".to_string(), None, None)
            .await
            .unwrap();

        let updated = room_store
            .update_room(room.id, Some("新名称".to_string()), None, None, None)
            .await
            .unwrap();

        assert_eq!(updated.name, "新名称");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_update_room_description() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room(owner_id, "测试群".to_string(), None, None)
            .await
            .unwrap();

        let updated = room_store
            .update_room(room.id, None, Some("新描述".to_string()), None, None)
            .await
            .unwrap();

        assert_eq!(updated.description, Some("新描述".to_string()));

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 房间删除/解散测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_dissolve_room_by_owner() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room(owner_id, "待解散群".to_string(), None, None)
            .await
            .unwrap();

        let dissolved = room_store.dissolve_room(room.id, owner_id).await.unwrap();
        assert!(dissolved, "群主解散群组应该成功");

        // 验证房间已删除
        let get_result = room_store.get_room(room.id).await;
        assert!(get_result.is_err(), "已解散的群组不应该能被获取");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_dissolve_room_not_owner() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;
        let member = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room_with_members(owner_id, "测试群".to_string(), None, None, &[member])
            .await
            .unwrap();

        let dissolved = room_store.dissolve_room(room.id, member).await.unwrap();
        assert!(!dissolved, "非群主不能解散群组");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_transfer_room_owner() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;
        let new_owner = create_test_user(&test_db.pool).await;

        let room = room_store
            .create_room_with_members(owner_id, "测试群".to_string(), None, None, &[new_owner])
            .await
            .unwrap();

        let updated = room_store
            .transfer_room_owner(room.id, owner_id, new_owner)
            .await
            .unwrap();

        assert_eq!(updated.owner_id, new_owner, "新群主应该更新");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 收藏夹测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_ensure_favorite_room_create() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let user_id = create_test_user(&test_db.pool).await;

        let room = room_store.ensure_favorite_room(user_id).await.unwrap();
        assert_eq!(room.room_type, RoomType::Favorite);
        assert_eq!(room.owner_id, user_id);

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_ensure_favorite_room_existing() {
        let test_db = setup_test_db().await;
        let room_store = RoomStore::new(&test_db.pool);

        let user_id = create_test_user(&test_db.pool).await;

        let room1 = room_store.ensure_favorite_room(user_id).await.unwrap();
        let room2 = room_store.ensure_favorite_room(user_id).await.unwrap();

        assert_eq!(room1.id, room2.id, "应该返回相同的收藏夹");

        cleanup_test_db(&test_db).await;
    }
}

// ============================================================================
// MessageStore 测试
// ============================================================================

mod message_store_tests {
    use super::*;

    fn unique_username() -> String {
        format!("msg_test_{}", Uuid::new_v4().simple())
    }

    fn unique_email() -> String {
        format!("msg_{}@example.com", Uuid::new_v4().simple())
    }

    /// 创建测试用户的辅助函数
    async fn create_test_user(pool: &PgPool) -> Uuid {
        let store = UserStore::new(Database { pool: pool.clone() });
        let request = CreateUserRequest {
            username: unique_username(),
            email: unique_email(),
            password: "password123".to_string(),
            nickname: None,
        };
        store.create_user(request).await.unwrap().id
    }

    /// 创建测试房间的辅助函数
    async fn create_test_room(pool: &PgPool, owner_id: Uuid) -> Uuid {
        let room_store = RoomStore::new(pool);
        room_store
            .create_room(owner_id, format!("测试群_{}", Uuid::new_v4().simple()), None, None)
            .await
            .unwrap()
            .id
    }

    // ------------------------------------------------------------------------
    // 消息创建测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_create_message_text() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let sender_id = create_test_user(&test_db.pool).await;
        let room_id = create_test_room(&test_db.pool, sender_id).await;

        let result = msg_store
            .create_message(
                room_id,
                sender_id,
                "Hello, World!".to_string(),
                MessageType::Text,
                None,
            )
            .await;

        assert!(result.is_ok(), "创建消息应该成功");

        let message = result.unwrap();
        assert_eq!(message.room_id, room_id);
        assert_eq!(message.sender_id, sender_id);
        assert_eq!(message.content, "Hello, World!");
        assert_eq!(message.message_type, MessageType::Text);

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_create_message_with_reply() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let sender_id = create_test_user(&test_db.pool).await;
        let room_id = create_test_room(&test_db.pool, sender_id).await;

        // 创建原始消息
        let original = msg_store
            .create_message(room_id, sender_id, "原始消息".to_string(), MessageType::Text, None)
            .await
            .unwrap();

        // 创建回复消息
        let reply = msg_store
            .create_message(
                room_id,
                sender_id,
                "这是回复".to_string(),
                MessageType::Text,
                Some(original.id),
            )
            .await
            .unwrap();

        assert_eq!(reply.quoted_message_id, Some(original.id), "应该引用原始消息");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 消息查询测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_get_room_messages() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let sender_id = create_test_user(&test_db.pool).await;
        let room_id = create_test_room(&test_db.pool, sender_id).await;

        // 创建多条消息
        for i in 0..5 {
            let _ = msg_store
                .create_message(
                    room_id,
                    sender_id,
                    format!("消息 {}", i),
                    MessageType::Text,
                    None,
                )
                .await
                .unwrap();
        }

        let messages = msg_store.get_room_messages(room_id, 10).await.unwrap();
        assert!(messages.len() >= 5, "应该至少有 5 条消息");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_get_message_exists() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let sender_id = create_test_user(&test_db.pool).await;
        let room_id = create_test_room(&test_db.pool, sender_id).await;

        let created = msg_store
            .create_message(room_id, sender_id, "测试消息".to_string(), MessageType::Text, None)
            .await
            .unwrap();

        let found = msg_store.get_message(created.id).await.unwrap();
        assert!(found.is_some(), "应该找到消息");
        assert_eq!(found.unwrap().id, created.id);

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_get_message_not_exists() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let random_id = Uuid::new_v4();
        let found = msg_store.get_message(random_id).await.unwrap();

        assert!(found.is_none(), "不存在的消息应该返回 None");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_get_message_with_sender() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let sender_id = create_test_user(&test_db.pool).await;
        let room_id = create_test_room(&test_db.pool, sender_id).await;

        let created = msg_store
            .create_message(room_id, sender_id, "测试消息".to_string(), MessageType::Text, None)
            .await
            .unwrap();

        let found = msg_store.get_message_with_sender(created.id).await.unwrap();
        assert!(found.is_some(), "应该找到消息");

        let msg = found.unwrap();
        assert_eq!(msg.sender_id, sender_id);
        assert!(!msg.sender_username.is_empty(), "应该包含发送者用户名");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 消息更新测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_update_message_content() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let sender_id = create_test_user(&test_db.pool).await;
        let room_id = create_test_room(&test_db.pool, sender_id).await;

        let created = msg_store
            .create_message(room_id, sender_id, "原始内容".to_string(), MessageType::Text, None)
            .await
            .unwrap();

        let updated = msg_store
            .update_message_content(created.id, "修改后的内容")
            .await
            .unwrap();

        assert!(updated.is_some(), "更新应该成功");
        let msg = updated.unwrap();
        assert_eq!(msg.content, "修改后的内容");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_mark_message_deleted() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let sender_id = create_test_user(&test_db.pool).await;
        let room_id = create_test_room(&test_db.pool, sender_id).await;

        let created = msg_store
            .create_message(room_id, sender_id, "待删除消息".to_string(), MessageType::Text, None)
            .await
            .unwrap();

        let deleted = msg_store.mark_message_deleted(created.id).await.unwrap();
        assert!(deleted.is_some(), "标记删除应该成功");

        // 验证消息 deleted_at 已设置
        let msg = deleted.unwrap();
        assert!(msg.deleted_at.is_some(), "deleted_at 应该被设置");

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 消息置顶测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_upsert_room_pin() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let sender_id = create_test_user(&test_db.pool).await;
        let room_id = create_test_room(&test_db.pool, sender_id).await;

        let message = msg_store
            .create_message(room_id, sender_id, "待置顶消息".to_string(), MessageType::Text, None)
            .await
            .unwrap();

        let pin = msg_store
            .upsert_room_pin(room_id, message.id, sender_id)
            .await
            .unwrap();

        assert_eq!(pin.room_id, room_id);
        assert_eq!(pin.message_id, message.id);

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_get_room_pins() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let sender_id = create_test_user(&test_db.pool).await;
        let room_id = create_test_room(&test_db.pool, sender_id).await;

        // 创建并置顶消息
        let message = msg_store
            .create_message(room_id, sender_id, "置顶消息".to_string(), MessageType::Text, None)
            .await
            .unwrap();

        let _ = msg_store
            .upsert_room_pin(room_id, message.id, sender_id)
            .await
            .unwrap();

        let pins = msg_store.get_room_pins(room_id).await.unwrap();
        assert!(!pins.is_empty(), "应该有置顶消息");
        assert!(pins.iter().any(|p| p.message_id == message.id), "应该包含置顶的消息");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_remove_room_pin() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let sender_id = create_test_user(&test_db.pool).await;
        let room_id = create_test_room(&test_db.pool, sender_id).await;

        let message = msg_store
            .create_message(room_id, sender_id, "置顶消息".to_string(), MessageType::Text, None)
            .await
            .unwrap();

        let _ = msg_store
            .upsert_room_pin(room_id, message.id, sender_id)
            .await
            .unwrap();

        let removed = msg_store.remove_room_pin(room_id, Some(message.id)).await.unwrap();
        assert!(removed > 0, "移除置顶应该成功");

        let pins = msg_store.get_room_pins(room_id).await.unwrap();
        assert!(
            !pins.iter().any(|p| p.message_id == message.id),
            "移除后不应该包含该消息"
        );

        cleanup_test_db(&test_db).await;
    }

    // ------------------------------------------------------------------------
    // 用户房间权限测试
    // ------------------------------------------------------------------------

    #[tokio::test]
    async fn test_user_in_room_true() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let sender_id = create_test_user(&test_db.pool).await;
        let room_id = create_test_room(&test_db.pool, sender_id).await;

        let is_member = msg_store.user_in_room(room_id, sender_id).await.unwrap();
        assert!(is_member, "房间创建者应该在房间中");

        cleanup_test_db(&test_db).await;
    }

    #[tokio::test]
    async fn test_user_in_room_false() {
        let test_db = setup_test_db().await;
        let msg_store = MessageStore::new(&test_db.pool);

        let owner_id = create_test_user(&test_db.pool).await;
        let other_user = create_test_user(&test_db.pool).await;
        let room_id = create_test_room(&test_db.pool, owner_id).await;

        let is_member = msg_store.user_in_room(room_id, other_user).await.unwrap();
        assert!(!is_member, "非成员不应该在房间中");

        cleanup_test_db(&test_db).await;
    }
}
