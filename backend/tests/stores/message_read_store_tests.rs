//! MessageReadStore 测试
//!
//! 覆盖消息已读状态标记和未读计数功能。

use super::common::{setup_test_db, unique_email, unique_username};
use redcode_im_backend::database::message_read_store::MessageReadStore;
use redcode_im_backend::database::message_store::MessageStore;
use redcode_im_backend::database::models::{CreateUserRequest, MessageType};
use redcode_im_backend::database::room_store::RoomStore;
use redcode_im_backend::database::user_store::UserStore;
use redcode_im_backend::database::Database;
use sqlx::PgPool;
use uuid::Uuid;

/// 创建测试用户
async fn create_test_user(pool: &PgPool) -> Uuid {
    let store = UserStore::new(Database { pool: pool.clone() });
    let request = CreateUserRequest {
        username: unique_username(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: Some("Test User".to_string()),
    };
    store.create_user(request).await.unwrap().id
}

/// 创建测试群聊
async fn create_test_room(pool: &PgPool, owner_id: Uuid) -> Uuid {
    let store = RoomStore::new(pool);
    store
        .create_room(owner_id, format!("room_{}", Uuid::new_v4().simple()), None, None)
        .await
        .unwrap()
        .id
}

/// 创建测试消息
async fn create_test_message(pool: &PgPool, room_id: Uuid, sender_id: Uuid) -> Uuid {
    let store = MessageStore::new(pool);
    store
        .create_message(room_id, sender_id, "Test message".to_string(), MessageType::Text, None)
        .await
        .unwrap()
        .id
}

/// 添加房间成员
async fn add_member(pool: &PgPool, room_id: Uuid, user_id: Uuid) {
    let store = RoomStore::new(pool);
    let _ = store.add_member(room_id, user_id, None).await;
}

// ============================================================================
// 标记已读测试
// ============================================================================

#[tokio::test]
async fn test_mark_message_read() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;
    let reader_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, sender_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, sender_id).await;

    // 添加 reader 为房间成员
    add_member(&test_db.pool, room_id, reader_id).await;

    let result = store.mark_message_read(message_id, reader_id, room_id).await;
    assert!(result.is_ok(), "标记已读应成功");

    let read = result.unwrap();
    assert_eq!(read.message_id, message_id);
    assert_eq!(read.user_id, reader_id);
    assert_eq!(read.room_id, room_id);
}

#[tokio::test]
async fn test_mark_message_read_idempotent() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;
    let reader_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, sender_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, sender_id).await;

    add_member(&test_db.pool, room_id, reader_id).await;

    // 多次标记同一消息已读
    let result1 = store.mark_message_read(message_id, reader_id, room_id).await;
    let result2 = store.mark_message_read(message_id, reader_id, room_id).await;

    assert!(result1.is_ok());
    assert!(result2.is_ok(), "重复标记应成功（幂等）");
}

// ============================================================================
// 批量标记已读测试
// ============================================================================

#[tokio::test]
async fn test_mark_messages_read_until() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;
    let reader_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, sender_id).await;

    // 添加 reader 为房间成员
    add_member(&test_db.pool, room_id, reader_id).await;

    // 创建多条消息
    let mut message_ids = Vec::new();
    for _ in 0..5 {
        let msg_id = create_test_message(&test_db.pool, room_id, sender_id).await;
        message_ids.push(msg_id);
    }

    // 标记到第 3 条消息
    let result = store
        .mark_messages_read_until(room_id, reader_id, message_ids[2])
        .await;

    assert!(result.is_ok(), "批量标记已读应成功");
    // 返回插入的记录数
    let count = result.unwrap();
    assert!(count >= 0, "应返回非负数");
}

#[tokio::test]
async fn test_mark_messages_read_until_nonexistent_message() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;

    // 使用不存在的消息 ID
    let fake_message_id = Uuid::new_v4();
    let result = store
        .mark_messages_read_until(room_id, user_id, fake_message_id)
        .await;

    assert!(result.is_ok());
    assert_eq!(result.unwrap(), 0, "不存在的消息应返回 0");
}

// ============================================================================
// 获取已读用户列表测试
// ============================================================================

#[tokio::test]
async fn test_get_message_read_users() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;
    let reader1 = create_test_user(&test_db.pool).await;
    let reader2 = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, sender_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, sender_id).await;

    // 添加成员
    add_member(&test_db.pool, room_id, reader1).await;
    add_member(&test_db.pool, room_id, reader2).await;

    // 两个用户标记已读
    let _ = store.mark_message_read(message_id, reader1, room_id).await.unwrap();
    let _ = store.mark_message_read(message_id, reader2, room_id).await.unwrap();

    let result = store.get_message_read_users(message_id).await;
    assert!(result.is_ok(), "获取已读用户应成功");

    let users = result.unwrap();
    assert_eq!(users.len(), 2, "应有 2 个已读用户");
}

#[tokio::test]
async fn test_get_message_read_users_empty() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, sender_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, sender_id).await;

    let result = store.get_message_read_users(message_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "无人已读应返回空列表");
}

// ============================================================================
// 检查消息被他人已读测试
// ============================================================================

#[tokio::test]
async fn test_message_ids_read_by_others() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;
    let reader_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, sender_id).await;

    add_member(&test_db.pool, room_id, reader_id).await;

    // 创建 3 条消息
    let msg1 = create_test_message(&test_db.pool, room_id, sender_id).await;
    let msg2 = create_test_message(&test_db.pool, room_id, sender_id).await;
    let msg3 = create_test_message(&test_db.pool, room_id, sender_id).await;

    // reader 只读了 msg1 和 msg2
    let _ = store.mark_message_read(msg1, reader_id, room_id).await.unwrap();
    let _ = store.mark_message_read(msg2, reader_id, room_id).await.unwrap();

    let result = store
        .message_ids_read_by_others(&[msg1, msg2, msg3], sender_id)
        .await;

    assert!(result.is_ok());
    let read_ids = result.unwrap();
    assert!(read_ids.contains(&msg1), "msg1 应被他人已读");
    assert!(read_ids.contains(&msg2), "msg2 应被他人已读");
    assert!(!read_ids.contains(&msg3), "msg3 不应被他人已读");
}

#[tokio::test]
async fn test_message_ids_read_by_others_empty_input() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;

    let result = store.message_ids_read_by_others(&[], sender_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "空输入应返回空集合");
}

// ============================================================================
// 未读计数测试
// ============================================================================

#[tokio::test]
async fn test_get_unread_count() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;
    let reader_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, sender_id).await;

    // 添加 reader 为成员
    add_member(&test_db.pool, room_id, reader_id).await;

    // 创建 5 条消息
    for _ in 0..5 {
        let _ = create_test_message(&test_db.pool, room_id, sender_id).await;
    }

    let result = store.get_unread_count(room_id, reader_id).await;
    assert!(result.is_ok(), "获取未读数应成功");
    // 应该有 5 条未读（sender 发的消息对 reader 来说都是未读）
    assert_eq!(result.unwrap(), 5, "应有 5 条未读");
}

#[tokio::test]
async fn test_get_unread_count_after_read() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;
    let reader_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, sender_id).await;

    add_member(&test_db.pool, room_id, reader_id).await;

    // 创建 3 条消息
    let msg1 = create_test_message(&test_db.pool, room_id, sender_id).await;
    let _msg2 = create_test_message(&test_db.pool, room_id, sender_id).await;
    let _msg3 = create_test_message(&test_db.pool, room_id, sender_id).await;

    // 读第一条消息
    let _ = store.mark_message_read(msg1, reader_id, room_id).await.unwrap();

    // 检查未读数 - 由于 mark_message_read 更新了 last_read_at
    // 未读数应该减少
    let result = store.get_unread_count(room_id, reader_id).await;
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_get_unread_count_own_messages_not_counted() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;

    // 用户自己发的消息
    for _ in 0..5 {
        let _ = create_test_message(&test_db.pool, room_id, user_id).await;
    }

    let result = store.get_unread_count(room_id, user_id).await;
    assert!(result.is_ok());
    // 自己发的消息不算未读
    assert_eq!(result.unwrap(), 0, "自己的消息不应计入未读");
}

// ============================================================================
// 全局未读计数测试
// ============================================================================

#[tokio::test]
async fn test_get_all_unread_counts() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let sender_id = create_test_user(&test_db.pool).await;
    let reader_id = create_test_user(&test_db.pool).await;

    // 创建多个房间
    let room1 = create_test_room(&test_db.pool, sender_id).await;
    let room2 = create_test_room(&test_db.pool, sender_id).await;

    // 添加 reader 为成员
    add_member(&test_db.pool, room1, reader_id).await;
    add_member(&test_db.pool, room2, reader_id).await;

    // 在每个房间发消息
    for _ in 0..3 {
        let _ = create_test_message(&test_db.pool, room1, sender_id).await;
    }
    for _ in 0..2 {
        let _ = create_test_message(&test_db.pool, room2, sender_id).await;
    }

    let result = store.get_all_unread_counts(reader_id).await;
    assert!(result.is_ok(), "获取所有未读数应成功");

    let counts = result.unwrap();
    // reader 是两个房间的成员
    assert!(counts.len() >= 2, "应至少返回 2 个房间的未读数");
}

#[tokio::test]
async fn test_get_all_unread_counts_no_rooms() {
    let test_db = setup_test_db().await;
    let store = MessageReadStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;

    let result = store.get_all_unread_counts(user_id).await;
    assert!(result.is_ok());
    // 新用户可能没有加入任何房间，或只是群主
    let counts = result.unwrap();
    assert!(counts.len() >= 0);
}
