 use std::{env, net::SocketAddr};

 use axum::{
     extract::ws::{Message, WebSocket, WebSocketUpgrade},
     response::IntoResponse,
     routing::get,
     Router,
 };
 use tokio::net::TcpListener;
 use tower_http::{
     cors::{Any, CorsLayer},
     trace::TraceLayer,
 };
 use tracing::info;
 use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

 async fn root() -> &'static str {
     "redcode IM backend"
 }

 async fn healthz() -> &'static str {
     "ok"
 }

 async fn ws(ws: WebSocketUpgrade) -> impl IntoResponse {
     ws.on_upgrade(handle_socket)
 }

 async fn handle_socket(mut socket: WebSocket) {
     while let Some(Ok(msg)) = socket.recv().await {
         match msg {
             Message::Text(t) => {
                 if socket.send(Message::Text(t)).await.is_err() {
                     break;
                 }
             }
             Message::Binary(b) => {
                 if socket.send(Message::Binary(b)).await.is_err() {
                     break;
                 }
             }
             Message::Ping(p) => {
                 let _ = socket.send(Message::Pong(p)).await;
             }
             Message::Pong(_) => {}
             Message::Close(_) => break,
         }
     }
 }

 #[tokio::main]
 async fn main() {
     tracing_subscriber::registry()
         .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()))
         .with(tracing_subscriber::fmt::layer())
         .init();

     let cors = CorsLayer::new()
         .allow_origin(Any)
         .allow_methods(Any)
         .allow_headers(Any);

     let app = Router::new()
         .route("/", get(root))
         .route("/healthz", get(healthz))
         .route("/ws", get(ws))
         .layer(TraceLayer::new_for_http())
         .layer(cors);

     let port: u16 = env::var("PORT")
         .ok()
         .and_then(|s| s.parse().ok())
         .unwrap_or(8080);
     let addr = SocketAddr::from(([0, 0, 0, 0], port));

     info!("listening on {}", addr);
     let listener = TcpListener::bind(addr).await.expect("bind");
     axum::serve(listener, app).await.expect("server");
 }
