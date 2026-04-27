use std::env;
use tracing::info;

const DEFAULT_SESSION_REDIS_URL: &str = "redis://localhost:6381";
const REDIS_SESSION_ENV: &str = "REDIS_SESSION_URL";
const REDIS_PUBSUB_ENV: &str = "REDIS_PUBSUB_URL";
const REDIS_CACHE_ENV: &str = "REDIS_CACHE_URL";

/// Redis 逻辑入口映射到物理实例时的拓扑形态。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RedisTopology {
    /// session / pubsub / cache 都落在同一实例。
    SingleInstance,
    /// session 与 pubsub 共用一套实例，cache 独立。
    SessionPubSubShared,
    /// session 与 cache 共用一套实例，pubsub 独立。
    SessionCacheShared,
    /// pubsub 与 cache 共用一套实例，session 独立。
    PubSubCacheShared,
    /// 三个逻辑入口完全独立。
    FullySplit,
}

impl RedisTopology {
    pub fn instance_count(self) -> usize {
        match self {
            Self::SingleInstance => 1,
            Self::SessionPubSubShared | Self::SessionCacheShared | Self::PubSubCacheShared => 2,
            Self::FullySplit => 3,
        }
    }

    pub fn description(self) -> &'static str {
        match self {
            Self::SingleInstance => "single-instance",
            Self::SessionPubSubShared => "session-pubsub-shared",
            Self::SessionCacheShared => "session-cache-shared",
            Self::PubSubCacheShared => "pubsub-cache-shared",
            Self::FullySplit => "fully-split",
        }
    }
}

/// Redis 三类逻辑入口的解析配置。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RedisConfig {
    session_url: String,
    pubsub_url: String,
    cache_url: String,
}

impl RedisConfig {
    /// 显式构造 Redis 配置，便于测试或非环境变量入口复用。
    pub fn new(
        session_url: impl Into<String>,
        pubsub_url: impl Into<String>,
        cache_url: impl Into<String>,
    ) -> Self {
        Self {
            session_url: session_url.into(),
            pubsub_url: pubsub_url.into(),
            cache_url: cache_url.into(),
        }
    }

    /// 从环境变量解析 Redis 配置。
    ///
    /// 回退规则：
    /// - `REDIS_SESSION_URL` 未设置时回退默认地址 `redis://localhost:6381`
    /// - `REDIS_PUBSUB_URL` 未设置时回退 `REDIS_SESSION_URL`
    /// - `REDIS_CACHE_URL` 未设置时回退 `REDIS_SESSION_URL`
    pub fn from_env() -> Self {
        let session_url = env::var(REDIS_SESSION_ENV).unwrap_or_else(|_| {
            info!(
                "未设置 {}，回退默认地址 {}",
                REDIS_SESSION_ENV, DEFAULT_SESSION_REDIS_URL
            );
            DEFAULT_SESSION_REDIS_URL.to_string()
        });

        let pubsub_url = Self::read_optional_url(REDIS_PUBSUB_ENV, &session_url);
        let cache_url = Self::read_optional_url(REDIS_CACHE_ENV, &session_url);

        let config = Self::new(session_url, pubsub_url, cache_url);
        let topology = config.topology();
        info!(
            "Redis 配置解析完成：topology={}, instances={}",
            topology.description(),
            topology.instance_count()
        );
        config
    }

    fn read_optional_url(name: &str, fallback: &str) -> String {
        env::var(name).unwrap_or_else(|_| {
            info!("未设置 {}，回退复用 {}", name, REDIS_SESSION_ENV);
            fallback.to_string()
        })
    }

    pub fn session_url(&self) -> &str {
        &self.session_url
    }

    pub fn pubsub_url(&self) -> &str {
        &self.pubsub_url
    }

    pub fn cache_url(&self) -> &str {
        &self.cache_url
    }

    pub fn topology(&self) -> RedisTopology {
        let session_eq_pubsub = self.session_url == self.pubsub_url;
        let session_eq_cache = self.session_url == self.cache_url;
        let pubsub_eq_cache = self.pubsub_url == self.cache_url;

        match (session_eq_pubsub, session_eq_cache, pubsub_eq_cache) {
            (true, true, true) => RedisTopology::SingleInstance,
            (true, false, false) => RedisTopology::SessionPubSubShared,
            (false, true, false) => RedisTopology::SessionCacheShared,
            (false, false, true) => RedisTopology::PubSubCacheShared,
            (false, false, false) => RedisTopology::FullySplit,
            _ => RedisTopology::SingleInstance,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use once_cell::sync::Lazy;
    use std::sync::Mutex;

    static ENV_LOCK: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));

    struct EnvVarGuard {
        saved: Vec<(&'static str, Option<String>)>,
    }

    impl EnvVarGuard {
        fn apply(entries: &[(&'static str, Option<&str>)]) -> Self {
            let mut saved = Vec::with_capacity(entries.len());
            for (name, value) in entries {
                saved.push((*name, std::env::var(name).ok()));
                match value {
                    Some(v) => std::env::set_var(name, v),
                    None => std::env::remove_var(name),
                }
            }
            Self { saved }
        }
    }

    impl Drop for EnvVarGuard {
        fn drop(&mut self) {
            for (name, value) in &self.saved {
                match value {
                    Some(v) => std::env::set_var(name, v),
                    None => std::env::remove_var(name),
                }
            }
        }
    }

    #[test]
    fn redis_config_defaults_to_single_instance_topology() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvVarGuard::apply(&[
            (REDIS_SESSION_ENV, None),
            (REDIS_PUBSUB_ENV, None),
            (REDIS_CACHE_ENV, None),
        ]);

        let config = RedisConfig::from_env();
        assert_eq!(config.session_url(), DEFAULT_SESSION_REDIS_URL);
        assert_eq!(config.pubsub_url(), DEFAULT_SESSION_REDIS_URL);
        assert_eq!(config.cache_url(), DEFAULT_SESSION_REDIS_URL);
        assert_eq!(config.topology(), RedisTopology::SingleInstance);
    }

    #[test]
    fn redis_config_supports_session_pubsub_shared_topology() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvVarGuard::apply(&[
            (REDIS_SESSION_ENV, Some("redis://session:6379/0")),
            (REDIS_PUBSUB_ENV, None),
            (REDIS_CACHE_ENV, Some("redis://cache:6379/0")),
        ]);

        let config = RedisConfig::from_env();
        assert_eq!(config.session_url(), "redis://session:6379/0");
        assert_eq!(config.pubsub_url(), "redis://session:6379/0");
        assert_eq!(config.cache_url(), "redis://cache:6379/0");
        assert_eq!(config.topology(), RedisTopology::SessionPubSubShared);
    }

    #[test]
    fn redis_config_supports_fully_split_topology() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvVarGuard::apply(&[
            (REDIS_SESSION_ENV, Some("redis://session:6379/0")),
            (REDIS_PUBSUB_ENV, Some("redis://pubsub:6379/0")),
            (REDIS_CACHE_ENV, Some("redis://cache:6379/0")),
        ]);

        let config = RedisConfig::from_env();
        assert_eq!(config.session_url(), "redis://session:6379/0");
        assert_eq!(config.pubsub_url(), "redis://pubsub:6379/0");
        assert_eq!(config.cache_url(), "redis://cache:6379/0");
        assert_eq!(config.topology(), RedisTopology::FullySplit);
    }

    #[test]
    fn redis_config_supports_pubsub_only_split_topology() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvVarGuard::apply(&[
            (REDIS_SESSION_ENV, Some("redis://session:6379/0")),
            (REDIS_PUBSUB_ENV, Some("redis://pubsub:6379/0")),
            (REDIS_CACHE_ENV, None),
        ]);

        let config = RedisConfig::from_env();
        assert_eq!(config.session_url(), "redis://session:6379/0");
        assert_eq!(config.pubsub_url(), "redis://pubsub:6379/0");
        assert_eq!(config.cache_url(), "redis://session:6379/0");
        assert_eq!(config.topology(), RedisTopology::SessionCacheShared);
    }

    #[test]
    fn redis_config_can_be_constructed_without_environment() {
        let config = RedisConfig::new(
            "redis://session:6379/0",
            "redis://pubsub:6379/0",
            "redis://cache:6379/0",
        );

        assert_eq!(config.session_url(), "redis://session:6379/0");
        assert_eq!(config.pubsub_url(), "redis://pubsub:6379/0");
        assert_eq!(config.cache_url(), "redis://cache:6379/0");
        assert_eq!(config.topology(), RedisTopology::FullySplit);
    }
}
