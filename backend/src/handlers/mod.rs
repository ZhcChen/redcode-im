pub mod auth;
pub mod message;

use axum::{
    extract::ws::WebSocketUpgrade,
    response::IntoResponse,
};

use crate::websocket::handle_socket;

pub async fn root() -> &'static str {
    "redcode IM backend"
}

pub async fn healthz() -> &'static str {
    "ok"
}

pub async fn ws(ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(handle_socket)
}