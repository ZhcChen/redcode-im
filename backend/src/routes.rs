use axum::{
    middleware,
    routing::{delete, get, patch, post},
    Router,
};

use crate::auth::auth_middleware;
use crate::handlers::{
    admin, auth, feedback, friend, healthz, message, message_read, room, root, settings, user, ws,
};
use crate::AppState;

pub fn create_routes() -> Router<AppState> {
    // 公开路由
    let public_routes = Router::new()
        .route("/", get(root))
        .route("/healthz", get(healthz))
        .route("/ws", get(ws))
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
        .route("/api/admin/users", get(admin::get_user_list))
        .route(
            "/api/admin/users/:user_id/status",
            patch(admin::update_user_status),
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
            "/api/admin/storage-providers/:provider_id",
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
        .route("/feedbacks", post(feedback::submit_feedback))
        // users
        .route("/users/search", get(user::search_users))
        .route(
            "/users/me",
            patch(user::update_me).delete(user::deactivate_me),
        )
        .route("/users/me/password", post(user::change_password))
        .route("/users/me/avatar", post(user::upload_avatar))
        .route("/users/:user_id", get(user::get_user_by_id))
        // friends
        .route(
            "/friends/requests",
            get(friend::list_friend_requests).post(friend::create_friend_request),
        )
        .route("/friends", get(friend::list_friends))
        .route(
            "/friends/requests/:request_id/respond",
            post(friend::respond_friend_request),
        )
        .route(
            "/friends/:friend_user_id/chat",
            post(friend::ensure_private_chat),
        )
        // chats
        .route("/chats", get(room::list_chat_summaries))
        // rooms
        .route("/rooms", post(room::create_room).get(room::list_my_rooms))
        .route("/rooms/:room_id/join", post(room::join_room))
        .route("/rooms/:room_id/leave", post(room::leave_room))
        .route("/rooms/:room_id/members", get(room::list_members))
        .route(
            "/rooms/:room_id/messages",
            post(message::send_message).get(message::list_messages),
        )
        .route(
            "/rooms/:room_id/messages/forward",
            post(message::forward_message),
        )
        // message reads
        .route(
            "/rooms/:room_id/messages/read",
            post(message_read::mark_message_read),
        )
        .route(
            "/rooms/:room_id/messages/read_until",
            post(message_read::mark_messages_read_until),
        )
        .route(
            "/rooms/:room_id/messages/:message_id/pin",
            post(message::pin_message).delete(message::unpin_message),
        )
        .route(
            "/rooms/:room_id/messages/:message_id",
            delete(message::delete_message),
        )
        .route(
            "/rooms/:room_id/messages/:message_id/reads",
            get(message_read::get_message_read_list),
        )
        .route(
            "/rooms/:room_id/unread_count",
            get(message_read::get_unread_count),
        )
        .route("/unread_counts", get(message_read::get_all_unread_counts))
        .layer(middleware::from_fn(auth_middleware));

    // 合并所有路由
    public_routes.merge(protected_routes)
}
