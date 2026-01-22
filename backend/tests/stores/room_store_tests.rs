//! RoomStore 测试
//!
//! 覆盖房间创建、成员管理、私聊、群组等功能。

use super::common::{setup_test_db, unique_email, unique_username};
use redcode_im_backend::database::models::{CreateUserRequest, RoomType};
use redcode_im_backend::database::room_store::RoomStore;
use redcode_im_backend::database::user_store::UserStore;
use sqlx::PgPool;
use uuid::Uuid;

/// 创建测试用户的辅助函数
async fn create_test_user(pool: &PgPool) -> Uuid {
    let store = UserStore::new(redcode_im_backend::database::Database { pool: pool.clone() });
    let request = CreateUserRequest {
        username: unique_username(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: None,
    };
    store.create_user(request).await.unwrap().id
}

// ============================================================================
// 房间创建测试
// ============================================================================

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

    let member_ids = room_store.list_member_ids(room.id).await.unwrap();
    assert!(member_ids.contains(&owner_id), "群主应该在成员列表中");
    assert!(member_ids.contains(&member1), "成员1应该在列表中");
    assert!(member_ids.contains(&member2), "成员2应该在列表中");
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
}

// ============================================================================
// 私聊房间测试
// ============================================================================

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
}

#[tokio::test]
async fn test_ensure_private_room_existing() {
    let test_db = setup_test_db().await;
    let room_store = RoomStore::new(&test_db.pool);

    let user_a = create_test_user(&test_db.pool).await;
    let user_b = create_test_user(&test_db.pool).await;

    let room1 = room_store
        .ensure_private_room(user_a, user_b, "私聊".to_string())
        .await
        .unwrap();

    let room2 = room_store
        .ensure_private_room(user_a, user_b, "私聊".to_string())
        .await
        .unwrap();

    assert_eq!(room1.id, room2.id, "应该返回相同的房间");
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
}

#[tokio::test]
async fn test_find_private_room_not_exists() {
    let test_db = setup_test_db().await;
    let room_store = RoomStore::new(&test_db.pool);

    let user_a = create_test_user(&test_db.pool).await;
    let user_b = create_test_user(&test_db.pool).await;

    let found = room_store.find_private_room(user_a, user_b).await.unwrap();
    assert!(found.is_none(), "不存在的私聊应该返回 None");
}

// ============================================================================
// 成员管理测试
// ============================================================================

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
}

// ============================================================================
// 房间查询测试
// ============================================================================

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
}

#[tokio::test]
async fn test_list_user_rooms() {
    let test_db = setup_test_db().await;
    let room_store = RoomStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;

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
}

// ============================================================================
// 房间置顶测试
// ============================================================================

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
}

// ============================================================================
// 房间更新测试
// ============================================================================

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
}

// ============================================================================
// 房间删除/解散测试
// ============================================================================

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

    let get_result = room_store.get_room(room.id).await;
    assert!(get_result.is_err(), "已解散的群组不应该能被获取");
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
}

// ============================================================================
// 收藏夹测试
// ============================================================================

#[tokio::test]
async fn test_ensure_favorite_room_create() {
    let test_db = setup_test_db().await;
    let room_store = RoomStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;

    let room = room_store.ensure_favorite_room(user_id).await.unwrap();
    assert_eq!(room.room_type, RoomType::Favorite);
    assert_eq!(room.owner_id, user_id);
}

#[tokio::test]
async fn test_ensure_favorite_room_existing() {
    let test_db = setup_test_db().await;
    let room_store = RoomStore::new(&test_db.pool);

    let user_id = create_test_user(&test_db.pool).await;

    let room1 = room_store.ensure_favorite_room(user_id).await.unwrap();
    let room2 = room_store.ensure_favorite_room(user_id).await.unwrap();

    assert_eq!(room1.id, room2.id, "应该返回相同的收藏夹");
}
