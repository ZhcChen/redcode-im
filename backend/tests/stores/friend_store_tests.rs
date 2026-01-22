//! FriendStore 测试
//!
//! 覆盖好友请求、好友关系、备注等功能。

use super::common::{setup_test_db, unique_email, unique_username};
use redcode_im_backend::database::friend_store::{FriendRequestDirection, FriendStore};
use redcode_im_backend::database::models::{CreateUserRequest, FriendRequestStatus};
use redcode_im_backend::database::user_store::UserStore;
use uuid::Uuid;

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

// ============================================================================
// 好友请求创建测试
// ============================================================================

#[tokio::test]
async fn test_create_request_success() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

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
}

#[tokio::test]
async fn test_create_request_to_self() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_id = create_test_user(&user_store).await;

    let result = friend_store.create_request(user_id, user_id, None).await;

    assert!(result.is_err(), "不能向自己发送好友请求");
}

#[tokio::test]
async fn test_create_request_pending_exists() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;

    let _ = friend_store.create_request(user_a, user_b, None).await.unwrap();

    let result = friend_store.create_request(user_a, user_b, None).await;
    assert!(result.is_err(), "已有待处理请求时应该失败");
}

// ============================================================================
// 好友请求响应测试
// ============================================================================

#[tokio::test]
async fn test_respond_request_accept() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;

    let request = friend_store.create_request(user_a, user_b, None).await.unwrap();

    let result = friend_store
        .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
        .await;

    assert!(result.is_ok(), "接受好友请求应该成功");
    assert_eq!(result.unwrap().status, FriendRequestStatus::Accepted);

    let friendships = friend_store.list_friendships(user_a).await.unwrap();
    assert!(!friendships.is_empty(), "应该建立好友关系");
    assert!(
        friendships.iter().any(|f| f.friend_user_id == user_b),
        "好友列表应该包含对方"
    );
}

#[tokio::test]
async fn test_respond_request_decline() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;

    let request = friend_store.create_request(user_a, user_b, None).await.unwrap();

    let result = friend_store
        .respond_request(request.id, user_b, FriendRequestStatus::Declined)
        .await;

    assert!(result.is_ok(), "拒绝好友请求应该成功");
    assert_eq!(result.unwrap().status, FriendRequestStatus::Declined);

    let friendships = friend_store.list_friendships(user_a).await.unwrap();
    assert!(
        !friendships.iter().any(|f| f.friend_user_id == user_b),
        "拒绝后不应建立好友关系"
    );
}

#[tokio::test]
async fn test_respond_request_not_addressee() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;
    let user_c = create_test_user(&user_store).await;

    let request = friend_store.create_request(user_a, user_b, None).await.unwrap();

    let result = friend_store
        .respond_request(request.id, user_c, FriendRequestStatus::Accepted)
        .await;

    assert!(result.is_err(), "非接收者无权处理请求");
}

#[tokio::test]
async fn test_respond_request_already_handled() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;

    let request = friend_store.create_request(user_a, user_b, None).await.unwrap();

    let _ = friend_store
        .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
        .await
        .unwrap();

    let result = friend_store
        .respond_request(request.id, user_b, FriendRequestStatus::Declined)
        .await;

    assert!(result.is_err(), "已处理的请求不能再次处理");
}

// ============================================================================
// 好友请求列表测试
// ============================================================================

#[tokio::test]
async fn test_list_requests_incoming() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

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
}

#[tokio::test]
async fn test_list_requests_outgoing() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

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
}

#[tokio::test]
async fn test_list_requests_by_status() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

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

    assert!(
        !accepted.iter().any(|r| r.requester_id == user_a && r.addressee_id == user_b),
        "新请求不应该在已接受列表中"
    );
}

// ============================================================================
// 好友关系测试
// ============================================================================

#[tokio::test]
async fn test_list_friendships() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;

    let request = friend_store.create_request(user_a, user_b, None).await.unwrap();
    let _ = friend_store
        .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
        .await
        .unwrap();

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
}

#[tokio::test]
async fn test_delete_friendship_success() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;

    let request = friend_store.create_request(user_a, user_b, None).await.unwrap();
    let _ = friend_store
        .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
        .await
        .unwrap();

    let deleted = friend_store.delete_friendship(user_a, user_b).await.unwrap();
    assert!(deleted, "删除好友应该成功");

    let a_friends = friend_store.list_friendships(user_a).await.unwrap();
    assert!(
        !a_friends.iter().any(|f| f.friend_user_id == user_b),
        "删除后好友列表不应包含对方"
    );
}

#[tokio::test]
async fn test_delete_friendship_to_self() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_id = create_test_user(&user_store).await;

    let result = friend_store.delete_friendship(user_id, user_id).await;
    assert!(result.is_err(), "不能删除自己为好友");
}

#[tokio::test]
async fn test_delete_friendship_not_friends() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;

    let deleted = friend_store.delete_friendship(user_a, user_b).await.unwrap();
    assert!(!deleted, "删除不存在的好友关系应该返回 false");
}

// ============================================================================
// 好友备注测试
// ============================================================================

#[tokio::test]
async fn test_upsert_friend_remark_create() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;

    let request = friend_store.create_request(user_a, user_b, None).await.unwrap();
    let _ = friend_store
        .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
        .await
        .unwrap();

    let remark = friend_store
        .upsert_friend_remark(user_a, user_b, Some("我的好朋友".to_string()))
        .await
        .unwrap();

    assert_eq!(remark, Some("我的好朋友".to_string()));

    let friends = friend_store.list_friendships(user_a).await.unwrap();
    let friend = friends.iter().find(|f| f.friend_user_id == user_b).unwrap();
    assert_eq!(friend.friend_remark, Some("我的好朋友".to_string()));
}

#[tokio::test]
async fn test_upsert_friend_remark_update() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;

    let request = friend_store.create_request(user_a, user_b, None).await.unwrap();
    let _ = friend_store
        .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
        .await
        .unwrap();

    let _ = friend_store
        .upsert_friend_remark(user_a, user_b, Some("初始备注".to_string()))
        .await
        .unwrap();

    let updated = friend_store
        .upsert_friend_remark(user_a, user_b, Some("更新后的备注".to_string()))
        .await
        .unwrap();

    assert_eq!(updated, Some("更新后的备注".to_string()));
}

#[tokio::test]
async fn test_upsert_friend_remark_clear() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;

    let request = friend_store.create_request(user_a, user_b, None).await.unwrap();
    let _ = friend_store
        .respond_request(request.id, user_b, FriendRequestStatus::Accepted)
        .await
        .unwrap();

    let _ = friend_store
        .upsert_friend_remark(user_a, user_b, Some("备注".to_string()))
        .await
        .unwrap();

    let cleared = friend_store
        .upsert_friend_remark(user_a, user_b, Some("".to_string()))
        .await
        .unwrap();

    assert_eq!(cleared, None, "清空备注应该返回 None");
}

#[tokio::test]
async fn test_upsert_friend_remark_not_friends() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;

    let result = friend_store
        .upsert_friend_remark(user_a, user_b, Some("备注".to_string()))
        .await;

    assert!(result.is_err(), "非好友无法设置备注");
}

// ============================================================================
// 待处理请求计数测试
// ============================================================================

#[tokio::test]
async fn test_count_pending_incoming() {
    let test_db = setup_test_db().await;
    let user_store = UserStore::new(test_db.database());
    let friend_store = FriendStore::new(test_db.database());

    let user_a = create_test_user(&user_store).await;
    let user_b = create_test_user(&user_store).await;
    let user_c = create_test_user(&user_store).await;

    let _ = friend_store.create_request(user_b, user_a, None).await.unwrap();
    let _ = friend_store.create_request(user_c, user_a, None).await.unwrap();

    let count = friend_store.count_pending_incoming(user_a).await.unwrap();
    assert!(count >= 2, "应该至少有 2 个待处理的收到请求");
}
