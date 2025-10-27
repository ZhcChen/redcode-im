// 模型转换工具模块
// 用于在 database::models 和 crate::models 之间转换

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
        status: None, // API 层不允许直接修改状态
    }
}

// ==================== 房间模型转换 ====================

/// 将数据库房间模型转换为 API 房间信息
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
pub fn db_message_to_api_message_info(
    db_msg: &crate::database::models::MessageWithSender,
) -> crate::models::MessageInfo {
    crate::models::MessageInfo {
        id: db_msg.id.to_string(),
        room_id: db_msg.room_id.to_string(),
        sender_id: db_msg.sender_id.to_string(),
        sender_username: db_msg.sender_username.clone(),
        sender_nickname: db_msg.sender_nickname.clone(),
        sender_avatar_url: db_msg.sender_avatar_url.clone(),
        content: db_msg.content.clone(),
        message_type: db_message_type_to_api(&db_msg.message_type),
        created_at: db_msg.created_at.to_rfc3339(),
        quoted_message: db_message_to_api_quoted_message(db_msg),
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
    }
}

/// 将 API 消息类型转换为数据库消息类型
pub fn api_message_type_to_db(
    api_type: &crate::models::MessageType,
) -> crate::database::models::MessageType {
    match api_type {
        crate::models::MessageType::Text => crate::database::models::MessageType::Text,
        crate::models::MessageType::Image => crate::database::models::MessageType::Image,
        crate::models::MessageType::File => crate::database::models::MessageType::File,
        crate::models::MessageType::System => crate::database::models::MessageType::System,
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

    crate::models::ChatSummary {
        room_id: row.room_id.to_string(),
        name: row.room_name.clone(),
        room_type: db_room_type_to_api(&row.room_type),
        avatar_url: row.room_avatar_url.clone(),
        description: row.room_description.clone(),
        unread_count: row.unread_count,
        last_read_message_id: row.last_read_message_id.map(|id| id.to_string()),
        last_read_at: row.last_read_at.map(|dt| dt.to_rfc3339()),
        last_message,
    }
}

fn db_message_to_api_quoted_message(
    db_msg: &crate::database::models::MessageWithSender,
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
    })
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
    friendship: &crate::database::models::Friendship,
    friend_user: &crate::database::models::User,
) -> crate::models::FriendInfo {
    crate::models::FriendInfo {
        id: friendship.id.to_string(),
        user: db_user_to_api_user_info(friend_user),
        created_at: friendship.created_at.to_rfc3339(),
    }
}

// ==================== ID 转换工具 ====================

/// 将 String ID 转换为 Uuid（带错误处理）
pub fn string_to_uuid(id_str: &str) -> Result<Uuid, crate::error::AppError> {
    Uuid::parse_str(id_str)
        .map_err(|e| crate::error::AppError::ValidationError(format!("Invalid UUID format: {}", e)))
}

/// 将多个 String ID 转换为 Uuid 列表
pub fn strings_to_uuids(id_strs: &[String]) -> Result<Vec<Uuid>, crate::error::AppError> {
    id_strs.iter().map(|s| string_to_uuid(s)).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;
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
}
