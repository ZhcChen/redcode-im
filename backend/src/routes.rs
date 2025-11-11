use axum::{
    middleware,
    routing::{delete, get, patch, post},
    Router,
};

use crate::auth::auth_middleware;
use crate::handlers::{
    admin, auth, feedback, friend, group_management, healthz, message, message_read,
    message_search, room, root, settings, user, version, ws,
};
use crate::AppState;

pub fn create_routes() -> Router<AppState> {
    // 公开路由
    let public_routes = Router::new()
        .route("/", get(root))
        .route("/healthz", get(healthz))
        .route("/ws", get(ws))
        .route("/versions/latest", get(version::latest_version))
        .route("/versions/download", get(version::download_version))
        .route("/auth/register", post(auth::register))
        .route("/auth/login", post(auth::login))
        .route("/auth/login/sms", post(auth::login_with_sms))
        .route("/auth/sms/send", post(auth::send_login_sms))
        .route(
            "/settings/privacy-policy",
            get(settings::get_privacy_policy),
        );

    // 需要认证的路由
    let protected_routes = Router::new()
        .route("/auth/me", get(auth::get_current_user))
        .route("/auth/password/reset", post(auth::reset_password_with_sms))
        // admin APIs
        .route("/api/dashboard/stats", get(admin::get_dashboard_stats))
        .route("/api/dashboard/monitor", get(admin::get_system_monitor))
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
        .route(
            "/api/admin/users/{user_id}/roles",
            get(admin::get_user_roles),
        )
        // 权限管理API
        .route("/api/admin/permissions", get(admin::get_permissions))
        .route("/api/admin/roles", get(admin::get_roles))
        .route("/api/admin/roles", post(admin::create_role))
        .route(
            "/api/admin/roles/{role_id}",
            patch(admin::update_role).delete(admin::delete_role),
        )
        .route("/api/admin/roles/assign", post(admin::assign_role_to_user))
        .route(
            "/api/admin/users/{user_id}/roles/{role_id}",
            delete(admin::revoke_role_from_user),
        )
        .route(
            "/api/admin/permissions/check",
            post(admin::check_user_permission),
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
        .route("/feedbacks", post(feedback::submit_feedback))
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
        // chats
        .route("/chats", get(room::list_chat_summaries))
        // rooms
        .route("/rooms", post(room::create_room).get(room::list_my_rooms))
        .route("/rooms/{room_id}/join", post(room::join_room))
        .route("/rooms/{room_id}/leave", post(room::leave_room))
        .route("/rooms/{room_id}/members", get(room::list_members))
        .route(
            "/rooms/{room_id}/notification-settings",
            post(room::update_notification_settings),
        )
        .route(
            "/rooms/{room_id}/messages",
            post(message::send_message).get(message::list_messages),
        )
        .route(
            "/rooms/{room_id}/messages/attachments/signature",
            post(message::generate_message_attachment_signature),
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
            "/rooms/{room_id}/announcements",
            get(group_management::list_announcements).post(group_management::create_announcement),
        )
        .route(
            "/rooms/{room_id}/announcements/{announcement_id}",
            patch(group_management::update_announcement)
                .delete(group_management::delete_announcement),
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
        .layer(middleware::from_fn(auth_middleware));

    // 合并所有路由
    public_routes.merge(protected_routes)
}
