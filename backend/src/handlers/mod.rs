pub mod activity_logs;
pub mod admin;
pub mod auth;
pub mod chat_history;
pub mod emoji_pack;
pub mod feedback;
pub mod friend;
pub mod group_management;
pub mod message;
pub mod message_read;
pub mod message_search;
pub mod room;
pub mod settings;
pub mod user;
pub mod version;

use axum::{
    extract::{ws::WebSocketUpgrade, State},
    response::IntoResponse,
};
use futures_util::StreamExt;

use crate::websocket::handle_websocket_upgrade;

pub async fn root() -> &'static str {
    "redcode IM backend"
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
    handle_websocket_upgrade(State(state), ws, addr, params).await
}
