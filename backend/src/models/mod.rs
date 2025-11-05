// API 层模型 - 用于 HTTP 请求/响应
// 特点：
// 1. 使用 String 类型的 ID（JSON 友好）
// 2. 不包含敏感字段（password_hash, deleted_at）
// 3. 用于与前端交互

pub mod convert;

use serde::{Deserialize, Serialize};

// ==================== 用户相关模型 ====================

/// 用户状态枚举（API 层）
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum UserStatus {
    Active,
    Inactive,
    Banned,
}

/// 用户公开信息（不包含敏感字段）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserInfo {
    pub id: String,
    pub username: String,
    pub email: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub avatar_object_key: Option<String>,
    pub status: UserStatus,
}

/// 创建用户请求
#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub username: String,
    pub email: String,
    pub password: String,
    pub nickname: Option<String>,
}

/// 用户登录请求
#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

/// 登录响应
#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub token: String,
    pub user: UserInfo,
}

#[derive(Debug, Deserialize)]
pub struct UpdateUserRequest {
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub avatar_object_key: Option<String>,
}

/// 修改密码请求
#[derive(Debug, Deserialize)]
pub struct ChangePasswordRequest {
    pub old_password: String,
    pub new_password: String,
}

/// 上传头像响应
#[derive(Debug, Serialize)]
pub struct UploadAvatarResponse {
    pub avatar_url: String,
}

// ==================== 版本管理模型 ====================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppVersionInfo {
    pub id: String,
    pub platform: String,
    pub version: String,
    pub build_number: i32,
    pub channel: String,
    pub download_key: String,
    pub download_url: Option<String>,
    pub file_size: Option<i64>,
    pub checksum: Option<String>,
    pub signature: Option<String>,
    pub release_notes: Option<String>,
    pub mandatory: bool,
    pub is_active: bool,
    pub created_at: String,
    pub updated_at: String,
    pub released_at: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CreateAppVersionRequest {
    pub platform: String,
    pub version: String,
    pub build_number: i32,
    #[serde(default = "CreateAppVersionRequest::default_channel")]
    pub channel: String,
    pub download_key: String,
    pub download_url: Option<String>,
    pub file_size: Option<i64>,
    pub checksum: Option<String>,
    pub signature: Option<String>,
    pub release_notes: Option<String>,
    #[serde(default)]
    pub mandatory: bool,
    #[serde(default = "CreateAppVersionRequest::default_is_active")]
    pub is_active: bool,
    pub released_at: Option<String>,
}

impl CreateAppVersionRequest {
    fn default_channel() -> String {
        "stable".to_string()
    }

    fn default_is_active() -> bool {
        true
    }
}

#[derive(Debug, Deserialize, Default)]
pub struct UpdateAppVersionRequest {
    pub download_key: Option<String>,
    pub download_url: Option<String>,
    pub file_size: Option<i64>,
    pub checksum: Option<String>,
    pub signature: Option<String>,
    pub release_notes: Option<String>,
    pub mandatory: Option<bool>,
    pub is_active: Option<bool>,
    pub released_at: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ListAppVersionsQuery {
    pub platform: String,
    pub channel: Option<String>,
    #[serde(default = "ListAppVersionsQuery::default_limit")]
    pub limit: i64,
    #[serde(default)]
    pub offset: i64,
}

impl ListAppVersionsQuery {
    fn default_limit() -> i64 {
        20
    }
}

#[derive(Debug, Deserialize)]
pub struct LatestVersionQuery {
    pub platform: String,
    #[serde(default = "LatestVersionQuery::default_channel")]
    pub channel: String,
    #[serde(default)]
    pub current_version: Option<String>,
}

impl LatestVersionQuery {
    fn default_channel() -> String {
        "stable".to_string()
    }
}

#[derive(Debug, Serialize)]
pub struct LatestVersionResponse {
    pub has_update: bool,
    pub current_version: Option<String>,
    pub version: Option<AppVersionInfo>,
}

// ==================== JWT Claims ====================

/// JWT Token Claims
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String, // 用户ID（String 格式）
    pub username: String,
    pub exp: usize, // 过期时间戳
    pub iat: usize, // 签发时间戳
}

// ==================== 房间相关模型 ====================

/// 房间类型（API 层）
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum RoomType {
    Private,  // 私聊
    Group,    // 群聊
    Public,   // 公开聊天室
    Favorite, // 收藏夹
}

/// 房间信息（API 响应）
#[derive(Debug, Clone, Serialize)]
pub struct RoomInfo {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub avatar_url: Option<String>,
    pub room_type: RoomType,
    pub owner_id: String,
    pub created_at: String, // ISO 8601 格式
}

/// 创建房间请求
#[derive(Debug, Deserialize)]
pub struct CreateRoomRequest {
    pub name: String,
    pub description: Option<String>,
    pub room_type: Option<RoomType>,
}

/// 房间成员角色（API 层）
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum MemberRole {
    Owner,  // 房主
    Admin,  // 管理员
    Member, // 普通成员
}

/// 房间成员信息（API 响应）
#[derive(Debug, Clone, Serialize)]
pub struct RoomMemberInfo {
    pub user_id: String,
    pub role: MemberRole,
    pub joined_at: String, // ISO 8601 格式
}

// ==================== 消息相关模型 ====================

/// 消息类型（API 层）
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum MessageType {
    Text,
    Image,
    File,
    System,
    Video,
    Audio,
    Mixed,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum MessagePartType {
    Text,
    Image,
    Video,
    Audio,
    File,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageAttachmentInfo {
    pub key: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mime: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub size: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub width: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub height: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration_ms: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub thumbnail_key: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessagePartInfo {
    pub position: i16,
    pub part_type: MessagePartType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub text: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub attachment: Option<MessageAttachmentInfo>,
}

/// 消息信息（API 响应）
#[derive(Debug, Clone, Serialize)]
pub struct MessageInfo {
    pub id: String,
    pub room_id: String,
    pub sender_id: String,
    pub sender_username: String,
    pub sender_nickname: Option<String>,
    pub sender_avatar_url: Option<String>,
    pub content: String,
    pub message_type: MessageType,
    pub created_at: String, // ISO 8601 格式
    #[serde(skip_serializing_if = "Option::is_none")]
    pub quoted_message: Option<QuotedMessageInfo>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub forward_message: Option<ForwardMessageInfo>,
    #[serde(default)]
    pub is_deleted: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub deleted_at: Option<String>,
    #[serde(default)]
    pub is_pinned: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pinned_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pinned_by: Option<String>,
    #[serde(default)]
    pub parts: Vec<MessagePartInfo>,
}

/// 发送消息请求
#[derive(Debug, Deserialize)]
pub struct SendMessageRequest {
    pub content: Option<String>,
    #[serde(default)]
    pub parts: Vec<MessagePartPayload>,
    #[serde(default)]
    pub quoted_message_id: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum MessagePartPayload {
    Text {
        text: String,
    },
    Image {
        key: String,
        #[serde(default)]
        name: Option<String>,
        #[serde(default)]
        mime: Option<String>,
        #[serde(default)]
        size: Option<i64>,
        #[serde(default)]
        width: Option<i32>,
        #[serde(default)]
        height: Option<i32>,
        #[serde(default)]
        thumbnail_key: Option<String>,
    },
    Video {
        key: String,
        #[serde(default)]
        name: Option<String>,
        #[serde(default)]
        mime: Option<String>,
        #[serde(default)]
        size: Option<i64>,
        #[serde(default)]
        width: Option<i32>,
        #[serde(default)]
        height: Option<i32>,
        #[serde(default)]
        duration_ms: Option<i32>,
        #[serde(default)]
        thumbnail_key: Option<String>,
    },
    Audio {
        key: String,
        #[serde(default)]
        name: Option<String>,
        #[serde(default)]
        mime: Option<String>,
        #[serde(default)]
        size: Option<i64>,
        #[serde(default)]
        duration_ms: Option<i32>,
    },
    File {
        key: String,
        #[serde(default)]
        name: Option<String>,
        #[serde(default)]
        mime: Option<String>,
        #[serde(default)]
        size: Option<i64>,
    },
}

/// 引用的消息信息（API 响应）
#[derive(Debug, Clone, Serialize)]
pub struct QuotedMessageInfo {
    pub id: String,
    pub room_id: String,
    pub sender_id: String,
    pub sender_username: String,
    pub sender_nickname: Option<String>,
    pub sender_avatar_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub content: Option<String>,
    pub message_type: MessageType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
    pub is_deleted: bool,
    #[serde(default)]
    pub parts: Vec<MessagePartInfo>,
}

/// 转发的消息信息（API 响应）
#[derive(Debug, Clone, Serialize)]
pub struct ForwardMessageInfo {
    pub message_id: String,
    pub room_id: String,
    pub sender_id: String,
    pub sender_username: Option<String>,
    pub sender_nickname: Option<String>,
}

/// 消息列表查询参数
#[derive(Debug, Deserialize)]
pub struct ListMessagesQuery {
    pub limit: Option<i64>,
    pub before_id: Option<String>,
    pub since_id: Option<String>,
}

// ==================== 消息已读相关模型 ====================

/// 标记消息已读请求
#[derive(Debug, Deserialize)]
pub struct MarkMessageReadRequest {
    pub message_id: String,
}

/// 消息已读信息（API 响应）
#[derive(Debug, Clone, Serialize)]
pub struct MessageReadInfo {
    pub user_id: String,
    pub username: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub read_at: String, // ISO 8601 格式
}

/// 未读消息统计
#[derive(Debug, Clone, Serialize)]
pub struct UnreadCount {
    pub room_id: String,
    pub unread_count: i64,
    pub last_read_message_id: Option<String>,
    pub last_read_at: Option<String>,
}

// ==================== 会话概要模型 ====================

/// 会话中的最后一条消息摘要
#[derive(Debug, Clone, Serialize)]
pub struct ChatMessagePreview {
    pub id: String,
    pub content: String,
    pub message_type: MessageType,
    pub created_at: String,
    pub sender_id: String,
    pub sender_username: String,
    pub sender_nickname: Option<String>,
}

/// 会话概要信息
#[derive(Debug, Clone, Serialize)]
pub struct ChatSummary {
    pub room_id: String,
    pub name: String,
    pub room_type: RoomType,
    pub avatar_url: Option<String>,
    pub description: Option<String>,
    pub unread_count: i64,
    pub last_read_message_id: Option<String>,
    pub last_read_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_message: Option<ChatMessagePreview>,
}

// ==================== 文档配置模型 ====================

#[derive(Debug, Clone, Serialize)]
pub struct DocumentContent {
    pub key: String,
    pub title: String,
    pub content: String,
    pub updated_at: String,
    pub updated_by: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateDocumentRequest {
    pub title: Option<String>,
    pub content: String,
}

// ==================== 好友相关模型 ====================

/// 好友请求状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum FriendRequestStatus {
    Pending,
    Accepted,
    Declined,
}

/// 创建好友请求
#[derive(Debug, Deserialize)]
pub struct CreateFriendRequest {
    pub target_user_id: String,
    #[serde(default)]
    pub message: Option<String>,
}

/// 好友请求响应动作
#[derive(Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FriendRequestAction {
    Accept,
    Decline,
}

/// 响应好友请求
#[derive(Debug, Deserialize)]
pub struct RespondFriendRequest {
    pub action: FriendRequestAction,
}

/// 好友请求信息
#[derive(Debug, Clone, Serialize)]
pub struct FriendRequestInfo {
    pub id: String,
    pub requester: UserInfo,
    pub addressee: UserInfo,
    pub status: FriendRequestStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
    pub created_at: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub responded_at: Option<String>,
    pub is_incoming: bool,
}

/// 好友信息
#[derive(Debug, Clone, Serialize)]
pub struct FriendInfo {
    pub id: String,
    pub user: UserInfo,
    pub created_at: String,
}
