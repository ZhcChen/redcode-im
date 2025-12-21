use axum::{
    middleware,
    routing::{delete, get, patch, post, put},
    Router,
};

use crate::auth::{admin_only_middleware, auth_middleware};
use crate::handlers::{
    activity_logs, admin, auth, chat_history, emoji_pack, feedback, friend, group_management,
    health, healthz, message, message_read, message_search, multipart_upload, report, room, root,
    settings, user, version, ws,
};
use crate::AppState;

pub fn create_routes() -> Router<AppState> {
    // 公开路由
    let public_routes = Router::new()
        .route("/", get(root))
        .route("/healthz", get(healthz))
        .route("/readyz", get(health::readyz))
        .route("/ws", get(ws))
        .route("/versions/latest", get(version::latest_version))
        .route(
            "/versions/latest/download-url",
            get(version::download_latest_version),
        )
        .route("/versions/hot-update", get(version::latest_hot_update))
        .route("/versions/download", get(version::download_version))
        .route(
            "/versions/hot-update/download",
            get(version::download_hot_update),
        )
        .route(
            "/versions/hot-update/report",
            post(version::report_hot_update_event),
        )
        // 兼容旧客户端（桌面端/移动端）上报路径
        .route(
            "/versions/hot-update-events",
            post(version::report_hot_update_event),
        )
        .route("/auth/register", post(auth::register))
        .route("/auth/login", post(auth::login))
        .route("/auth/login/sms", post(auth::login_with_sms))
        .route("/auth/refresh", post(auth::refresh_token))
        .route("/auth/sms/send", post(auth::send_login_sms))
        .route("/auth/admin/login", post(auth::admin_login))
        .route("/auth/admin/refresh", post(auth::admin_refresh_token))
        .route(
            "/settings/privacy-policy",
            get(settings::get_privacy_policy),
        )
        .route(
            "/settings/user-agreement",
            get(settings::get_user_agreement),
        )
        .route("/settings/general", get(settings::get_general_settings))
        .route("/settings/app-name", get(settings::get_app_name))
        .route(
            "/settings/captcha",
            get(settings::get_captcha_setting_public),
        )
        // 临时API：创建默认管理员用户（仅用于初始化）
        .route(
            "/api/admin/init-default-admin",
            post(admin::create_default_admin_user),
        )
        // 临时API：检查管理员用户
        .route(
            "/api/admin/check-admin-users",
            get(admin::check_admin_users),
        )
        // 临时API：重置管理员密码
        .route(
            "/api/admin/reset-admin-password",
            post(admin::reset_admin_password),
        );

    // 需要认证且必须是管理员 Token 的路由
    //
    // 注意：layer 的调用顺序是“后调用的在最外层”，所以这里把 auth_middleware 放在最后，
    // 以确保先完成鉴权并注入 Claims，再由 admin_only_middleware 校验 is_admin。
    let admin_routes = Router::new()
        .route(
            "/auth/admin/me",
            get(auth::get_current_admin_user).patch(auth::update_current_admin_user),
        )
        .route(
            "/auth/admin/me/password",
            post(auth::change_current_admin_password),
        )
        // admin APIs
        .route("/api/dashboard/stats", get(admin::get_dashboard_stats))
        .route(
            "/api/dashboard/storage-stats",
            get(admin::get_dashboard_storage_stats),
        )
        .route(
            "/api/dashboard/emoji-stats",
            get(admin::get_dashboard_emoji_stats),
        )
        .route("/api/dashboard/monitor", get(admin::get_system_monitor))
        .route("/api/admin/nodes/monitor", get(admin::list_active_nodes_monitor))
        .route("/api/dashboard/statistics", get(admin::get_data_statistics))
        .route("/api/admin/users", get(admin::get_user_list))
        .route("/api/admin/users", post(admin::create_user))
        .route(
            "/api/admin/users/{user_id}",
            get(admin::get_user_detail)
                .patch(admin::update_user)
                .delete(admin::delete_user),
        )
        .route(
            "/api/admin/users/{user_id}/password/reset",
            post(admin::reset_user_password),
        )
        .route(
            "/api/admin/users/{user_id}/status",
            patch(admin::update_user_status),
        )
        .route("/api/admin/feedbacks", get(admin::list_feedbacks))
        .route("/api/admin/reports", get(report::list_reports_admin))
        // 权限管理API
        .route("/api/admin/permissions", get(admin::get_permissions))
        .route("/api/admin/roles", get(admin::get_roles))
        .route("/api/admin/roles", post(admin::create_role))
        .route(
            "/api/admin/roles/{role_id}",
            patch(admin::update_role).delete(admin::delete_role),
        )
        .route(
            "/api/admin/permissions/check",
            post(admin::check_user_permission),
        )
        // 管理员用户管理API
        .route("/api/admin/admin-users", get(admin::get_admin_user_list))
        .route("/api/admin/admin-users", post(admin::create_admin_user))
        .route(
            "/api/admin/admin-users/{admin_user_id}/status",
            patch(admin::update_admin_user_status),
        )
        // 文件管理和存储统计API
        .route(
            "/api/admin/files/stats",
            get(admin::get_file_management_stats),
        )
        .route("/api/admin/files", get(admin::get_file_list))
        .route("/api/admin/files/{file_id}", delete(admin::delete_file))
        .route(
            "/api/admin/files/batch-delete",
            post(admin::delete_files_batch),
        )
        .route(
            "/api/admin/settings/captcha",
            get(admin::get_captcha_setting).post(admin::update_captcha_setting),
        )
        .route(
            "/api/admin/settings/privacy-policy",
            get(settings::get_privacy_policy_admin).post(settings::update_privacy_policy),
        )
        .route(
            "/api/admin/settings/user-agreement",
            get(settings::get_user_agreement_admin).post(settings::update_user_agreement),
        )
        .route(
            "/api/admin/settings/app-name",
            put(settings::update_app_name),
        )
        .route(
            "/api/admin/settings/user-account-limit",
            get(settings::get_user_account_limit).put(settings::update_user_account_limit),
        )
        .route(
            "/api/admin/storage-providers",
            get(admin::list_storage_providers).post(admin::create_storage_provider),
        )
        .route(
            "/api/admin/storage-providers/default",
            get(admin::get_default_storage_provider),
        )
        .route(
            "/api/admin/storage-providers/{provider_id}",
            axum::routing::patch(admin::update_storage_provider)
                .delete(admin::delete_storage_provider),
        )
        .route(
            "/api/admin/storage-providers/test/upload",
            post(admin::test_cos_upload),
        )
        .route(
            "/api/admin/storage-providers/test/upload/signature",
            post(admin::test_cos_upload_signature),
        )
        .route(
            "/api/admin/storage-providers/test/upload/multipart/initiate",
            post(admin::test_cos_upload_multipart_initiate),
        )
        .route(
            "/api/admin/storage-providers/test/download-url",
            post(admin::test_cos_download_url),
        )
        .route(
            "/api/admin/storage-providers/test/cors/list",
            post(admin::test_cos_get_cors),
        )
        .route(
            "/api/admin/storage-providers/test/cors",
            post(admin::test_cos_set_cors),
        )
        .route(
            "/api/admin/storage-providers/test/delete",
            post(admin::test_cos_delete),
        )
        .route(
            "/api/admin/storage-providers/test/exists",
            post(admin::test_cos_exists),
        )
        .route(
            "/api/admin/storage-providers/test/buckets",
            post(admin::test_cos_list_buckets),
        )
        .route(
            "/api/admin/storage-providers/test/buckets/create",
            post(admin::test_cos_create_bucket),
        )
        .route(
            "/api/admin/app-versions/upload/signature",
            post(version::generate_version_upload_signature),
        )
        .route(
            "/api/admin/app-versions/upload/multipart/initiate",
            post(version::initiate_version_multipart_upload),
        )
        // COS 大文件分片直传（管理员）
        .route(
            "/api/admin/uploads/multipart/sessions/{session_id}",
            get(multipart_upload::get_multipart_session),
        )
        .route(
            "/api/admin/uploads/multipart/sessions/{session_id}/parts/signature",
            post(multipart_upload::generate_multipart_part_signature),
        )
        .route(
            "/api/admin/uploads/multipart/sessions/{session_id}/parts/commit",
            post(multipart_upload::commit_multipart_part),
        )
        .route(
            "/api/admin/uploads/multipart/sessions/{session_id}/complete",
            post(multipart_upload::complete_multipart_upload),
        )
        .route(
            "/api/admin/uploads/multipart/sessions/{session_id}/abort",
            post(multipart_upload::abort_multipart_upload),
        )
        .route(
            "/api/admin/app-versions",
            get(version::list_app_versions).post(version::create_app_version),
        )
        .route(
            "/api/admin/app-versions/{id}",
            get(version::get_app_version)
                .patch(version::update_app_version)
                .delete(version::delete_app_version),
        )
        .route(
            "/api/admin/app-versions/{id}/deactivate",
            post(version::deactivate_app_version),
        )
        .route(
            "/api/admin/hot-updates",
            get(version::list_hot_updates).post(version::create_hot_update),
        )
        .route(
            "/api/admin/hot-updates/events",
            get(version::list_hot_update_events),
        )
        .route(
            "/api/admin/hot-updates/{id}",
            get(version::get_hot_update)
                .patch(version::update_hot_update)
                .delete(version::delete_hot_update),
        )
        .route(
            "/api/admin/hot-updates/{id}/activate",
            post(version::activate_hot_update),
        )
        .route(
            "/api/admin/hot-updates/{id}/deactivate",
            post(version::deactivate_hot_update),
        )
        // ipinfo Token管理API
        .route(
            "/api/admin/ipinfo-tokens",
            get(admin::get_token_list).post(admin::create_token),
        )
        .route(
            "/api/admin/ipinfo-tokens/{token_id}",
            get(admin::get_token_list)
                .patch(admin::update_token)
                .delete(admin::delete_token),
        )
        .route(
            "/api/admin/ipinfo-tokens/{token_id}/reset",
            post(admin::reset_token_usage),
        )
        // 地理位置API测试
        .route(
            "/api/admin/test-geolocation-api",
            post(admin::test_geolocation_api),
        )
        // 数据清理API（仅限开发环境）
        .route("/admin/data/cleanup/all", post(admin::cleanup_all_app_data))
        // IP地理位置解析开关管理API
        .route(
            "/api/admin/ip-geolocation/enabled",
            get(admin::get_ip_geolocation_enabled).patch(admin::set_ip_geolocation_enabled),
        )
        // 系统日志管理API
        .route("/api/admin/logs", get(admin::list_system_logs))
        .route("/api/admin/logs/stats", get(admin::get_system_log_stats))
        .route(
            "/api/admin/logs/cleanup",
            post(admin::cleanup_system_logs),
        )
        // 聊天记录管理API
        .route(
            "/api/admin/chat-history",
            get(chat_history::get_chat_history),
        )
        .route(
            "/api/admin/users/{user_id}/rooms",
            get(chat_history::get_user_rooms),
        )
        .route(
            "/api/admin/rooms/{room_id}/chat-history",
            get(chat_history::get_room_chat_history),
        )
        .route(
            "/api/admin/users/geolocation/distribution",
            get(activity_logs::get_global_user_distribution),
        )
        // 贴纸管理 API（管理员）
        .route(
            "/api/admin/emoji-packs",
            get(emoji_pack::list_all_packs).post(emoji_pack::create_pack),
        )
        .route(
            "/api/admin/emoji-packs/{pack_id}",
            get(emoji_pack::get_pack)
                .patch(emoji_pack::update_pack)
                .delete(emoji_pack::delete_pack),
        )
        .route("/api/admin/emoji-items", post(emoji_pack::create_item))
        .route(
            "/api/admin/emoji-items/{item_id}",
            get(emoji_pack::get_item)
                .patch(emoji_pack::update_item)
                .delete(emoji_pack::delete_item),
        )
        .layer(middleware::from_fn(admin_only_middleware))
        .layer(middleware::from_fn(auth_middleware));

    // 需要认证的路由（普通用户）
    let user_routes = Router::new()
        .route("/auth/me", get(auth::get_current_user))
        .route("/auth/password/reset", post(auth::reset_password_with_sms))
        .route("/feedbacks", post(feedback::submit_feedback))
        // 举报（群聊/用户）
        .route(
            "/reports/attachments/signature",
            post(report::generate_report_attachment_signature),
        )
        .route(
            "/reports/attachments/commit",
            post(report::commit_report_attachment_upload),
        )
        // COS 大文件分片直传（普通用户）
        .route(
            "/uploads/multipart/sessions/{session_id}",
            get(multipart_upload::get_multipart_session),
        )
        .route(
            "/uploads/multipart/sessions/{session_id}/parts/signature",
            post(multipart_upload::generate_multipart_part_signature),
        )
        .route(
            "/uploads/multipart/sessions/{session_id}/parts/commit",
            post(multipart_upload::commit_multipart_part),
        )
        .route(
            "/uploads/multipart/sessions/{session_id}/complete",
            post(multipart_upload::complete_multipart_upload),
        )
        .route(
            "/uploads/multipart/sessions/{session_id}/abort",
            post(multipart_upload::abort_multipart_upload),
        )
        .route("/reports", post(report::create_report))
        // activity logs
        .route(
            "/activity/heartbeat",
            post(activity_logs::create_heartbeat_log),
        )
        .route("/activity/login", post(activity_logs::create_login_history))
        .route(
            "/activity/login/{log_id}/logout",
            post(activity_logs::update_login_logout),
        )
        .route(
            "/users/{user_id}/activity/login-history",
            get(activity_logs::get_user_login_history),
        )
        .route(
            "/users/{user_id}/activity/heartbeat-logs",
            get(activity_logs::get_user_heartbeat_logs),
        )
        .route(
            "/users/{user_id}/geolocation",
            get(activity_logs::get_user_geolocation),
        )
        // users
        .route("/users/search", get(user::search_users))
        .route(
            "/users/me",
            patch(user::update_me).delete(user::deactivate_me),
        )
        .route("/users/me/password", post(user::change_password))
        .route(
            "/users/me/avatar/direct-upload",
            post(user::generate_avatar_direct_upload),
        )
        .route("/users/me/avatar/commit", post(user::commit_avatar_upload))
        .route("/users/me/avatar/url", get(user::get_avatar_download_url))
        .route("/users/{user_id}", get(user::get_user_by_id))
        .route(
            "/users/{user_id}/avatar/url",
            get(user::get_user_avatar_download_url),
        )
        // friends
        .route(
            "/friends/requests",
            get(friend::list_friend_requests).post(friend::create_friend_request),
        )
        .route("/friends", get(friend::list_friends))
        .route(
            "/friends/requests/{request_id}/respond",
            post(friend::respond_friend_request),
        )
        .route(
            "/friends/{friend_user_id}/chat",
            post(friend::ensure_private_chat),
        )
        .route(
            "/friends/{friend_user_id}/remark",
            patch(friend::update_friend_remark),
        )
        .route("/friends/{friend_user_id}", delete(friend::delete_friend))
        // chats
        .route("/chats", get(room::list_chat_summaries))
        .route("/chats/{room_id}", delete(room::delete_chat))
        // rooms
        .route("/rooms", post(room::create_room).get(room::list_my_rooms))
        .route("/rooms/{room_id}/join", post(room::join_room))
        .route("/rooms/{room_id}/leave", post(room::leave_room))
        .route(
            "/rooms/{room_id}/members",
            get(room::list_members).post(group_management::add_group_members),
        )
        .route(
            "/rooms/{room_id}/members/add",
            post(group_management::add_group_members),
        )
        .route(
            "/rooms/{room_id}/members/{user_id}",
            delete(group_management::remove_group_member),
        )
        .route(
            "/rooms/{room_id}",
            get(room::get_room)
                .patch(room::update_room)
                .delete(room::dissolve_room),
        )
        .route("/rooms/{room_id}/transfer", post(room::transfer_room_owner))
        .route(
            "/rooms/{room_id}/avatar/direct-upload",
            post(room::generate_room_avatar_direct_upload),
        )
        .route(
            "/rooms/{room_id}/avatar/commit",
            post(room::commit_room_avatar_upload),
        )
        .route(
            "/rooms/{room_id}/avatar/url",
            get(room::get_room_avatar_download_url),
        )
        .route(
            "/rooms/{room_id}/notification-settings",
            post(room::update_notification_settings),
        )
        .route(
            "/rooms/{room_id}/pin",
            post(room::pin_room).delete(room::unpin_room),
        )
        .route(
            "/rooms/{room_id}/messages",
            post(message::send_message)
                .get(message::list_messages)
                .delete(message::clear_room_messages),
        )
        .route(
            "/rooms/{room_id}/messages/attachments/signature",
            post(message::generate_message_attachment_signature),
        )
        .route(
            "/rooms/{room_id}/messages/attachments/multipart/initiate",
            post(message::initiate_message_attachment_multipart_upload),
        )
        .route(
            "/rooms/{room_id}/messages/attachments/commit",
            post(message::commit_message_attachment_upload),
        )
        .route(
            "/rooms/{room_id}/messages/attachments/download",
            get(message::generate_message_attachment_download_url),
        )
        .route(
            "/rooms/{room_id}/messages/forward",
            post(message::forward_message),
        )
        // message reads
        .route(
            "/rooms/{room_id}/messages/read",
            post(message_read::mark_message_read),
        )
        .route(
            "/rooms/{room_id}/messages/read_until",
            post(message_read::mark_messages_read_until),
        )
        .route(
            "/rooms/{room_id}/messages/{message_id}/pin",
            post(message::pin_message).delete(message::unpin_message),
        )
        .route(
            "/rooms/{room_id}/messages/{message_id}",
            delete(message::delete_message),
        )
        .route(
            "/rooms/{room_id}/messages/{message_id}/reads",
            get(message_read::get_message_read_list),
        )
        .route(
            "/rooms/{room_id}/unread_count",
            get(message_read::get_unread_count),
        )
        .route("/unread_counts", get(message_read::get_all_unread_counts))
        // 消息搜索 API
        .route("/messages/search", get(message_search::search_messages))
        .route(
            "/messages/search/suggestions",
            get(message_search::get_search_suggestions),
        )
        .route(
            "/messages/search/trending",
            get(message_search::get_trending_keywords),
        )
        // 群聊管理 API
        .route(
            "/rooms/{room_id}/settings",
            get(group_management::get_group_settings)
                .patch(group_management::update_group_settings),
        )
        .route(
            "/rooms/{room_id}/rules",
            get(group_management::list_rules).post(group_management::create_rule),
        )
        .route(
            "/rooms/{room_id}/rules/{rule_id}",
            patch(group_management::update_rule).delete(group_management::delete_rule),
        )
        .route(
            "/rooms/{room_id}/join-requests",
            get(group_management::list_join_requests).post(group_management::create_join_request),
        )
        .route(
            "/rooms/{room_id}/join-requests/{request_id}/review",
            patch(group_management::review_join_request),
        )
        .route(
            "/rooms/{room_id}/invitations",
            post(group_management::create_invitations),
        )
        .route(
            "/rooms/{room_id}/invitations/{invitation_id}/respond",
            patch(group_management::respond_to_invitation),
        )
        .route(
            "/rooms/{room_id}/admins",
            get(group_management::list_admins).post(group_management::appoint_admin),
        )
        .route(
            "/rooms/{room_id}/admins/{admin_id}",
            delete(group_management::remove_admin),
        )
        .route(
            "/rooms/{room_id}/mutes",
            post(group_management::mute_user).get(group_management::list_muted_users),
        )
        .route(
            "/rooms/{room_id}/mutes/global",
            post(group_management::update_global_mute),
        )
        .route(
            "/rooms/{room_id}/mutes/{muted_user_id}",
            delete(group_management::unmute_user),
        )
        .route(
            "/rooms/{room_id}/operation-logs",
            get(group_management::list_operation_logs),
        )
        .route(
            "/rooms/{room_id}/detail",
            get(group_management::get_group_detail),
        )
        // 贴纸用户 API
        .route(
            "/emoji-packs/available",
            get(emoji_pack::list_available_packs),
        )
        .route("/emoji-packs/search", get(emoji_pack::search_packs))
        .route("/emoji-packs/my", get(emoji_pack::list_user_packs))
        .route(
            "/emoji-packs/download-url",
            get(emoji_pack::get_emoji_download_url),
        )
        .route(
            "/emoji-packs/{pack_id}/add",
            post(emoji_pack::add_user_pack),
        )
        .route(
            "/emoji-packs/suites/{suite_id}/add",
            post(emoji_pack::add_user_suite),
        )
        .route(
            "/emoji-packs/{pack_id}/remove",
            delete(emoji_pack::remove_user_pack),
        )
        .route(
            "/emoji-packs/suites/{suite_id}/packs",
            get(emoji_pack::list_user_suite_packs),
        )
        .layer(middleware::from_fn(auth_middleware));

    // 合并所有路由
    public_routes.merge(user_routes).merge(admin_routes)
}
