// 模型转换工具模块
// 用于在 database::models 和 crate::models 之间转换

use crate::i18n::message::MessageParams;
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine;
use uuid::Uuid;

// ==================== 用户模型转换 ====================

/// 将数据库用户模型转换为 API 用户信息
pub fn db_user_to_api_user_info(
    db_user: &crate::database::models::User,
) -> crate::models::UserInfo {
    crate::models::UserInfo {
        id: db_user.id.to_string(),
        username: db_user.username.clone(),
        email: db_user.email.clone(),
        nickname: db_user.nickname.clone(),
        avatar_url: db_user.avatar_url.clone(),
        avatar_object_key: db_user.avatar_object_key.clone(),
        status: db_user_status_to_api_status(&db_user.status),
    }
}

/// 将数据库用户状态转换为 API 用户状态
pub fn db_user_status_to_api_status(
    db_status: &crate::database::models::UserStatus,
) -> crate::models::UserStatus {
    match db_status {
        crate::database::models::UserStatus::Active => crate::models::UserStatus::Active,
        crate::database::models::UserStatus::Inactive => crate::models::UserStatus::Inactive,
        crate::database::models::UserStatus::Banned => crate::models::UserStatus::Banned,
    }
}

/// 将 API 创建用户请求转换为数据库创建用户请求
pub fn api_create_user_to_db(
    api_req: &crate::models::CreateUserRequest,
) -> crate::database::models::CreateUserRequest {
    crate::database::models::CreateUserRequest {
        username: api_req.username.clone(),
        email: api_req.email.clone(),
        password: api_req.password.clone(),
        nickname: api_req.nickname.clone(),
    }
}

/// 将 API 登录请求转换为数据库登录请求
pub fn api_login_to_db(
    api_req: &crate::models::LoginRequest,
) -> crate::database::models::LoginRequest {
    crate::database::models::LoginRequest {
        username: api_req.username.clone(),
        password: api_req.password.clone(),
    }
}

/// 将 API 更新用户请求转换为数据库更新用户请求
pub fn api_update_user_to_db(
    api_req: &crate::models::UpdateUserRequest,
) -> crate::database::models::UpdateUserRequest {
    crate::database::models::UpdateUserRequest {
        nickname: api_req.nickname.clone(),
        avatar_url: api_req.avatar_url.clone(),
        avatar_object_key: api_req.avatar_object_key.clone(),
        status: None, // API 层不允许直接修改状态
    }
}

// ==================== 房间模型转换 ====================

/// 将数据库房间模型转换为 API 房间信息
#[allow(dead_code)]
pub fn db_room_to_api_room_info(
    db_room: &crate::database::models::Room,
) -> crate::models::RoomInfo {
    crate::models::RoomInfo {
        id: db_room.id.to_string(),
        name: db_room.name.clone(),
        description: db_room.description.clone(),
        avatar_url: db_room.avatar_url.clone(),
        room_type: db_room_type_to_api(&db_room.room_type),
        owner_id: db_room.owner_id.to_string(),
        created_at: db_room.created_at.to_rfc3339(),
    }
}

/// 将数据库房间类型转换为 API 房间类型
pub fn db_room_type_to_api(db_type: &crate::database::models::RoomType) -> crate::models::RoomType {
    match db_type {
        crate::database::models::RoomType::Private => crate::models::RoomType::Private,
        crate::database::models::RoomType::Group => crate::models::RoomType::Group,
        crate::database::models::RoomType::Public => crate::models::RoomType::Public,
        crate::database::models::RoomType::Favorite => crate::models::RoomType::Favorite,
    }
}

/// 将 API 房间类型转换为数据库房间类型
#[allow(dead_code)]
pub fn api_room_type_to_db(
    api_type: &crate::models::RoomType,
) -> crate::database::models::RoomType {
    match api_type {
        crate::models::RoomType::Private => crate::database::models::RoomType::Private,
        crate::models::RoomType::Group => crate::database::models::RoomType::Group,
        crate::models::RoomType::Public => crate::database::models::RoomType::Public,
        crate::models::RoomType::Favorite => crate::database::models::RoomType::Favorite,
    }
}

/// 将数据库成员角色转换为 API 成员角色
#[allow(dead_code)]
pub fn db_member_role_to_api(
    db_role: &crate::database::models::MemberRole,
) -> crate::models::MemberRole {
    match db_role {
        crate::database::models::MemberRole::Owner => crate::models::MemberRole::Owner,
        crate::database::models::MemberRole::Admin => crate::models::MemberRole::Admin,
        crate::database::models::MemberRole::Member => crate::models::MemberRole::Member,
    }
}

/// 将 API 成员角色转换为数据库成员角色
#[allow(dead_code)]
pub fn api_member_role_to_db(
    api_role: &crate::models::MemberRole,
) -> crate::database::models::MemberRole {
    match api_role {
        crate::models::MemberRole::Owner => crate::database::models::MemberRole::Owner,
        crate::models::MemberRole::Admin => crate::database::models::MemberRole::Admin,
        crate::models::MemberRole::Member => crate::database::models::MemberRole::Member,
    }
}

/// 将数据库房间成员转换为 API 房间成员信息
#[allow(dead_code)]
pub fn db_room_member_to_api(
    db_member: &crate::database::models::RoomMember,
) -> crate::models::RoomMemberInfo {
    crate::models::RoomMemberInfo {
        user_id: db_member.user_id.to_string(),
        role: db_member_role_to_api(&db_member.role),
        joined_at: db_member.joined_at.to_rfc3339(),
    }
}

// ==================== 消息模型转换 ====================

/// 将数据库消息模型转换为 API 消息信息
use std::collections::HashMap;

pub fn db_message_to_api_message_info(
    db_msg: &crate::database::models::MessageWithSender,
    parts_lookup: &HashMap<uuid::Uuid, Vec<crate::database::models::MessagePart>>,
    room_pin: Option<&crate::database::models::RoomPin>,
    delivery_status: Option<crate::models::MessageDeliveryStatus>,
) -> crate::models::MessageInfo {
    let is_pinned = room_pin
        .map(|pin| pin.message_id == db_msg.id)
        .unwrap_or(false);
    let (pinned_at, pinned_by) = if is_pinned {
        let pin = room_pin.unwrap();
        (
            Some(pin.pinned_at.to_rfc3339()),
            Some(pin.pinned_by.to_string()),
        )
    } else {
        (None, None)
    };

    let forward =
        db_msg
            .forward_from_message_id
            .map(|message_id| crate::models::ForwardMessageInfo {
                message_id: message_id.to_string(),
                room_id: db_msg
                    .forward_from_room_id
                    .map(|id| id.to_string())
                    .unwrap_or_default(),
                sender_id: db_msg
                    .forward_from_sender_id
                    .map(|id| id.to_string())
                    .unwrap_or_default(),
                sender_username: db_msg.forward_from_sender_username.clone(),
                sender_nickname: db_msg.forward_from_sender_nickname.clone(),
            });

    let current_parts = parts_lookup
        .get(&db_msg.id)
        .map(|v| v.as_slice())
        .unwrap_or(&[]);

    let api_parts: Vec<crate::models::MessagePartInfo> =
        current_parts.iter().map(db_message_part_to_api).collect();

    crate::models::MessageInfo {
        id: db_msg.id.to_string(),
        room_id: db_msg.room_id.to_string(),
        sender_id: db_msg.sender_id.to_string(),
        sender_username: db_msg.sender_username.clone(),
        sender_nickname: db_msg.sender_nickname.clone(),
        sender_avatar_url: db_msg.sender_avatar_url.clone(),
        content: db_msg.content.clone(),
        encrypted_content: db_msg
            .encrypted_content
            .as_ref()
            .map(|data| BASE64_STANDARD.encode(data)),
        encryption_metadata: db_msg.encryption_metadata.clone(),
        message_type: db_message_type_to_api(&db_msg.message_type),
        status: delivery_status,
        created_at: db_msg.created_at.to_rfc3339(),
        quoted_message: db_message_to_api_quoted_message(db_msg, parts_lookup),
        forward_message: forward,
        is_deleted: db_msg.deleted_at.is_some(),
        deleted_at: db_msg.deleted_at.map(|dt| dt.to_rfc3339()),
        is_edited: db_msg.edited_at.is_some(),
        edited_at: db_msg.edited_at.map(|dt| dt.to_rfc3339()),
        is_pinned,
        pinned_at,
        pinned_by,
        parts: api_parts,
    }
}

/// 将数据库消息类型转换为 API 消息类型
pub fn db_message_type_to_api(
    db_type: &crate::database::models::MessageType,
) -> crate::models::MessageType {
    match db_type {
        crate::database::models::MessageType::Text => crate::models::MessageType::Text,
        crate::database::models::MessageType::Image => crate::models::MessageType::Image,
        crate::database::models::MessageType::File => crate::models::MessageType::File,
        crate::database::models::MessageType::System => crate::models::MessageType::System,
        crate::database::models::MessageType::Video => crate::models::MessageType::Video,
        crate::database::models::MessageType::Audio => crate::models::MessageType::Audio,
        crate::database::models::MessageType::Mixed => crate::models::MessageType::Mixed,
    }
}

/// 将 API 消息类型转换为数据库消息类型
#[allow(dead_code)]
pub fn api_message_type_to_db(
    api_type: &crate::models::MessageType,
) -> crate::database::models::MessageType {
    match api_type {
        crate::models::MessageType::Text => crate::database::models::MessageType::Text,
        crate::models::MessageType::Image => crate::database::models::MessageType::Image,
        crate::models::MessageType::File => crate::database::models::MessageType::File,
        crate::models::MessageType::System => crate::database::models::MessageType::System,
        crate::models::MessageType::Video => crate::database::models::MessageType::Video,
        crate::models::MessageType::Audio => crate::database::models::MessageType::Audio,
        crate::models::MessageType::Mixed => crate::database::models::MessageType::Mixed,
    }
}

/// 将数据库会话概要转换为 API 会话概要
pub fn db_chat_summary_to_api(
    row: &crate::database::models::ChatSummaryRow,
) -> crate::models::ChatSummary {
    let last_message = row.last_message_id.map(|message_id| {
        let message_type = row
            .last_message_type
            .as_ref()
            .map(|ty| db_message_type_to_api(ty))
            .unwrap_or(crate::models::MessageType::Text);

        crate::models::ChatMessagePreview {
            id: message_id.to_string(),
            content: row.last_message_content.clone().unwrap_or_default(),
            message_type,
            created_at: row
                .last_message_created_at
                .map(|dt| dt.to_rfc3339())
                .unwrap_or_default(),
            sender_id: row
                .last_message_sender_id
                .map(|id| id.to_string())
                .unwrap_or_default(),
            sender_username: row.last_message_sender_username.clone().unwrap_or_default(),
            sender_nickname: row.last_message_sender_nickname.clone(),
        }
    });

    let notification_settings = row.notification_settings as i32;
    let is_muted = matches!(
        row.notification_settings,
        crate::database::models::NotificationSetting::Muted
    );

    crate::models::ChatSummary {
        room_id: row.room_id.to_string(),
        name: row.room_name.clone(),
        room_type: db_room_type_to_api(&row.room_type),
        avatar_url: row.room_avatar_url.clone(),
        room_avatar_object_key: row.room_avatar_object_key.clone(),
        description: row.room_description.clone(),
        unread_count: row.unread_count,
        last_read_message_id: row.last_read_message_id.map(|id| id.to_string()),
        last_read_at: row.last_read_at.map(|dt| dt.to_rfc3339()),
        notification_settings,
        is_muted,
        is_pinned: row.is_pinned,
        last_message,
        friend_user_id: row.friend_user_id.map(|id| id.to_string()),
        friend_nickname: row.friend_nickname.clone(),
        friend_username: row.friend_username.clone(),
        friend_remark: row.friend_remark.clone(),
        friend_avatar_object_key: row.friend_avatar_object_key.clone(),
    }
}

fn db_message_to_api_quoted_message(
    db_msg: &crate::database::models::MessageWithSender,
    parts_lookup: &HashMap<uuid::Uuid, Vec<crate::database::models::MessagePart>>,
) -> Option<crate::models::QuotedMessageInfo> {
    let quoted_id = db_msg.quoted_message_id?;
    let quoted_room_id = db_msg.quoted_message_room_id.unwrap_or(db_msg.room_id);
    let quoted_sender_id = db_msg.quoted_message_sender_id?;

    let username = db_msg
        .quoted_message_sender_username
        .clone()
        .unwrap_or_default();
    let message_type = db_msg
        .quoted_message_type
        .as_ref()
        .map(db_message_type_to_api)
        .unwrap_or(crate::models::MessageType::Text);
    let is_deleted = db_msg.quoted_message_deleted_at.is_some();
    let content = if is_deleted {
        None
    } else {
        db_msg.quoted_message_content.clone()
    };

    let created_at = db_msg.quoted_message_created_at.map(|dt| dt.to_rfc3339());
    let quoted_parts = parts_lookup
        .get(&quoted_id)
        .map(|v| v.as_slice())
        .unwrap_or(&[]);

    Some(crate::models::QuotedMessageInfo {
        id: quoted_id.to_string(),
        room_id: quoted_room_id.to_string(),
        sender_id: quoted_sender_id.to_string(),
        sender_username: username,
        sender_nickname: db_msg.quoted_message_sender_nickname.clone(),
        sender_avatar_url: db_msg.quoted_message_sender_avatar_url.clone(),
        content,
        message_type,
        created_at,
        is_deleted,
        parts: quoted_parts.iter().map(db_message_part_to_api).collect(),
    })
}

fn db_message_part_to_api(
    part: &crate::database::models::MessagePart,
) -> crate::models::MessagePartInfo {
    let attachment = match part.part_type {
        crate::database::models::MessagePartType::Text => None,
        _ => part
            .attachment_key
            .as_ref()
            .map(|key| crate::models::MessageAttachmentInfo {
                key: key.clone(),
                name: part.attachment_name.clone(),
                mime: part.attachment_mime.clone(),
                size: part.attachment_size,
                width: part.width,
                height: part.height,
                duration_ms: part.duration_ms,
                thumbnail_key: part.thumbnail_key.clone(),
            }),
    };

    crate::models::MessagePartInfo {
        position: part.position,
        part_type: db_message_part_type_to_api(&part.part_type),
        text: part.text_content.clone(),
        attachment,
    }
}

fn db_message_part_type_to_api(
    db_type: &crate::database::models::MessagePartType,
) -> crate::models::MessagePartType {
    match db_type {
        crate::database::models::MessagePartType::Text => crate::models::MessagePartType::Text,
        crate::database::models::MessagePartType::Image => crate::models::MessagePartType::Image,
        crate::database::models::MessagePartType::Video => crate::models::MessagePartType::Video,
        crate::database::models::MessagePartType::Audio => crate::models::MessagePartType::Audio,
        crate::database::models::MessagePartType::File => crate::models::MessagePartType::File,
    }
}

// ==================== 文档模型转换 ====================

pub fn db_document_to_api(
    doc: &crate::database::models::AppDocument,
) -> crate::models::DocumentContent {
    crate::models::DocumentContent {
        key: doc.key.clone(),
        title: doc.title.clone(),
        content: doc.content.clone(),
        updated_at: doc.updated_at.to_rfc3339(),
        updated_by: doc.updated_by.map(|id| id.to_string()),
    }
}

pub fn api_update_document_to_db(
    req: &crate::models::UpdateDocumentRequest,
    updated_by: Option<uuid::Uuid>,
) -> crate::database::models::DocumentUpdate {
    crate::database::models::DocumentUpdate {
        title: req.title.clone(),
        content: req.content.clone(),
        updated_by,
    }
}

// ==================== 好友模型转换 ====================

/// 将数据库好友请求状态转换为 API 状态
pub fn db_friend_request_status_to_api(
    status: &crate::database::models::FriendRequestStatus,
) -> crate::models::FriendRequestStatus {
    match status {
        crate::database::models::FriendRequestStatus::Pending => {
            crate::models::FriendRequestStatus::Pending
        }
        crate::database::models::FriendRequestStatus::Accepted => {
            crate::models::FriendRequestStatus::Accepted
        }
        crate::database::models::FriendRequestStatus::Declined => {
            crate::models::FriendRequestStatus::Declined
        }
    }
}

/// 将数据库好友请求转换为 API 信息
pub fn db_friend_request_to_api(
    request: &crate::database::models::FriendRequest,
    requester: &crate::database::models::User,
    addressee: &crate::database::models::User,
    current_user_id: &Uuid,
) -> crate::models::FriendRequestInfo {
    crate::models::FriendRequestInfo {
        id: request.id.to_string(),
        requester: db_user_to_api_user_info(requester),
        addressee: db_user_to_api_user_info(addressee),
        status: db_friend_request_status_to_api(&request.status),
        message: request.message.clone(),
        created_at: request.created_at.to_rfc3339(),
        responded_at: request.responded_at.map(|dt| dt.to_rfc3339()),
        is_incoming: request.addressee_id == *current_user_id,
    }
}

/// 将数据库好友关系转换为 API 好友信息
pub fn db_friendship_to_api(
    friendship_record: &crate::database::friend_store::FriendshipRecord,
    friend_user: &crate::database::models::User,
) -> crate::models::FriendInfo {
    crate::models::FriendInfo {
        id: friendship_record.friendship.id.to_string(),
        user: db_user_to_api_user_info(friend_user),
        created_at: friendship_record.friendship.created_at.to_rfc3339(),
        friend_remark: friendship_record.friend_remark.clone(),
    }
}

// ==================== ID 转换工具 ====================

/// 将 String ID 转换为 Uuid（带错误处理）
pub fn string_to_uuid(id_str: &str) -> Result<Uuid, crate::error::AppError> {
    Uuid::parse_str(id_str)
        .map_err(|e| crate::error::AppError::ValidationError(format!("Invalid UUID format: {}", e)))
}

/// 将多个 String ID 转换为 Uuid 列表
#[allow(dead_code)]
pub fn strings_to_uuids(id_strs: &[String]) -> Result<Vec<Uuid>, crate::error::AppError> {
    id_strs.iter().map(|s| string_to_uuid(s)).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{CreateAppVersionRequest, CreateHotUpdateRequest};
    use uuid::Uuid;

    #[test]
    fn test_user_status_conversion() {
        let db_status = crate::database::models::UserStatus::Active;
        let api_status = db_user_status_to_api_status(&db_status);
        assert_eq!(api_status, crate::models::UserStatus::Active);
    }

    #[test]
    fn test_room_type_conversion() {
        let db_type = crate::database::models::RoomType::Group;
        let api_type = db_room_type_to_api(&db_type);
        let db_type_back = api_room_type_to_db(&api_type);
        assert_eq!(db_type, db_type_back);
    }

    #[test]
    fn test_string_to_uuid() {
        let uuid = Uuid::new_v4();
        let uuid_str = uuid.to_string();
        let result = string_to_uuid(&uuid_str);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), uuid);
    }

    #[test]
    fn test_invalid_uuid() {
        let result = string_to_uuid("invalid-uuid");
        assert!(result.is_err());
    }

    #[test]
    fn api_create_version_to_db_invalid_platform_returns_stable_key_and_params() {
        let req = test_create_app_version_request("symbian");

        let error = api_create_version_to_db(&req, None).expect_err("invalid platform should fail");

        assert_eq!(error.response_message_key(), "version.platform_unsupported");
        let params = error.message_params().expect("params present");
        assert_eq!(params["platform"], "symbian");
        assert_eq!(
            params["supported_platforms"],
            "windows, macos, ios, android, linux"
        );
    }

    #[test]
    fn api_create_hot_update_to_db_invalid_platform_returns_stable_key_and_params() {
        let req = test_create_hot_update_request("symbian", &Uuid::new_v4().to_string());

        let error =
            api_create_hot_update_to_db(&req, None).expect_err("invalid platform should fail");

        assert_eq!(error.response_message_key(), "version.platform_unsupported");
        let params = error.message_params().expect("params present");
        assert_eq!(params["platform"], "symbian");
        assert_eq!(
            params["supported_platforms"],
            "windows, macos, ios, android, linux"
        );
    }

    #[test]
    fn api_create_hot_update_to_db_invalid_app_version_id_returns_stable_key() {
        let req = test_create_hot_update_request("ios", "not-a-uuid");

        let error = api_create_hot_update_to_db(&req, None)
            .expect_err("invalid app_version_id should fail");

        assert_eq!(
            error.response_message_key(),
            "version.app_version_id_invalid"
        );
        assert!(error.message_params().is_none());
    }

    #[test]
    fn convert_version_validation_should_not_embed_legacy_free_strings() {
        let source = include_str!("convert.rs");

        for legacy in [
            "\u{4e0d}\u{652f}\u{6301}\u{7684}\u{5e73}\u{53f0}",
            "\u{65e0}\u{6548}\u{7684} app_version_id",
        ] {
            assert!(
                !source.contains(legacy),
                "convert version validation should not embed legacy literal: {legacy}"
            );
        }
    }

    fn test_create_app_version_request(platform: &str) -> CreateAppVersionRequest {
        CreateAppVersionRequest {
            platform: platform.to_string(),
            version: "1.0.0".to_string(),
            build_number: 1,
            channel: "stable".to_string(),
            download_key: "versions/ios/stable/app.pkg".to_string(),
            download_url: None,
            app_store_url: None,
            file_size: None,
            checksum: None,
            signature: None,
            release_notes: None,
            mandatory: false,
            is_active: true,
            released_at: None,
        }
    }

    fn test_create_hot_update_request(
        platform: &str,
        app_version_id: &str,
    ) -> CreateHotUpdateRequest {
        CreateHotUpdateRequest {
            platform: platform.to_string(),
            app_version_id: app_version_id.to_string(),
            patch_version: "1.0.1".to_string(),
            channel: "stable".to_string(),
            download_key: "patches/ios/stable/patch.zip".to_string(),
            download_url: None,
            file_size: None,
            checksum: None,
            signature: None,
            rollout_percentage: 100,
            mandatory: false,
            description: None,
            released_at: None,
        }
    }
}

pub fn db_app_version_to_api(
    model: &crate::database::models::AppVersion,
) -> crate::models::AppVersionInfo {
    crate::models::AppVersionInfo {
        id: model.id.to_string(),
        platform: model.platform.to_string(),
        version: model.version.clone(),
        build_number: model.build_number,
        channel: model.channel.clone(),
        download_key: model.download_key.clone(),
        download_url: model.download_url.clone(),
        app_store_url: model.app_store_url.clone(),
        file_size: model.file_size,
        checksum: model.checksum.clone(),
        signature: model.signature.clone(),
        release_notes: model.release_notes.clone(),
        mandatory: model.mandatory,
        is_active: model.is_active,
        created_at: model.created_at.to_rfc3339(),
        updated_at: model.updated_at.to_rfc3339(),
        released_at: model.released_at.map(|dt| dt.to_rfc3339()),
    }
}

pub fn db_versions_to_api_list(
    models: &[crate::database::models::AppVersion],
) -> Vec<crate::models::AppVersionInfo> {
    models.iter().map(db_app_version_to_api).collect()
}

pub fn db_hot_update_to_api(
    model: &crate::database::models::HotUpdate,
) -> crate::models::HotUpdateInfo {
    crate::models::HotUpdateInfo {
        id: model.id.to_string(),
        platform: model.platform.to_string(),
        app_version_id: model.app_version_id.to_string(),
        patch_version: model.patch_version.clone(),
        channel: model.channel.clone(),
        download_key: model.download_key.clone(),
        download_url: model.download_url.clone(),
        file_size: model.file_size,
        checksum: model.checksum.clone(),
        signature: model.signature.clone(),
        rollout_percentage: model.rollout_percentage,
        mandatory: model.mandatory,
        description: model.description.clone(),
        is_active: model.is_active,
        released_at: model.released_at.map(|dt| dt.to_rfc3339()),
        created_at: model.created_at.to_rfc3339(),
        updated_at: model.updated_at.to_rfc3339(),
    }
}

pub fn db_hot_updates_to_api_list(
    models: &[crate::database::models::HotUpdate],
) -> Vec<crate::models::HotUpdateInfo> {
    models.iter().map(db_hot_update_to_api).collect()
}

pub fn db_hot_update_event_to_api(
    model: &crate::database::models::HotUpdateEvent,
) -> crate::models::HotUpdateEventInfo {
    crate::models::HotUpdateEventInfo {
        id: model.id.to_string(),
        platform: model.platform.to_string(),
        channel: model.channel.clone(),
        base_version: model.base_version.clone(),
        patch_version: model.patch_version.clone(),
        event_type: model.event_type.clone(),
        client_id: model.client_id.clone(),
        message: model.message.clone(),
        created_at: model.created_at.to_rfc3339(),
        // 新增的详细字段
        client_type: model.client_type.clone(),
        os_version: model.os_version.clone(),
        os_arch: model.os_arch.clone(),
        app_arch: model.app_arch.clone(),
        build_number: model.build_number,
        trigger_source: model.trigger_source.clone(),
        network_type: model.network_type.clone(),
        device_info: model.device_info.clone(),
    }
}

pub fn db_hot_update_events_to_api_list(
    models: &[crate::database::models::HotUpdateEvent],
) -> Vec<crate::models::HotUpdateEventInfo> {
    models.iter().map(db_hot_update_event_to_api).collect()
}

const SUPPORTED_VERSION_PLATFORMS: &str = "windows, macos, ios, android, linux";

fn version_validation_error(message_key: &'static str) -> crate::error::AppError {
    crate::error::AppError::ValidationError(String::new()).with_message_key(message_key)
}

fn version_validation_error_with_params(
    message_key: &'static str,
    params: MessageParams,
) -> crate::error::AppError {
    crate::error::AppError::ValidationError(String::new())
        .with_message_key_and_params(message_key, Some(params))
}

pub fn api_create_version_to_db(
    req: &crate::models::CreateAppVersionRequest,
    operator: Option<uuid::Uuid>,
) -> Result<crate::database::version_store::AppVersionInsert, crate::error::AppError> {
    use chrono::{DateTime, Utc};

    let platform =
        crate::database::models::Platform::from_str(req.platform.trim()).ok_or_else(|| {
            version_validation_error_with_params(
                "version.platform_unsupported",
                MessageParams::from([
                    ("platform".to_string(), req.platform.trim().to_string()),
                    (
                        "supported_platforms".to_string(),
                        SUPPORTED_VERSION_PLATFORMS.to_string(),
                    ),
                ]),
            )
        })?;

    let released_at = req
        .released_at
        .as_ref()
        .and_then(|v| DateTime::parse_from_rfc3339(v).ok())
        .map(|dt| dt.with_timezone(&Utc));

    Ok(crate::database::version_store::AppVersionInsert {
        platform,
        version: req.version.trim().to_string(),
        build_number: req.build_number,
        channel: req.channel.trim().to_string(),
        download_key: req.download_key.trim().to_string(),
        download_url: req.download_url.clone(),
        app_store_url: req.app_store_url.clone(),
        file_size: req.file_size,
        checksum: req.checksum.clone(),
        signature: req.signature.clone(),
        release_notes: req.release_notes.clone(),
        mandatory: req.mandatory,
        is_active: req.is_active,
        released_at,
        operator,
    })
}

pub fn api_update_version_to_db(
    req: &crate::models::UpdateAppVersionRequest,
    operator: Option<uuid::Uuid>,
) -> crate::database::version_store::AppVersionUpdate {
    use chrono::{DateTime, Utc};

    let released_at = req
        .released_at
        .as_ref()
        .and_then(|v| DateTime::parse_from_rfc3339(v).ok())
        .map(|dt| dt.with_timezone(&Utc));

    crate::database::version_store::AppVersionUpdate {
        download_key: req.download_key.clone(),
        download_url: req.download_url.clone(),
        app_store_url: req.app_store_url.clone(),
        file_size: req.file_size,
        checksum: req.checksum.clone(),
        signature: req.signature.clone(),
        release_notes: req.release_notes.clone(),
        mandatory: req.mandatory,
        is_active: req.is_active,
        released_at,
        operator,
    }
}

pub fn api_create_hot_update_to_db(
    req: &crate::models::CreateHotUpdateRequest,
    operator: Option<uuid::Uuid>,
) -> Result<crate::database::version_store::HotUpdateInsert, crate::error::AppError> {
    use chrono::{DateTime, Utc};

    let platform =
        crate::database::models::Platform::from_str(req.platform.trim()).ok_or_else(|| {
            version_validation_error_with_params(
                "version.platform_unsupported",
                MessageParams::from([
                    ("platform".to_string(), req.platform.trim().to_string()),
                    (
                        "supported_platforms".to_string(),
                        SUPPORTED_VERSION_PLATFORMS.to_string(),
                    ),
                ]),
            )
        })?;

    let released_at = req
        .released_at
        .as_ref()
        .and_then(|v| DateTime::parse_from_rfc3339(v).ok())
        .map(|dt| dt.with_timezone(&Utc));

    let app_version_id = uuid::Uuid::parse_str(req.app_version_id.trim())
        .map_err(|_| version_validation_error("version.app_version_id_invalid"))?;

    Ok(crate::database::version_store::HotUpdateInsert {
        platform,
        app_version_id,
        patch_version: req.patch_version.trim().to_string(),
        channel: req.channel.trim().to_string(),
        download_key: req.download_key.trim().to_string(),
        download_url: req.download_url.clone(),
        file_size: req.file_size,
        checksum: req.checksum.clone(),
        signature: req.signature.clone(),
        rollout_percentage: req.rollout_percentage,
        mandatory: req.mandatory,
        description: req.description.clone(),
        released_at,
        operator,
    })
}

pub fn api_update_hot_update_to_db(
    req: &crate::models::UpdateHotUpdateRequest,
    operator: Option<uuid::Uuid>,
) -> crate::database::version_store::HotUpdateUpdate {
    use chrono::{DateTime, Utc};

    let released_at = req
        .released_at
        .as_ref()
        .and_then(|v| DateTime::parse_from_rfc3339(v).ok())
        .map(|dt| dt.with_timezone(&Utc));

    crate::database::version_store::HotUpdateUpdate {
        patch_version: req.patch_version.clone(),
        channel: req.channel.clone(),
        download_key: req.download_key.clone(),
        download_url: req.download_url.clone(),
        file_size: req.file_size,
        checksum: req.checksum.clone(),
        signature: req.signature.clone(),
        rollout_percentage: req.rollout_percentage,
        mandatory: req.mandatory,
        description: req.description.clone(),
        is_active: req.is_active,
        released_at,
        operator,
    }
}
