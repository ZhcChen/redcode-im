use axum::{
    routing::{get, post},
    middleware,
    Router,
};

use crate::handlers::{root, healthz, ws, auth};
use crate::auth::auth_middleware;
use crate::{AppState};

pub fn create_routes() -> Router<AppState> {
    // 公开路由
    let public_routes = Router::new()
        .route("/", get(root))
        .route("/healthz", get(healthz))
        .route("/ws", get(ws))
        .route("/auth/register", post(auth::register))
        .route("/auth/login", post(auth::login));

    // 需要认证的路由
    let protected_routes = Router::new()
        .route("/auth/me", get(auth::get_current_user))
        .layer(middleware::from_fn(auth_middleware));

    // 合并所有路由
    public_routes.merge(protected_routes)
}