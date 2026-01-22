//! MessageReactionStore 测试
//!
//! 覆盖消息反应（表情）的增删查功能。

use super::common::{setup_test_db, unique_email, unique_username};
use redcode_im_backend::database::message_reaction_store::MessageReactionStore;
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

// ============================================================================
// 添加反应测试
// ============================================================================

#[tokio::test]
async fn test_add_reaction() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, user_id).await;

    let result = store.add_reaction(message_id, user_id, "👍").await;
    assert!(result.is_ok(), "添加反应应成功");

    let reaction = result.unwrap();
    assert_eq!(reaction.message_id, message_id);
    assert_eq!(reaction.user_id, user_id);
    assert_eq!(reaction.reaction_key, "👍");
    assert!(reaction.deleted_at.is_none());
}

#[tokio::test]
async fn test_add_reaction_idempotent() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, user_id).await;

    // 添加两次相同的反应
    let result1 = store.add_reaction(message_id, user_id, "❤️").await.unwrap();
    let result2 = store.add_reaction(message_id, user_id, "❤️").await.unwrap();

    // 应该返回相同的反应（幂等）
    assert_eq!(result1.id, result2.id, "重复添加应返回同一记录");
}

#[tokio::test]
async fn test_add_multiple_reactions() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, user_id).await;

    // 添加多个不同的反应
    let _ = store.add_reaction(message_id, user_id, "👍").await.unwrap();
    let _ = store.add_reaction(message_id, user_id, "❤️").await.unwrap();
    let _ = store.add_reaction(message_id, user_id, "😄").await.unwrap();

    let reactions = store.get_user_reactions(message_id, user_id).await.unwrap();
    assert_eq!(reactions.len(), 3, "应有 3 个反应");
}

// ============================================================================
// 删除反应测试
// ============================================================================

#[tokio::test]
async fn test_remove_reaction() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, user_id).await;

    // 先添加反应
    let _ = store.add_reaction(message_id, user_id, "👍").await.unwrap();

    // 删除反应
    let result = store.remove_reaction(message_id, user_id, "👍").await;
    assert!(result.is_ok());
    assert!(result.unwrap(), "删除应成功");

    // 确认已删除
    let has = store.has_reaction(message_id, user_id, "👍").await.unwrap();
    assert!(!has, "反应应已删除");
}

#[tokio::test]
async fn test_remove_reaction_not_exists() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, user_id).await;

    // 删除不存在的反应
    let result = store.remove_reaction(message_id, user_id, "👎").await;
    assert!(result.is_ok());
    assert!(!result.unwrap(), "删除不存在的反应应返回 false");
}

#[tokio::test]
async fn test_add_after_remove() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, user_id).await;

    // 添加 -> 删除 -> 再添加
    let _ = store.add_reaction(message_id, user_id, "👍").await.unwrap();
    let _ = store.remove_reaction(message_id, user_id, "👍").await.unwrap();
    let result = store.add_reaction(message_id, user_id, "👍").await;

    assert!(result.is_ok(), "删除后重新添加应成功");
    let reaction = result.unwrap();
    assert!(reaction.deleted_at.is_none(), "应该是活跃状态");
}

// ============================================================================
// 查询反应测试
// ============================================================================

#[tokio::test]
async fn test_has_reaction_true() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, user_id).await;

    let _ = store.add_reaction(message_id, user_id, "❤️").await.unwrap();

    let result = store.has_reaction(message_id, user_id, "❤️").await;
    assert!(result.is_ok());
    assert!(result.unwrap(), "应该有该反应");
}

#[tokio::test]
async fn test_has_reaction_false() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, user_id).await;

    let result = store.has_reaction(message_id, user_id, "🔥").await;
    assert!(result.is_ok());
    assert!(!result.unwrap(), "不应该有该反应");
}

#[tokio::test]
async fn test_get_user_reactions() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, user_id).await;

    let _ = store.add_reaction(message_id, user_id, "👍").await.unwrap();
    let _ = store.add_reaction(message_id, user_id, "😄").await.unwrap();

    let result = store.get_user_reactions(message_id, user_id).await;
    assert!(result.is_ok());

    let reactions = result.unwrap();
    assert_eq!(reactions.len(), 2, "应有 2 个反应");
    assert!(reactions.contains(&"👍".to_string()));
    assert!(reactions.contains(&"😄".to_string()));
}

#[tokio::test]
async fn test_get_user_reactions_empty() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, user_id).await;

    let result = store.get_user_reactions(message_id, user_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "应该没有反应");
}

// ============================================================================
// 反应汇总测试
// ============================================================================

#[tokio::test]
async fn test_get_reaction_summaries() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user1 = create_test_user(&test_db.pool).await;
    let user2 = create_test_user(&test_db.pool).await;
    let user3 = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user1).await;
    let message_id = create_test_message(&test_db.pool, room_id, user1).await;

    // 多个用户添加反应
    let _ = store.add_reaction(message_id, user1, "👍").await.unwrap();
    let _ = store.add_reaction(message_id, user2, "👍").await.unwrap();
    let _ = store.add_reaction(message_id, user3, "👍").await.unwrap();
    let _ = store.add_reaction(message_id, user1, "❤️").await.unwrap();

    let result = store.get_reaction_summaries(message_id, Some(user1)).await;
    assert!(result.is_ok(), "获取汇总应成功");

    let summaries = result.unwrap();
    assert!(!summaries.is_empty(), "应有反应汇总");

    // 找到 👍 的汇总
    let thumbs_up = summaries.iter().find(|s| s.reaction_key == "👍");
    assert!(thumbs_up.is_some(), "应有 👍 汇总");

    let summary = thumbs_up.unwrap();
    assert_eq!(summary.count, 3, "👍 应有 3 个");
    assert_eq!(summary.user_ids.len(), 3, "应有 3 个用户");
    assert!(summary.has_self, "当前用户应有该反应");
}

#[tokio::test]
async fn test_get_reaction_summaries_empty() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user_id).await;
    let message_id = create_test_message(&test_db.pool, room_id, user_id).await;

    let result = store.get_reaction_summaries(message_id, None).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "无反应应返回空汇总");
}

#[tokio::test]
async fn test_get_reaction_summaries_has_self_false() {
    let test_db = setup_test_db().await;
    let store = MessageReactionStore::new(&test_db.pool);

    let user1 = create_test_user(&test_db.pool).await;
    let user2 = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, user1).await;
    let message_id = create_test_message(&test_db.pool, room_id, user1).await;

    // 只有 user1 添加反应
    let _ = store.add_reaction(message_id, user1, "👍").await.unwrap();

    // user2 查询汇总
    let result = store.get_reaction_summaries(message_id, Some(user2)).await;
    assert!(result.is_ok());

    let summaries = result.unwrap();
    let summary = summaries.iter().find(|s| s.reaction_key == "👍").unwrap();
    assert!(!summary.has_self, "user2 不应有该反应");
}
