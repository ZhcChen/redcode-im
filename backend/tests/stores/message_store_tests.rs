//! MessageStore 测试
//!
//! 覆盖消息创建、查询、更新、置顶等功能。

use super::common::{setup_test_db, unique_email, unique_username};
use redcode_im_backend::database::message_store::MessageStore;
use redcode_im_backend::database::models::{CreateUserRequest, MessageType};
use redcode_im_backend::database::room_store::RoomStore;
use redcode_im_backend::database::user_store::UserStore;
use redcode_im_backend::database::Database;
use sqlx::PgPool;
use uuid::Uuid;

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

// ============================================================================
// 消息创建测试
// ============================================================================

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
}

#[tokio::test]
async fn test_create_message_with_reply() {
    let test_db = setup_test_db().await;
    let msg_store = MessageStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, sender_id).await;

    let original = msg_store
        .create_message(room_id, sender_id, "原始消息".to_string(), MessageType::Text, None)
        .await
        .unwrap();

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
}

// ============================================================================
// 消息查询测试
// ============================================================================

#[tokio::test]
async fn test_get_room_messages() {
    let test_db = setup_test_db().await;
    let msg_store = MessageStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, sender_id).await;

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
}

#[tokio::test]
async fn test_get_message_not_exists() {
    let test_db = setup_test_db().await;
    let msg_store = MessageStore::new(&test_db.pool);

    let random_id = Uuid::new_v4();
    let found = msg_store.get_message(random_id).await.unwrap();

    assert!(found.is_none(), "不存在的消息应该返回 None");
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
}

// ============================================================================
// 消息更新测试
// ============================================================================

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

    let msg = deleted.unwrap();
    assert!(msg.deleted_at.is_some(), "deleted_at 应该被设置");
}

// ============================================================================
// 消息置顶测试
// ============================================================================

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
}

#[tokio::test]
async fn test_get_room_pins() {
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

    let pins = msg_store.get_room_pins(room_id).await.unwrap();
    assert!(!pins.is_empty(), "应该有置顶消息");
    assert!(pins.iter().any(|p| p.message_id == message.id), "应该包含置顶的消息");
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
}

// ============================================================================
// 用户房间权限测试
// ============================================================================

#[tokio::test]
async fn test_user_in_room_true() {
    let test_db = setup_test_db().await;
    let msg_store = MessageStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, sender_id).await;

    let is_member = msg_store.user_in_room(room_id, sender_id).await.unwrap();
    assert!(is_member, "房间创建者应该在房间中");
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
}
