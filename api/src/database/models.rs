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

/// 管理后台用户状态枚举
#[derive(
    Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, sqlx::Type,
)]
#[repr(i16)]
#[sqlx(type_name = "int2")]
pub enum AdminUserStatus {
    Active = 0,
    Inactive = 1,
    Banned = 2,
    Locked = 3,
}

impl Default for AdminUserStatus {
    fn default() -> Self {
        AdminUserStatus::Active
    }
}

impl Default for UserStatus {
    fn default() -> Self {
        UserStatus::Active
    }
}

/// 管理后台用户表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct AdminUser {
    pub id: Uuid,
    pub username: String,
    pub email: String,
    pub password_hash: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub status: AdminUserStatus,
    pub last_login_at: Option<DateTime<Utc>>,
    pub login_attempts: i16,
    pub locked_until: Option<DateTime<Utc>>,
    pub require_password_change: bool,
    pub password_changed_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}

/// 管理员用户角色关联表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
#[allow(dead_code)]
pub struct AdminUserRole {
    pub id: Uuid,
    pub admin_user_id: Uuid,
    pub role_id: Uuid,
    pub assigned_by: Option<Uuid>,
    pub assigned_at: DateTime<Utc>,
}

/// 管理员登录历史表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
#[allow(dead_code)]
pub struct AdminLoginHistory {
    pub id: Uuid,
    pub admin_user_id: Uuid,
    pub ip_address: Option<std::net::IpAddr>,
    pub user_agent: Option<String>,
    pub login_at: DateTime<Utc>,
    pub logout_at: Option<DateTime<Utc>>,
    pub success: bool,
    pub failure_reason: Option<String>,
}

/// 管理员操作日志表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
#[allow(dead_code)]
pub struct AdminOperationLog {
    pub id: Uuid,
    pub admin_user_id: Option<Uuid>,
    pub operation: String,
    pub resource_type: Option<String>,
    pub resource_id: Option<Uuid>,
    pub details: Option<Value>,
    pub ip_address: Option<std::net::IpAddr>,
    pub user_agent: Option<String>,
    pub created_at: DateTime<Utc>,
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

/// 角色权限关联表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
#[allow(dead_code)]
pub struct RolePermission {
    pub id: Uuid,
    pub role_id: Uuid,
    pub permission_id: Uuid,
    pub created_at: DateTime<Utc>,
}

/// 用户权限枚举（简化版，实际应该从database获取）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[allow(dead_code)]
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
    pub email: String,
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

/// 平台枚举
#[derive(
    Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, sqlx::Type,
)]
#[sqlx(type_name = "text")]
#[serde(rename_all = "lowercase")]
pub enum Platform {
    #[sqlx(rename = "windows")]
    Windows,
    #[sqlx(rename = "macos")]
    MacOS,
    #[sqlx(rename = "ios")]
    IOS,
    #[sqlx(rename = "android")]
    Android,
    #[sqlx(rename = "linux")]
    Linux,
}

impl fmt::Display for Platform {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Platform::Windows => write!(f, "windows"),
            Platform::MacOS => write!(f, "macos"),
            Platform::IOS => write!(f, "ios"),
            Platform::Android => write!(f, "android"),
            Platform::Linux => write!(f, "linux"),
        }
    }
}

impl Platform {
    pub fn as_str(&self) -> &'static str {
        match self {
            Platform::Windows => "windows",
            Platform::MacOS => "macos",
            Platform::IOS => "ios",
            Platform::Android => "android",
            Platform::Linux => "linux",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "windows" => Some(Platform::Windows),
            "macos" => Some(Platform::MacOS),
            "ios" => Some(Platform::IOS),
            "android" => Some(Platform::Android),
            "linux" => Some(Platform::Linux),
            _ => None,
        }
    }
}

/// 应用版本记录
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct AppVersion {
    pub id: Uuid,
    pub platform: Platform,
    pub version: String,
    pub build_number: i32,
    pub channel: String,
    pub download_key: String,
    pub download_url: Option<String>,
    pub app_store_url: Option<String>,
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

/// 热更新补丁记录（Flutter 移动端专用）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct HotUpdate {
    pub id: Uuid,
    pub platform: Platform,
    pub app_version_id: Uuid,
    pub patch_version: String,
    pub channel: String,
    pub download_key: String,
    pub download_url: Option<String>,
    pub file_size: Option<i64>,
    pub checksum: Option<String>,
    pub signature: Option<String>,
    pub rollout_percentage: i32,
    pub mandatory: bool,
    pub description: Option<String>,
    pub is_active: bool,
    pub released_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub created_by: Option<Uuid>,
    pub updated_by: Option<Uuid>,
}

/// 热更新事件记录
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct HotUpdateEvent {
    pub id: Uuid,
    pub platform: Platform,
    pub channel: Option<String>,
    pub base_version: String,
    pub patch_version: String,
    pub event_type: String,
    pub client_id: Option<String>,
    pub message: Option<String>,
    pub created_at: DateTime<Utc>,
    // 新增的详细字段
    pub client_type: Option<String>,
    pub os_version: Option<String>,
    pub os_arch: Option<String>,
    pub app_arch: Option<String>,
    pub build_number: Option<i32>,
    pub trigger_source: Option<String>,
    pub network_type: Option<String>,
    pub device_info: Option<String>,
}

/// 房间表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Room {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub avatar_url: Option<String>,
    pub avatar_object_key: Option<String>,
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
    pub encrypted_content: Option<Vec<u8>>,
    pub encryption_metadata: Option<Value>,
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
    pub encrypted_content: Option<Vec<u8>>,
    pub encryption_metadata: Option<Value>,
    pub message_type: MessageType,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub edited_at: Option<DateTime<Utc>>,
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

/// 当前用户联系人群目录的查询行。
#[derive(Debug, Clone, FromRow)]
pub struct GroupDirectoryRow {
    pub room_id: Uuid,
    pub room_name: String,
    pub room_description: Option<String>,
    pub room_avatar_url: Option<String>,
    pub room_avatar_object_key: Option<String>,
    pub member_count: i64,
    pub group_directory_favorited_at: Option<DateTime<Utc>>,
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

/// 包含用户信息的房间成员（用于 API 返回）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
#[allow(dead_code)]
pub struct RoomMemberWithUserInfo {
    pub user_id: Uuid,
    pub username: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub role: MemberRole,
    pub joined_at: Option<DateTime<Utc>>,
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
#[serde(rename_all = "lowercase")]
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

/// 消息反应表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct MessageReaction {
    pub id: Uuid,
    pub message_id: Uuid,
    pub user_id: Uuid,
    pub reaction_key: String,
    pub created_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}

/// 消息反应聚合结果（用于 API 返回）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageReactionSummary {
    pub reaction_key: String,
    pub count: i64,
    pub user_ids: Vec<Uuid>,
    pub has_self: bool,
}

/// Push 设备记录（用于离线推送）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct PushDevice {
    pub id: Uuid,
    pub user_id: Uuid,
    pub platform: String,
    pub channel: String,
    pub device_id: String,
    pub device_token: String,
    pub is_active: bool,
    pub last_seen_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Push 平台配置（由管理后台维护）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct PushProviderConfig {
    pub id: Uuid,
    pub provider: String,
    pub platform: String,
    pub enabled: bool,
    pub config_public: Value,
    pub secret_ciphertext: Option<String>,
    pub secret_fingerprint: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub updated_by: Option<Uuid>,
}

/// E2EE 身份公钥（每设备一份）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct E2eeIdentityKey {
    pub user_id: Uuid,
    pub device_id: String,
    pub public_key: Vec<u8>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// E2EE 签名预密钥（Signed Pre-Key）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct E2eeSignedPreKey {
    pub id: Uuid,
    pub user_id: Uuid,
    pub device_id: String,
    pub key_id: i32,
    pub public_key: Vec<u8>,
    pub signature: Vec<u8>,
    pub expires_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}

/// E2EE 一次性预密钥（One-Time Pre-Key）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct E2eeOneTimePreKey {
    pub id: Uuid,
    pub user_id: Uuid,
    pub device_id: String,
    pub key_id: i32,
    pub public_key: Vec<u8>,
    pub is_used: bool,
    pub used_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
}

/// 会话概要信息（用于列表展示）
#[derive(Debug, Clone, FromRow)]
pub struct ChatSummaryRow {
    pub room_id: Uuid,
    pub room_name: String,
    pub room_type: RoomType,
    pub room_description: Option<String>,
    pub room_avatar_url: Option<String>,
    pub room_avatar_object_key: Option<String>,
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
    pub notification_settings: NotificationSetting,
    pub friend_user_id: Option<Uuid>,
    pub friend_nickname: Option<String>,
    pub friend_username: Option<String>,
    pub friend_remark: Option<String>,
    pub friend_avatar_object_key: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
#[allow(dead_code)]
pub struct UserFriendRemark {
    pub id: Uuid,
    pub user_id: Uuid,
    pub friend_user_id: Uuid,
    pub remark: String,
    pub updated_at: DateTime<Utc>,
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
    pub require_captcha_for_login: bool,
    pub updated_at: DateTime<Utc>,
    pub updated_by: Option<Uuid>,
}

/// 通用设置记录
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct GeneralSettingRecord {
    pub key: String,
    pub value: String,
    pub description: String,
    pub updated_at: DateTime<Utc>,
    pub updated_by: Option<Uuid>,
}

/// 用户账号限制设置记录
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct UserAccountLimitRecord {
    pub id: i32,
    pub enable_phone_validation: bool,
    pub enable_email_validation: bool,
    pub enable_length_validation: bool,
    pub min_length: i32,
    pub max_length: i32,
    pub enable_alphanumeric_validation: bool,
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
    S3Compatible = 5, // S3 兼容对象存储
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
            StorageProviderType::S3Compatible => "s3_compatible",
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

/// 对象存储运行时配置版本记录
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct ObjectStorageConfigRecord {
    pub id: Uuid,
    pub provider: String,
    pub endpoint: Option<String>,
    pub region: String,
    pub encrypted_key_id: Option<String>,
    pub encrypted_application_key: Option<String>,
    pub private_bucket: String,
    pub public_bucket: Option<String>,
    pub public_base_url: Option<String>,
    pub upload_url_ttl_seconds: i32,
    pub download_url_ttl_seconds: i32,
    pub version: i32,
    pub status: String,
    pub rollback_source_version: Option<i32>,
    pub change_note: Option<String>,
    pub created_by: Option<String>,
    pub applied_by: Option<String>,
    pub activated_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 文件上传记录（统一管理通过对象存储直传的文件）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct FileUploadRecord {
    pub id: Uuid,
    pub storage_provider_id: Uuid,
    pub object_key: String,
    pub hash_alg: i16,
    pub hash_value: String,
    pub file_size: Option<i64>,
    pub content_type: Option<String>,
    pub status: i16,
    pub uploaded_at: Option<DateTime<Utc>>,
    pub updated_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub last_error: Option<String>,
}

/// 大文件分片直传会话（对象存储 Multipart Upload）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct FileUploadMultipartSession {
    pub id: Uuid,
    pub storage_provider_id: Uuid,
    pub object_key: String,
    pub upload_id: String,
    pub creator_id: Uuid,
    pub creator_is_admin: bool,
    pub file_size: Option<i64>,
    pub content_type: Option<String>,
    pub part_size: i32,
    pub total_parts: i32,
    pub uploaded_parts: Value,
    pub status: i16,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub completed_at: Option<DateTime<Utc>>,
}

/// 文件内容审核任务（对象存储可达性审核）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct FileUploadAuditTask {
    pub id: Uuid,
    pub storage_provider_id: Uuid,
    pub object_key: String,
    pub scene: String,
    pub media_kind: String,
    pub content_type: Option<String>,
    pub file_size: Option<i64>,
    pub status: i16,
    pub vendor_job_id: Option<String>,
    pub result: Value,
    pub rejected_reason: Option<String>,
    pub attempts: i32,
    pub next_run_at: DateTime<Utc>,
    pub last_error: Option<String>,
    pub audited_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
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
    pub global_mute_enabled: bool,
    pub global_mute_until: Option<DateTime<Utc>>,
    pub global_mute_reason: Option<String>,
    pub global_mute_set_by: Option<Uuid>,
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
///
/// 说明：
/// - DB 中存储为 int4（0/1/2）
/// - API JSON 序列化为数字（兼容客户端的 int 映射）
/// - 反序列化同时兼容数字与字符串（pending/approved/rejected，大小写不敏感）
#[derive(Debug, Clone, Copy, PartialEq, Eq, sqlx::Type)]
#[repr(i32)]
#[sqlx(type_name = "int4")]
pub enum JoinRequestStatus {
    Pending = 0,
    Approved = 1,
    Rejected = 2,
}

impl Serialize for JoinRequestStatus {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_i32(*self as i32)
    }
}

impl<'de> Deserialize<'de> for JoinRequestStatus {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        struct JoinRequestStatusVisitor;

        impl<'de> serde::de::Visitor<'de> for JoinRequestStatusVisitor {
            type Value = JoinRequestStatus;

            fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
                formatter.write_str("join request status (0/1/2 or pending/approved/rejected)")
            }

            fn visit_i64<E>(self, value: i64) -> Result<Self::Value, E>
            where
                E: serde::de::Error,
            {
                match value {
                    0 => Ok(JoinRequestStatus::Pending),
                    1 => Ok(JoinRequestStatus::Approved),
                    2 => Ok(JoinRequestStatus::Rejected),
                    _ => Err(E::custom(format!("invalid join request status: {}", value))),
                }
            }

            fn visit_u64<E>(self, value: u64) -> Result<Self::Value, E>
            where
                E: serde::de::Error,
            {
                match value {
                    0 => Ok(JoinRequestStatus::Pending),
                    1 => Ok(JoinRequestStatus::Approved),
                    2 => Ok(JoinRequestStatus::Rejected),
                    _ => Err(E::custom(format!("invalid join request status: {}", value))),
                }
            }

            fn visit_str<E>(self, value: &str) -> Result<Self::Value, E>
            where
                E: serde::de::Error,
            {
                let normalized = value.trim().to_ascii_lowercase();
                match normalized.as_str() {
                    "pending" | "0" => Ok(JoinRequestStatus::Pending),
                    "approved" | "1" => Ok(JoinRequestStatus::Approved),
                    "rejected" | "2" => Ok(JoinRequestStatus::Rejected),
                    _ => Err(E::custom(format!("invalid join request status: {}", value))),
                }
            }
        }

        deserializer.deserialize_any(JoinRequestStatusVisitor)
    }
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
///
/// 说明：
/// - DB 中存储为 int4（0/1/2/3）
/// - API JSON 序列化为数字
/// - 反序列化同时兼容数字与字符串（pending/accepted/declined/expired，大小写不敏感）
#[derive(Debug, Clone, Copy, PartialEq, Eq, sqlx::Type)]
#[repr(i32)]
#[sqlx(type_name = "int4")]
pub enum InvitationStatus {
    Pending = 0,
    Accepted = 1,
    Declined = 2,
    Expired = 3,
}

impl Serialize for InvitationStatus {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_i32(*self as i32)
    }
}

impl<'de> Deserialize<'de> for InvitationStatus {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        struct InvitationStatusVisitor;

        impl<'de> serde::de::Visitor<'de> for InvitationStatusVisitor {
            type Value = InvitationStatus;

            fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
                formatter
                    .write_str("invitation status (0/1/2/3 or pending/accepted/declined/expired)")
            }

            fn visit_i64<E>(self, value: i64) -> Result<Self::Value, E>
            where
                E: serde::de::Error,
            {
                match value {
                    0 => Ok(InvitationStatus::Pending),
                    1 => Ok(InvitationStatus::Accepted),
                    2 => Ok(InvitationStatus::Declined),
                    3 => Ok(InvitationStatus::Expired),
                    _ => Err(E::custom(format!("invalid invitation status: {}", value))),
                }
            }

            fn visit_u64<E>(self, value: u64) -> Result<Self::Value, E>
            where
                E: serde::de::Error,
            {
                match value {
                    0 => Ok(InvitationStatus::Pending),
                    1 => Ok(InvitationStatus::Accepted),
                    2 => Ok(InvitationStatus::Declined),
                    3 => Ok(InvitationStatus::Expired),
                    _ => Err(E::custom(format!("invalid invitation status: {}", value))),
                }
            }

            fn visit_str<E>(self, value: &str) -> Result<Self::Value, E>
            where
                E: serde::de::Error,
            {
                let normalized = value.trim().to_ascii_lowercase();
                match normalized.as_str() {
                    "pending" | "0" => Ok(InvitationStatus::Pending),
                    "accepted" | "1" => Ok(InvitationStatus::Accepted),
                    "declined" | "2" => Ok(InvitationStatus::Declined),
                    "expired" | "3" => Ok(InvitationStatus::Expired),
                    _ => Err(E::custom(format!("invalid invitation status: {}", value))),
                }
            }
        }

        deserializer.deserialize_any(InvitationStatusVisitor)
    }
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
    #[serde(alias = "duration_hours")]
    pub mute_duration_hours: Option<i32>,
}

/// 群聊详细信息（用于管理后台）
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct GroupDetailInfo {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub avatar_url: Option<String>,
    pub avatar_object_key: Option<String>,
    pub room_type: RoomType,
    pub owner_id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub join_approval_required: bool,
    pub member_can_invite: bool,
    pub member_can_add_friends: bool,
    pub require_admin_to_add_friends: bool,
    pub max_members: i32,
    pub global_mute_enabled: bool,
    pub global_mute_until: Option<DateTime<Utc>>,
    pub global_mute_reason: Option<String>,
    pub global_mute_set_by: Option<Uuid>,
    pub current_member_count: i64,
    pub pending_request_count: i64,
}

// ===== 贴纸相关模型 =====

/// 贴纸状态枚举
#[derive(
    Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, sqlx::Type,
)]
#[repr(i16)]
#[sqlx(type_name = "int2")]
pub enum EmojiPackStatus {
    Inactive = 0,
    Active = 1,
}

impl Default for EmojiPackStatus {
    fn default() -> Self {
        EmojiPackStatus::Active
    }
}

/// 贴纸类型枚举
#[derive(
    Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, sqlx::Type,
)]
#[repr(i16)]
#[sqlx(type_name = "int2")]
pub enum EmojiPackType {
    Single = 0, // 单个贴纸
    Suite = 1,  // 贴纸包（系列）
}

impl Default for EmojiPackType {
    fn default() -> Self {
        EmojiPackType::Single
    }
}

/// 贴纸表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct EmojiPack {
    pub id: Uuid,
    pub name: String,
    pub icon_url: Option<String>,
    /// 对象键（用于生成临时下载地址）
    pub icon_object_key: Option<String>,
    pub description: Option<String>,
    pub is_active: EmojiPackStatus,
    pub pack_type: EmojiPackType,
    pub parent_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 表情项表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct EmojiItem {
    pub id: Uuid,
    pub pack_id: Uuid,
    pub image_url: String,
    /// 对象键（用于生成临时下载地址）
    pub image_object_key: Option<String>,
    pub name: Option<String>,
    pub sort_order: i32,
    pub created_at: DateTime<Utc>,
}

/// 用户贴纸关联表模型
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct UserEmojiPack {
    pub user_id: Uuid,
    pub pack_id: Uuid,
    pub created_at: DateTime<Utc>,
}

/// 创建贴纸请求
#[derive(Debug, Deserialize)]
pub struct CreateEmojiPackRequest {
    pub name: String,
    pub icon_url: Option<String>,
    /// 对象键（可选，若传入则优先作为下载地址生成依据）
    pub icon_object_key: Option<String>,
    pub description: Option<String>,
    pub is_active: Option<bool>,
    pub pack_type: Option<i16>,    // 0=单个, 1=贴纸包
    pub parent_id: Option<String>, // 贴纸包下的贴纸需要指定父贴纸包ID
}

/// 更新贴纸请求
#[derive(Debug, Deserialize)]
pub struct UpdateEmojiPackRequest {
    pub name: Option<String>,
    pub icon_url: Option<String>,
    /// 对象键（可选）
    pub icon_object_key: Option<String>,
    pub description: Option<String>,
    pub is_active: Option<bool>,
    pub pack_type: Option<i16>,
    pub parent_id: Option<String>,
}

/// 创建表情项请求
#[derive(Debug, Deserialize)]
pub struct CreateEmojiItemRequest {
    pub pack_id: String,
    pub image_url: String,
    /// 对象键（可选）
    pub image_object_key: Option<String>,
    pub name: Option<String>,
    pub sort_order: Option<i32>,
}

/// 更新表情项请求
#[derive(Debug, Deserialize)]
pub struct UpdateEmojiItemRequest {
    pub image_url: Option<String>,
    /// 对象键（可选）
    pub image_object_key: Option<String>,
    pub name: Option<String>,
    pub sort_order: Option<i32>,
}
