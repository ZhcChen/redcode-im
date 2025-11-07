use redcode_im_backend::database::models::*;
use uuid::Uuid;
use chrono::Utc;

#[test]
fn test_user_model_serialization() {
    let user = User {
        id: Uuid::new_v4(),
        username: "testuser".to_string(),
        email: "test@example.com".to_string(),
        password_hash: "hashed_password".to_string(),
        nickname: Some("Test User".to_string()),
        avatar_url: Some("https://example.com/avatar.jpg".to_string()),
        avatar_object_key: Some("avatars/testuser.jpg".to_string()),
        status: UserStatus::Active,
        created_at: Utc::now(),
        updated_at: Utc::now(),
        deleted_at: None,
    };

    let serialized = serde_json::to_string(&user).unwrap();
    let deserialized: User = serde_json::from_str(&serialized).unwrap();

    assert_eq!(user.id, deserialized.id);
    assert_eq!(user.username, deserialized.username);
    assert_eq!(user.email, deserialized.email);
    assert_eq!(user.nickname, deserialized.nickname);
    assert_eq!(user.status, deserialized.status);
}

#[test]
fn test_room_model_serialization() {
    let room = Room {
        id: Uuid::new_v4(),
        name: "Test Room".to_string(),
        description: Some("A test room".to_string()),
        avatar_url: Some("https://example.com/room.jpg".to_string()),
        room_type: RoomType::Group,
        owner_id: Uuid::new_v4(),
        created_at: Utc::now(),
        updated_at: Utc::now(),
        deleted_at: None,
    };

    let serialized = serde_json::to_string(&room).unwrap();
    let deserialized: Room = serde_json::from_str(&serialized).unwrap();

    assert_eq!(room.id, deserialized.id);
    assert_eq!(room.name, deserialized.name);
    assert_eq!(room.room_type, deserialized.room_type);
    assert_eq!(room.owner_id, deserialized.owner_id);
}

#[test]
fn test_message_model_serialization() {
    let message = Message {
        id: Uuid::new_v4(),
        room_id: Uuid::new_v4(),
        sender_id: Uuid::new_v4(),
        content: "Test message".to_string(),
        message_type: MessageType::Text,
        extra: Some(serde_json::json!({"key": "value"})),
        created_at: Utc::now(),
        updated_at: Utc::now(),
        deleted_at: None,
    };

    let serialized = serde_json::to_string(&message).unwrap();
    let deserialized: Message = serde_json::from_str(&serialized).unwrap();

    assert_eq!(message.id, deserialized.id);
    assert_eq!(message.content, deserialized.content);
    assert_eq!(message.message_type, deserialized.message_type);
}

#[test]
fn test_room_member_serialization() {
    let member = RoomMember {
        id: Uuid::new_v4(),
        room_id: Uuid::new_v4(),
        user_id: Uuid::new_v4(),
        role: MemberRole::Member,
        joined_at: Utc::now(),
        deleted_at: None,
        last_read_at: Some(Utc::now()),
        last_read_message_id: Some(Uuid::new_v4()),
    };

    let serialized = serde_json::to_string(&member).unwrap();
    let deserialized: RoomMember = serde_json::from_str(&serialized).unwrap();

    assert_eq!(member.room_id, deserialized.room_id);
    assert_eq!(member.user_id, deserialized.user_id);
    assert_eq!(member.role, deserialized.role);
}

#[test]
fn test_group_settings_serialization() {
    let settings = GroupSettings {
        id: Uuid::new_v4(),
        room_id: Uuid::new_v4(),
        join_approval_required: true,
        member_can_invite: true,
        member_can_add_friends: false,
        require_admin_to_add_friends: true,
        max_members: 500,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let serialized = serde_json::to_string(&settings).unwrap();
    let deserialized: GroupSettings = serde_json::from_str(&serialized).unwrap();

    assert_eq!(settings.room_id, deserialized.room_id);
    assert_eq!(settings.join_approval_required, deserialized.join_approval_required);
    assert_eq!(settings.max_members, deserialized.max_members);
}

#[test]
fn test_group_announcement_serialization() {
    let announcement = GroupAnnouncement {
        id: Uuid::new_v4(),
        room_id: Uuid::new_v4(),
        title: "Welcome".to_string(),
        content: "Welcome to the group!".to_string(),
        publisher_id: Uuid::new_v4(),
        is_pinned: true,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let serialized = serde_json::to_string(&announcement).unwrap();
    let deserialized: GroupAnnouncement = serde_json::from_str(&serialized).unwrap();

    assert_eq!(announcement.room_id, deserialized.room_id);
    assert_eq!(announcement.title, deserialized.title);
    assert_eq!(announcement.is_pinned, deserialized.is_pinned);
}

#[test]
fn test_join_request_status_enum() {
    assert_eq!(JoinRequestStatus::Pending as i32, 0);
    assert_eq!(JoinRequestStatus::Approved as i32, 1);
    assert_eq!(JoinRequestStatus::Rejected as i32, 2);

    assert_eq!(JoinRequestStatus::Pending.to_string(), "pending");
    assert_eq!(JoinRequestStatus::Approved.to_string(), "approved");
    assert_eq!(JoinRequestStatus::Rejected.to_string(), "rejected");
}

#[test]
fn test_invitation_status_enum() {
    assert_eq!(InvitationStatus::Pending as i32, 0);
    assert_eq!(InvitationStatus::Accepted as i32, 1);
    assert_eq!(InvitationStatus::Declined as i32, 2);
    assert_eq!(InvitationStatus::Expired as i32, 3);

    assert_eq!(InvitationStatus::Pending.to_string(), "pending");
    assert_eq!(InvitationStatus::Accepted.to_string(), "accepted");
    assert_eq!(InvitationStatus::Declined.to_string(), "declined");
    assert_eq!(InvitationStatus::Expired.to_string(), "expired");
}

#[test]
fn test_create_announcement_request() {
    let request = CreateAnnouncementRequest {
        title: "Test Announcement".to_string(),
        content: "This is a test announcement content".to_string(),
        is_pinned: Some(true),
    };

    let serialized = serde_json::to_string(&request).unwrap();
    let deserialized: CreateAnnouncementRequest = serde_json::from_str(&serialized).unwrap();

    assert_eq!(request.title, deserialized.title);
    assert_eq!(request.content, deserialized.content);
    assert_eq!(request.is_pinned, deserialized.is_pinned);
}

#[test]
fn test_update_group_settings_request() {
    let request = UpdateGroupSettingsRequest {
        join_approval_required: Some(false),
        member_can_invite: Some(true),
        member_can_add_friends: Some(true),
        require_admin_to_add_friends: Some(false),
        max_members: Some(1000),
    };

    let serialized = serde_json::to_string(&request).unwrap();
    let deserialized: UpdateGroupSettingsRequest = serde_json::from_str(&serialized).unwrap();

    assert_eq!(request.join_approval_required, deserialized.join_approval_required);
    assert_eq!(request.max_members, deserialized.max_members);
}

#[test]
fn test_review_join_request_request() {
    let request = ReviewJoinRequestRequest {
        status: JoinRequestStatus::Approved,
        review_message: Some("Approved!".to_string()),
    };

    let serialized = serde_json::to_string(&request).unwrap();
    let deserialized: ReviewJoinRequestRequest = serde_json::from_str(&serialized).unwrap();

    assert_eq!(request.status, deserialized.status);
    assert_eq!(request.review_message, deserialized.review_message);
}

#[test]
fn test_invite_to_group_request() {
    let user_ids = vec!["user1".to_string(), "user2".to_string(), "user3".to_string()];
    let request = InviteToGroupRequest {
        user_ids,
        message: Some("You are invited to join our group".to_string()),
    };

    let serialized = serde_json::to_string(&request).unwrap();
    let deserialized: InviteToGroupRequest = serde_json::from_str(&serialized).unwrap();

    assert_eq!(deserialized.user_ids.len(), 3);
    assert!(deserialized.user_ids.contains(&"user1".to_string()));
}

#[test]
fn test_appoint_admin_request() {
    let request = AppointAdminRequest {
        user_id: "admin-user-id".to_string(),
        role: "deputy_admin".to_string(),
        permissions: Some(vec!["manage_members".to_string(), "view_logs".to_string()]),
    };

    let serialized = serde_json::to_string(&request).unwrap();
    let deserialized: AppointAdminRequest = serde_json::from_str(&serialized).unwrap();

    assert_eq!(request.user_id, deserialized.user_id);
    assert_eq!(request.role, deserialized.role);
    assert_eq!(request.permissions, deserialized.permissions);
}

#[test]
fn test_mute_user_request() {
    let request = MuteUserRequest {
        user_id: "muted-user-id".to_string(),
        reason: Some("Spam messages".to_string()),
        mute_duration_hours: Some(24),
    };

    let serialized = serde_json::to_string(&request).unwrap();
    let deserialized: MuteUserRequest = serde_json::from_str(&serialized).unwrap();

    assert_eq!(request.user_id, deserialized.user_id);
    assert_eq!(request.reason, deserialized.reason);
    assert_eq!(request.mute_duration_hours, deserialized.mute_duration_hours);
}

#[test]
fn test_group_detail_info() {
    let info = GroupDetailInfo {
        id: Uuid::new_v4(),
        name: "Test Group".to_string(),
        description: Some("A test group".to_string()),
        avatar_url: Some("https://example.com/group.jpg".to_string()),
        room_type: RoomType::Group,
        owner_id: Uuid::new_v4(),
        created_at: Utc::now(),
        updated_at: Utc::now(),
        join_approval_required: false,
        member_can_invite: true,
        member_can_add_friends: false,
        require_admin_to_add_friends: true,
        max_members: 500,
        current_member_count: 10,
        announcement_count: 5,
        pending_request_count: 2,
    };

    let serialized = serde_json::to_string(&info).unwrap();
    let deserialized: GroupDetailInfo = serde_json::from_str(&serialized).unwrap();

    assert_eq!(info.id, deserialized.id);
    assert_eq!(info.name, deserialized.name);
    assert_eq!(info.current_member_count, deserialized.current_member_count);
}

#[test]
fn test_message_type_conversion() {
    assert_eq!(MessageType::Text.to_string(), "text");
    assert_eq!(MessageType::Image.to_string(), "image");
    assert_eq!(MessageType::Video.to_string(), "video");
    assert_eq!(MessageType::Voice.to_string(), "voice");
    assert_eq!(MessageType::File.to_string(), "file");
    assert_eq!(MessageType::System.to_string(), "system");
    assert_eq!(MessageType::Mixed.to_string(), "mixed");
}

#[test]
fn test_user_status_conversion() {
    assert_eq!(UserStatus::Active as i32, 0);
    assert_eq!(UserStatus::Inactive as i32, 1);
    assert_eq!(UserStatus::Banned as i32, 2);
}

#[test]
fn test_room_type_conversion() {
    assert_eq!(RoomType::Private as i32, 0);
    assert_eq!(RoomType::Group as i32, 1);
    assert_eq!(RoomType::Public as i32, 2);
    assert_eq!(RoomType::Favorite as i32, 3);
}

#[test]
fn test_member_role_conversion() {
    assert_eq!(MemberRole::Owner as i32, 0);
    assert_eq!(MemberRole::Admin as i32, 1);
    assert_eq!(MemberRole::Member as i32, 2);
}
