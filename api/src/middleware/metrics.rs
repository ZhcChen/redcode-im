use crate::redis::session::ApiMetricAggregate;
use crate::AppState;
use axum::{
    body::Body,
    extract::State,
    http::{Method, Request},
    middleware::Next,
    response::Response,
};
use std::{
    collections::HashMap,
    env,
    time::{Duration, Instant},
};
use tokio::sync::mpsc;

const DEFAULT_METRICS_CHANNEL_CAPACITY: usize = 8192;
const DEFAULT_METRICS_FLUSH_BATCH_SIZE: usize = 1000;
const DEFAULT_METRICS_FLUSH_INTERVAL_SECONDS: u64 = 5;

#[derive(Debug, Clone)]
struct MetricsConfig {
    enabled: bool,
    channel_capacity: usize,
    flush_batch_size: usize,
    flush_interval: Duration,
    sample_rate: f64,
}

impl Default for MetricsConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            channel_capacity: DEFAULT_METRICS_CHANNEL_CAPACITY,
            flush_batch_size: DEFAULT_METRICS_FLUSH_BATCH_SIZE,
            flush_interval: Duration::from_secs(DEFAULT_METRICS_FLUSH_INTERVAL_SECONDS),
            sample_rate: 1.0,
        }
    }
}

impl MetricsConfig {
    fn from_env() -> Self {
        let defaults = Self::default();
        Self {
            enabled: read_bool_env("METRICS_ENABLED", defaults.enabled),
            channel_capacity: read_positive_usize_env(
                "METRICS_CHANNEL_CAPACITY",
                defaults.channel_capacity,
            ),
            flush_batch_size: read_positive_usize_env(
                "METRICS_FLUSH_BATCH_SIZE",
                defaults.flush_batch_size,
            ),
            flush_interval: Duration::from_secs(read_positive_u64_env(
                "METRICS_FLUSH_INTERVAL_SECONDS",
                defaults.flush_interval.as_secs(),
            )),
            sample_rate: read_sample_rate_env("METRICS_SAMPLE_RATE", defaults.sample_rate),
        }
    }
}

#[derive(Debug, Clone)]
struct ApiMetricEvent {
    method: String,
    path: String,
    duration_ms: u64,
}

#[derive(Clone)]
pub struct MetricsRecorder {
    sender: mpsc::Sender<ApiMetricEvent>,
    sample_rate: f64,
}

impl MetricsRecorder {
    fn should_record(&self) -> bool {
        self.sample_rate >= 1.0 || rand::random::<f64>() < self.sample_rate
    }
}

/// API 性能监控中间件
pub async fn metrics_middleware(
    State(state): State<AppState>,
    method: Method,
    uri: axum::http::Uri,
    request: Request<Body>,
    next: Next,
) -> Response {
    let start = Instant::now();
    let path = uri.path().to_string();

    // 跳过健康检查等非业务接口，减少 Redis 压力
    let skip_paths = ["/healthz", "/readyz", "/ws"];
    if skip_paths.iter().any(|p| path == *p) {
        return next.run(request).await;
    }

    let response = next.run(request).await;
    let duration = start.elapsed().as_millis() as u64;

    if let Some(recorder) = &state.metrics_recorder {
        if recorder.should_record() {
            let event = ApiMetricEvent {
                method: method.as_str().to_string(),
                path,
                duration_ms: duration,
            };
            if let Err(err) = recorder.sender.try_send(event) {
                tracing::debug!("API metrics 队列已满或关闭，丢弃本次指标: {}", err);
            }
        }
    }

    response
}

pub fn spawn_metrics_recorder(state: &AppState) -> Option<MetricsRecorder> {
    let config = MetricsConfig::from_env();
    if !config.enabled || config.sample_rate <= 0.0 {
        tracing::info!("API metrics 已关闭");
        return None;
    }

    let (sender, receiver) = mpsc::channel(config.channel_capacity);
    let session_manager = state.redis.get_session_manager(state.node_id.clone());
    let worker_config = config.clone();
    tokio::spawn(async move {
        run_metrics_worker(receiver, session_manager, worker_config).await;
    });

    Some(MetricsRecorder {
        sender,
        sample_rate: config.sample_rate,
    })
}

async fn run_metrics_worker(
    mut receiver: mpsc::Receiver<ApiMetricEvent>,
    session_manager: crate::redis::session::SessionManager,
    config: MetricsConfig,
) {
    let mut buffer: HashMap<(String, String), ApiMetricAccumulator> = HashMap::new();
    let mut flush_interval = tokio::time::interval(config.flush_interval);
    flush_interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        tokio::select! {
            maybe_event = receiver.recv() => {
                match maybe_event {
                    Some(event) => {
                        aggregate_event(&mut buffer, event);
                        if buffer.len() >= config.flush_batch_size {
                            flush_metrics(&session_manager, &mut buffer).await;
                        }
                    }
                    None => {
                        flush_metrics(&session_manager, &mut buffer).await;
                        break;
                    }
                }
            }
            _ = flush_interval.tick() => {
                flush_metrics(&session_manager, &mut buffer).await;
            }
        }
    }
}

#[derive(Debug, Default)]
struct ApiMetricAccumulator {
    count: u64,
    total_duration_ms: u64,
    max_duration_ms: u64,
}

fn aggregate_event(
    buffer: &mut HashMap<(String, String), ApiMetricAccumulator>,
    event: ApiMetricEvent,
) {
    let entry = buffer
        .entry((event.method, event.path))
        .or_insert_with(ApiMetricAccumulator::default);
    entry.count = entry.count.saturating_add(1);
    entry.total_duration_ms = entry.total_duration_ms.saturating_add(event.duration_ms);
    entry.max_duration_ms = entry.max_duration_ms.max(event.duration_ms);
}

async fn flush_metrics(
    session_manager: &crate::redis::session::SessionManager,
    buffer: &mut HashMap<(String, String), ApiMetricAccumulator>,
) {
    if buffer.is_empty() {
        return;
    }

    let metrics = buffer
        .drain()
        .map(|((method, path), item)| ApiMetricAggregate {
            method,
            path,
            count: item.count,
            total_duration_ms: item.total_duration_ms,
            max_duration_ms: item.max_duration_ms,
        })
        .collect::<Vec<_>>();

    if let Err(err) = session_manager.record_api_metrics_batch(&metrics).await {
        tracing::warn!(
            "批量写入 API metrics 失败，丢弃 {} 条聚合指标: {}",
            metrics.len(),
            err
        );
    }
}

fn read_bool_env(name: &str, default: bool) -> bool {
    match env::var(name) {
        Ok(value) => match value.trim().to_ascii_lowercase().as_str() {
            "1" | "true" | "yes" | "y" | "on" => true,
            "0" | "false" | "no" | "n" | "off" => false,
            _ => default,
        },
        Err(_) => default,
    }
}

fn read_positive_usize_env(name: &str, default: usize) -> usize {
    env::var(name)
        .ok()
        .and_then(|value| value.trim().parse::<usize>().ok())
        .filter(|value| *value > 0)
        .unwrap_or(default)
}

fn read_positive_u64_env(name: &str, default: u64) -> u64 {
    env::var(name)
        .ok()
        .and_then(|value| value.trim().parse::<u64>().ok())
        .filter(|value| *value > 0)
        .unwrap_or(default)
}

fn read_sample_rate_env(name: &str, default: f64) -> f64 {
    env::var(name)
        .ok()
        .and_then(|value| value.trim().parse::<f64>().ok())
        .filter(|value| value.is_finite())
        .map(|value| value.clamp(0.0, 1.0))
        .unwrap_or(default)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Mutex, OnceLock};

    const METRICS_ENV_NAMES: &[&str] = &[
        "METRICS_ENABLED",
        "METRICS_CHANNEL_CAPACITY",
        "METRICS_FLUSH_BATCH_SIZE",
        "METRICS_FLUSH_INTERVAL_SECONDS",
        "METRICS_SAMPLE_RATE",
    ];

    fn env_lock() -> &'static Mutex<()> {
        static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        LOCK.get_or_init(|| Mutex::new(()))
    }

    struct EnvGuard {
        saved: Vec<(&'static str, Option<String>)>,
    }

    impl EnvGuard {
        fn apply(entries: &[(&'static str, Option<&str>)]) -> Self {
            let mut saved = Vec::with_capacity(METRICS_ENV_NAMES.len());
            for name in METRICS_ENV_NAMES {
                saved.push((*name, env::var(name).ok()));
                env::remove_var(name);
            }

            for (name, value) in entries {
                match value {
                    Some(value) => env::set_var(name, value),
                    None => env::remove_var(name),
                }
            }

            Self { saved }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            for (name, value) in &self.saved {
                match value {
                    Some(value) => env::set_var(name, value),
                    None => env::remove_var(name),
                }
            }
        }
    }

    #[test]
    fn metrics_config_uses_defaults() {
        let _lock = env_lock().lock().expect("env lock poisoned");
        let _guard = EnvGuard::apply(&[]);

        let config = MetricsConfig::from_env();
        assert!(config.enabled);
        assert_eq!(config.channel_capacity, DEFAULT_METRICS_CHANNEL_CAPACITY);
        assert_eq!(config.flush_batch_size, DEFAULT_METRICS_FLUSH_BATCH_SIZE);
        assert_eq!(
            config.flush_interval,
            Duration::from_secs(DEFAULT_METRICS_FLUSH_INTERVAL_SECONDS)
        );
        assert_eq!(config.sample_rate, 1.0);
    }

    #[test]
    fn metrics_config_reads_env_and_clamps_sample_rate() {
        let _lock = env_lock().lock().expect("env lock poisoned");
        let _guard = EnvGuard::apply(&[
            ("METRICS_ENABLED", Some("false")),
            ("METRICS_CHANNEL_CAPACITY", Some("64")),
            ("METRICS_FLUSH_BATCH_SIZE", Some("32")),
            ("METRICS_FLUSH_INTERVAL_SECONDS", Some("2")),
            ("METRICS_SAMPLE_RATE", Some("2.5")),
        ]);

        let config = MetricsConfig::from_env();
        assert!(!config.enabled);
        assert_eq!(config.channel_capacity, 64);
        assert_eq!(config.flush_batch_size, 32);
        assert_eq!(config.flush_interval, Duration::from_secs(2));
        assert_eq!(config.sample_rate, 1.0);
    }

    #[test]
    fn aggregate_event_accumulates_count_total_and_max() {
        let mut buffer = HashMap::new();
        aggregate_event(
            &mut buffer,
            ApiMetricEvent {
                method: "GET".to_string(),
                path: "/foo".to_string(),
                duration_ms: 10,
            },
        );
        aggregate_event(
            &mut buffer,
            ApiMetricEvent {
                method: "GET".to_string(),
                path: "/foo".to_string(),
                duration_ms: 25,
            },
        );

        let item = buffer
            .get(&("GET".to_string(), "/foo".to_string()))
            .expect("metric should exist");
        assert_eq!(item.count, 2);
        assert_eq!(item.total_duration_ms, 35);
        assert_eq!(item.max_duration_ms, 25);
    }
}
