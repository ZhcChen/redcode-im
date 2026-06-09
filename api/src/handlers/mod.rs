pub mod activity_logs;
pub mod admin;
pub mod admin_storage_config;
pub mod auth;
pub mod chat_history;
pub mod e2ee;
pub mod emoji_pack;
pub mod feedback;
pub mod friend;
pub mod group_management;
pub mod health;
pub mod message;
pub mod message_read;
pub mod message_search;
pub mod multipart_upload;
pub mod push;
pub mod push_logs;
pub mod push_queue;
pub mod push_settings;
pub mod report;
pub mod room;
pub mod settings;
pub mod upload_policy;
pub mod user;
pub mod version;

use axum::{
    extract::{ws::WebSocketUpgrade, State},
    response::IntoResponse,
};

use crate::websocket::handle_websocket_upgrade;

pub async fn root() -> &'static str {
    "redcode IM api"
}

pub async fn healthz() -> &'static str {
    "ok"
}

pub async fn ws(
    State(state): State<crate::AppState>,
    ws: WebSocketUpgrade,
    axum::extract::ConnectInfo(addr): axum::extract::ConnectInfo<std::net::SocketAddr>,
    params: axum::extract::Query<crate::websocket::WsUpgradeParams>,
) -> Result<impl IntoResponse, axum::http::StatusCode> {
    handle_websocket_upgrade(State(state), ws, axum::extract::ConnectInfo(addr), params).await
}
