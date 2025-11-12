use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use std::fmt;
use uuid::Uuid;

/// 用户表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct User {
    pub id: Uuid,
    pub username: String,
    pub email: String,
    pub password_hash: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub avatar_object_key: Option<String>,
    pub status: UserStatus,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}

/// 用户状态枚举
#[derive(
    Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, sqlx::Type,
)]
#[repr(i16)]
#[sqlx(type_name = "int2")]
pub enum UserStatus {
    Active = 0,
    Inactive = 1,
    Banned = 2,
}

impl Default for UserStatus {
    fn default() -> Self {
        UserStatus::Active
    }
}

/// 权限表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Permission {
    pub id: Uuid,
    pub name: String,
    pub code: String,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 角色表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Role {
    pub id: Uuid,
    pub name: String,
    pub code: String,
    pub description: Option<String>,
    pub is_system: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 用户角色关联表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct UserRole {
    pub id: Uuid,
    pub user_id: Uuid,
    pub role_id: Uuid,
    pub assigned_by: Uuid,
    pub assigned_at: DateTime<Utc>,
}

/// 角色权限关联表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct RolePermission {
    pub id: Uuid,
    pub role_id: Uuid,
    pub permission_id: Uuid,
    pub created_at: DateTime<Utc>,
}

/// 用户权限枚举（简化版，实际应该从数据库获取）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum UserPermission {
    // 用户管理
    UserView,
    UserCreate,
    UserUpdate,
    UserDelete,
    // 角色管理
    RoleView,
    RoleCreate,
    RoleUpdate,
    RoleDelete,
    // 系统管理
    SystemMonitor,
    SystemStats,
    SettingsManage,
    // 文件管理
    FileView,
    FileManage,
    StorageManage,
}

impl fmt::Display for UserPermission {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let code = match self {
            UserPermission::UserView => "user:view",
            UserPermission::UserCreate => "user:create",
            UserPermission::UserUpdate => "user:update",
            UserPermission::UserDelete => "user:delete",
            UserPermission::RoleView => "role:view",
            UserPermission::RoleCreate => "role:create",
            UserPermission::RoleUpdate => "role:update",
            UserPermission::RoleDelete => "role:delete",
            UserPermission::SystemMonitor => "system:monitor",
            UserPermission::SystemStats => "system:stats",
            UserPermission::SettingsManage => "settings:manage",
            UserPermission::FileView => "file:view",
            UserPermission::FileManage => "file:manage",
            UserPermission::StorageManage => "storage:manage",
        };
        f.write_str(code)
    }
}

impl fmt::Display for UserStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let text = match self {
            UserStatus::Active => "active",
            UserStatus::Inactive => "inactive",
            UserStatus::Banned => "banned",
        };
        f.write_str(text)
    }
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

/// 用户更新请求
#[derive(Debug, Deserialize)]
pub struct UpdateUserRequest {
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub avatar_object_key: Option<String>,
    pub status: Option<UserStatus>,
}

/// 应用版本记录
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct AppVersion {
    pub id: Uuid,
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
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub released_at: Option<DateTime<Utc>>,
    pub created_by: Option<Uuid>,
    pub updated_by: Option<Uuid>,
}

/// 房间表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Room {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub avatar_url: Option<String>,
    pub room_type: RoomType,
    pub owner_id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}

/// 房间类型枚举
#[derive(
    Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, sqlx::Type,
)]
#[repr(i16)]
#[serde(rename_all = "lowercase")]
#[sqlx(type_name = "int2")]
pub enum RoomType {
    Private = 0,  // 私聊
    Group = 1,    // 群聊
    Public = 2,   // 公共聊天室
    Favorite = 3, // 收藏夹（仅自己可见）
}

impl fmt::Display for RoomType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let text = match self {
            RoomType::Private => "private",
            RoomType::Group => "group",
            RoomType::Public => "public",
            RoomType::Favorite => "favorite",
        };
        f.write_str(text)
    }
}

/// 消息表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Message {
    pub id: Uuid,
    pub room_id: Uuid,
    pub sender_id: Uuid,
    pub content: String,
    pub message_type: MessageType,
    pub quoted_message_id: Option<Uuid>,
    pub forward_from_message_id: Option<Uuid>,
    pub forward_from_room_id: Option<Uuid>,
    pub forward_from_sender_id: Option<Uuid>,
    pub forward_from_sender_username: Option<String>,
    pub forward_from_sender_nickname: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}

/// 携带发送者信息的消息记录
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct MessageWithSender {
    pub id: Uuid,
    pub room_id: Uuid,
    pub sender_id: Uuid,
    pub content: String,
    pub message_type: MessageType,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub sender_username: String,
    pub sender_nickname: Option<String>,
    pub sender_avatar_url: Option<String>,
    pub quoted_message_id: Option<Uuid>,
    pub quoted_message_room_id: Option<Uuid>,
    pub quoted_message_sender_id: Option<Uuid>,
    pub quoted_message_sender_username: Option<String>,
    pub quoted_message_sender_nickname: Option<String>,
    pub quoted_message_sender_avatar_url: Option<String>,
    pub quoted_message_content: Option<String>,
    pub quoted_message_type: Option<MessageType>,
    pub quoted_message_created_at: Option<DateTime<Utc>>,
    pub quoted_message_deleted_at: Option<DateTime<Utc>>,
    pub forward_from_message_id: Option<Uuid>,
    pub forward_from_room_id: Option<Uuid>,
    pub forward_from_sender_id: Option<Uuid>,
    pub forward_from_sender_username: Option<String>,
    pub forward_from_sender_nickname: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct RoomPin {
    pub room_id: Uuid,
    pub message_id: Uuid,
    pub pinned_by: Uuid,
    pub pinned_at: DateTime<Utc>,
}

/// 用户房间置顶表模型 (用于用户级别的聊天置顶功能)
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct UserRoomPin {
    pub id: Uuid,
    pub user_id: Uuid,
    pub room_id: Uuid,
    pub pinned_at: DateTime<Utc>,
}

/// 消息类型枚举
#[derive(
    Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, sqlx::Type,
)]
#[repr(i16)]
#[serde(rename_all = "lowercase")]
#[sqlx(type_name = "int2")]
pub enum MessageType {
    Text = 0,   // 纯文本
    Image = 1,  // 单图
    File = 2,   // 文件
    System = 3, // 系统
    Video = 4,  // 视频
    Audio = 5,  // 音频/语音
    Mixed = 6,  // 混合内容（文本 + 多媒体）
}

impl Default for MessageType {
    fn default() -> Self {
        MessageType::Text
    }
}

impl fmt::Display for MessageType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let text = match self {
            MessageType::Text => "text",
            MessageType::Image => "image",
            MessageType::File => "file",
            MessageType::System => "system",
            MessageType::Video => "video",
            MessageType::Audio => "audio",
            MessageType::Mixed => "mixed",
        };
        f.write_str(text)
    }
}

#[derive(
    Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, sqlx::Type,
)]
#[repr(i16)]
#[sqlx(type_name = "int2")]
pub enum MessagePartType {
    Text = 0,
    Image = 1,
    Video = 2,
    Audio = 3,
    File = 4,
}

impl Default for MessagePartType {
    fn default() -> Self {
        MessagePartType::Text
    }
}

impl fmt::Display for MessagePartType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let text = match self {
            MessagePartType::Text => "text",
            MessagePartType::Image => "image",
            MessagePartType::Video => "video",
            MessagePartType::Audio => "audio",
            MessagePartType::File => "file",
        };
        f.write_str(text)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct MessagePart {
    pub id: Uuid,
    pub message_id: Uuid,
    pub position: i16,
    pub part_type: MessagePartType,
    pub text_content: Option<String>,
    pub attachment_key: Option<String>,
    pub attachment_name: Option<String>,
    pub attachment_mime: Option<String>,
    pub attachment_size: Option<i64>,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub duration_ms: Option<i32>,
    pub thumbnail_key: Option<String>,
    pub extra: Option<Value>,
    pub created_at: DateTime<Utc>,
}

/// 房间成员表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct RoomMember {
    pub id: Uuid,
    pub room_id: Uuid,
    pub user_id: Uuid,
    pub role: MemberRole,
    pub joined_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
    #[sqlx(default)]
    pub last_read_at: Option<DateTime<Utc>>,
    #[sqlx(default)]
    pub last_read_message_id: Option<Uuid>,
    #[sqlx(default)]
    pub notification_settings: NotificationSetting,
}

/// 通知设置枚举
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, sqlx::Type)]
#[repr(i32)]
#[sqlx(type_name = "int4")]
pub enum NotificationSetting {
    All = 0,          // 接收所有通知
    MentionsOnly = 1, // 只接收@通知
    Muted = 2,        // 完全静音（免打扰）
}

impl Default for NotificationSetting {
    fn default() -> Self {
        NotificationSetting::All
    }
}

impl fmt::Display for NotificationSetting {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let text = match self {
            NotificationSetting::All => "all",
            NotificationSetting::MentionsOnly => "mentions_only",
            NotificationSetting::Muted => "muted",
        };
        f.write_str(text)
    }
}

/// 成员角色枚举
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, sqlx::Type)]
#[repr(i16)]
#[sqlx(type_name = "int2")]
pub enum MemberRole {
    Owner = 0,  // 房主
    Admin = 1,  // 管理员
    Member = 2, // 普通成员
}

impl Default for MemberRole {
    fn default() -> Self {
        MemberRole::Member
    }
}

impl fmt::Display for MemberRole {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let text = match self {
            MemberRole::Owner => "owner",
            MemberRole::Admin => "admin",
            MemberRole::Member => "member",
        };
        f.write_str(text)
    }
}

/// 消息已读记录模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct MessageRead {
    pub id: Uuid,
    pub message_id: Uuid,
    pub user_id: Uuid,
    pub room_id: Uuid,
    pub read_at: DateTime<Utc>,
}

/// 会话概要信息（用于列表展示）
#[derive(Debug, Clone, FromRow)]
pub struct ChatSummaryRow {
    pub room_id: Uuid,
    pub room_name: String,
    pub room_type: RoomType,
    pub room_description: Option<String>,
    pub room_avatar_url: Option<String>,
    pub is_pinned: bool,
    pub last_message_id: Option<Uuid>,
    pub last_message_content: Option<String>,
    pub last_message_type: Option<MessageType>,
    pub last_message_created_at: Option<DateTime<Utc>>,
    pub last_message_sender_id: Option<Uuid>,
    pub last_message_sender_username: Option<String>,
    pub last_message_sender_nickname: Option<String>,
    pub unread_count: i64,
    pub last_read_message_id: Option<Uuid>,
    pub last_read_at: Option<DateTime<Utc>>,
    pub friend_user_id: Option<Uuid>,
    pub friend_avatar_object_key: Option<String>,
}

/// 好友请求状态
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, sqlx::Type)]
#[repr(i16)]
#[sqlx(type_name = "int2")]
pub enum FriendRequestStatus {
    Pending = 0,
    Accepted = 1,
    Declined = 2,
}

impl fmt::Display for FriendRequestStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let text = match self {
            FriendRequestStatus::Pending => "pending",
            FriendRequestStatus::Accepted => "accepted",
            FriendRequestStatus::Declined => "declined",
        };
        f.write_str(text)
    }
}

/// 好友请求记录
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct AppDocument {
    pub key: String,
    pub title: String,
    pub content: String,
    pub updated_at: DateTime<Utc>,
    pub updated_by: Option<Uuid>,
}

#[derive(Debug, Clone)]
pub struct DocumentUpdate {
    pub title: Option<String>,
    pub content: String,
    pub updated_by: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct CaptchaSettingRecord {
    pub key: String,
    pub enabled: bool,
    pub captcha_code: String,
    pub description: String,
    pub updated_at: DateTime<Utc>,
    pub updated_by: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct FriendRequest {
    pub id: Uuid,
    pub requester_id: Uuid,
    pub addressee_id: Uuid,
    pub status: FriendRequestStatus,
    pub message: Option<String>,
    pub created_at: DateTime<Utc>,
    pub responded_at: Option<DateTime<Utc>>,
}

/// 好友关系记录
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Friendship {
    pub id: Uuid,
    pub user_a_id: Uuid,
    pub user_b_id: Uuid,
    pub created_at: DateTime<Utc>,
}

/// 文件上传提供商类型枚举
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, sqlx::Type)]
#[repr(i16)]
#[sqlx(type_name = "int2")]
pub enum StorageProviderType {
    Unknown = 0,
    TencentCos = 1, // 腾讯云COS
    AliyunOss = 2,  // 阿里云OSS
    AwsS3 = 3,      // AWS S3
    Minio = 4,      // MinIO
}

impl Default for StorageProviderType {
    fn default() -> Self {
        StorageProviderType::Unknown
    }
}

impl fmt::Display for StorageProviderType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let text = match self {
            StorageProviderType::Unknown => "unknown",
            StorageProviderType::TencentCos => "tencent_cos",
            StorageProviderType::AliyunOss => "aliyun_oss",
            StorageProviderType::AwsS3 => "aws_s3",
            StorageProviderType::Minio => "minio",
        };
        f.write_str(text)
    }
}

/// 文件上传提供商配置记录
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct StorageProvider {
    pub id: Uuid,
    pub provider_type: StorageProviderType,
    pub name: String,
    pub secret_id: String,
    pub secret_key: String,
    pub region: String,
    pub endpoint: String,
    pub bucket_name: Option<String>,
    pub is_active: bool,
    pub is_default: bool,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub updated_by: Option<Uuid>,
}

// ===== 群聊管理相关模型 =====

/// 群聊设置
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct GroupSettings {
    pub id: Uuid,
    pub room_id: Uuid,
    pub join_approval_required: bool,
    pub member_can_invite: bool,
    pub member_can_add_friends: bool,
    pub require_admin_to_add_friends: bool,
    pub max_members: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 群公告
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct GroupAnnouncement {
    pub id: Uuid,
    pub room_id: Uuid,
    pub title: String,
    pub content: String,
    pub publisher_id: Uuid,
    pub is_pinned: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 群规
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct GroupRule {
    pub id: Uuid,
    pub room_id: Uuid,
    pub title: String,
    pub content: String,
    pub creator_id: Uuid,
    pub order_index: i32,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 入群申请状态
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, sqlx::Type)]
#[repr(i32)]
#[sqlx(type_name = "int4")]
pub enum JoinRequestStatus {
    Pending = 0,
    Approved = 1,
    Rejected = 2,
}

impl fmt::Display for JoinRequestStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let text = match self {
            JoinRequestStatus::Pending => "pending",
            JoinRequestStatus::Approved => "approved",
            JoinRequestStatus::Rejected => "rejected",
        };
        f.write_str(text)
    }
}

/// 入群申请
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct JoinRequest {
    pub id: Uuid,
    pub room_id: Uuid,
    pub applicant_id: Uuid,
    pub message: Option<String>,
    pub status: JoinRequestStatus,
    pub reviewer_id: Option<Uuid>,
    pub review_message: Option<String>,
    pub created_at: DateTime<Utc>,
    pub reviewed_at: Option<DateTime<Utc>>,
}

/// 群聊邀请状态
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, sqlx::Type)]
#[repr(i32)]
#[sqlx(type_name = "int4")]
pub enum InvitationStatus {
    Pending = 0,
    Accepted = 1,
    Declined = 2,
    Expired = 3,
}

impl fmt::Display for InvitationStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let text = match self {
            InvitationStatus::Pending => "pending",
            InvitationStatus::Accepted => "accepted",
            InvitationStatus::Declined => "declined",
            InvitationStatus::Expired => "expired",
        };
        f.write_str(text)
    }
}

/// 群聊邀请
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct GroupInvitation {
    pub id: Uuid,
    pub room_id: Uuid,
    pub inviter_id: Uuid,
    pub invitee_id: Uuid,
    pub message: Option<String>,
    pub status: InvitationStatus,
    pub invited_at: DateTime<Utc>,
    pub responded_at: Option<DateTime<Utc>>,
    pub expires_at: DateTime<Utc>,
}

/// 群聊管理员
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct GroupAdmin {
    pub id: Uuid,
    pub room_id: Uuid,
    pub admin_id: Uuid,
    pub appointed_by: Uuid,
    pub role: String,
    pub permissions: Option<Vec<String>>,
    pub appointed_at: DateTime<Utc>,
}

/// 群聊操作日志
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct GroupOperationLog {
    pub id: Uuid,
    pub room_id: Uuid,
    pub operator_id: Uuid,
    pub target_user_id: Option<Uuid>,
    pub operation_type: String,
    pub operation_data: Option<Value>,
    pub created_at: DateTime<Utc>,
}

/// 群聊禁言
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct GroupMute {
    pub id: Uuid,
    pub room_id: Uuid,
    pub user_id: Uuid,
    pub muted_by: Uuid,
    pub reason: Option<String>,
    pub mute_duration_hours: i32,
    pub muted_at: DateTime<Utc>,
    pub unmuted_at: Option<DateTime<Utc>>,
    pub is_active: bool,
}

// ===== 群聊管理请求结构体 =====

/// 创建群公告请求
#[derive(Debug, Deserialize)]
pub struct CreateAnnouncementRequest {
    pub title: String,
    pub content: String,
    pub is_pinned: Option<bool>,
}

/// 更新群公告请求
#[derive(Debug, Deserialize)]
pub struct UpdateAnnouncementRequest {
    pub title: Option<String>,
    pub content: Option<String>,
    pub is_pinned: Option<bool>,
}

/// 创建群规请求
#[derive(Debug, Deserialize)]
pub struct CreateRuleRequest {
    pub title: String,
    pub content: String,
    pub order_index: Option<i32>,
}

/// 更新群规请求
#[derive(Debug, Deserialize)]
pub struct UpdateRuleRequest {
    pub title: Option<String>,
    pub content: Option<String>,
    pub order_index: Option<i32>,
    pub is_active: Option<bool>,
}

/// 更新群设置请求
#[derive(Debug, Deserialize)]
pub struct UpdateGroupSettingsRequest {
    pub join_approval_required: Option<bool>,
    pub member_can_invite: Option<bool>,
    pub member_can_add_friends: Option<bool>,
    pub require_admin_to_add_friends: Option<bool>,
    pub max_members: Option<i32>,
}

/// 申请加入群聊请求
#[derive(Debug, Deserialize)]
pub struct JoinGroupRequest {
    pub message: Option<String>,
}

/// 审批入群申请请求
#[derive(Debug, Deserialize, Clone)]
pub struct ReviewJoinRequestRequest {
    pub status: JoinRequestStatus,
    pub review_message: Option<String>,
}

/// 邀请用户加入群聊请求
#[derive(Debug, Deserialize)]
pub struct InviteToGroupRequest {
    pub user_ids: Vec<String>,
    pub message: Option<String>,
}

/// 任命管理员请求
#[derive(Debug, Deserialize)]
pub struct AppointAdminRequest {
    pub user_id: String,
    pub role: String,
    pub permissions: Option<Vec<String>>,
}

/// 禁言用户请求
#[derive(Debug, Deserialize)]
pub struct MuteUserRequest {
    pub user_id: String,
    pub reason: Option<String>,
    pub mute_duration_hours: Option<i32>,
}

/// 群聊详细信息（用于管理后台）
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct GroupDetailInfo {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub avatar_url: Option<String>,
    pub room_type: RoomType,
    pub owner_id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub join_approval_required: bool,
    pub member_can_invite: bool,
    pub member_can_add_friends: bool,
    pub require_admin_to_add_friends: bool,
    pub max_members: i32,
    pub current_member_count: i64,
    pub announcement_count: i64,
    pub pending_request_count: i64,
}
