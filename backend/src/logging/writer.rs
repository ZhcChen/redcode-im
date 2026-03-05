use std::sync::Arc;
use std::time::Duration;
use tokio::sync::mpsc;
use tracing::{error, info};

use super::store::{LogEntry, LogStore};

/// 日志写入器配置
#[derive(Debug, Clone)]
pub struct LogWriterConfig {
    /// 批量写入大小
    pub batch_size: usize,
    /// 刷新间隔
    pub flush_interval: Duration,
    /// 日志保留天数
    pub retention_days: i64,
    /// 清理间隔（秒）
    pub cleanup_interval_secs: u64,
}

impl Default for LogWriterConfig {
    fn default() -> Self {
        Self {
            batch_size: 100,
            flush_interval: Duration::from_secs(5),
            retention_days: 7,
            cleanup_interval_secs: 86400, // 每天清理一次
        }
    }
}

impl LogWriterConfig {
    /// 从环境变量读取配置
    pub fn from_env() -> Self {
        fn read_positive_usize(name: &str, default: usize) -> usize {
            std::env::var(name)
                .ok()
                .and_then(|v| v.trim().parse::<usize>().ok())
                .filter(|v| *v > 0)
                .unwrap_or(default)
        }

        fn read_positive_u64(name: &str, default: u64) -> u64 {
            std::env::var(name)
                .ok()
                .and_then(|v| v.trim().parse::<u64>().ok())
                .filter(|v| *v > 0)
                .unwrap_or(default)
        }

        fn read_positive_i64(name: &str, default: i64) -> i64 {
            std::env::var(name)
                .ok()
                .and_then(|v| v.trim().parse::<i64>().ok())
                .filter(|v| *v > 0)
                .unwrap_or(default)
        }

        Self {
            batch_size: read_positive_usize("LOG_DB_BATCH_SIZE", 100),
            flush_interval: Duration::from_millis(read_positive_u64(
                "LOG_DB_FLUSH_INTERVAL_MS",
                5000,
            )),
            retention_days: read_positive_i64("LOG_DB_RETENTION_DAYS", 7),
            cleanup_interval_secs: 86400,
        }
    }
}

/// 日志写入器
pub struct LogWriter {
    receiver: mpsc::Receiver<LogEntry>,
    store: Arc<dyn LogStore>,
    config: LogWriterConfig,
}

impl LogWriter {
    pub fn new(
        receiver: mpsc::Receiver<LogEntry>,
        store: Arc<dyn LogStore>,
        config: LogWriterConfig,
    ) -> Self {
        Self {
            receiver,
            store,
            config,
        }
    }

    /// 运行写入循环
    pub async fn run(mut self) {
        let mut buffer = Vec::with_capacity(self.config.batch_size);
        let mut flush_interval = tokio::time::interval(self.config.flush_interval);

        // 跳过第一次立即触发
        flush_interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

        loop {
            tokio::select! {
                // 接收日志条目
                maybe_entry = self.receiver.recv() => {
                    match maybe_entry {
                        Some(entry) => {
                            buffer.push(entry);
                            if buffer.len() >= self.config.batch_size {
                                self.flush(&mut buffer).await;
                            }
                        }
                        None => {
                            // channel 已关闭，刷新剩余日志并退出
                            if !buffer.is_empty() {
                                self.flush(&mut buffer).await;
                            }
                            info!("日志写入器已关闭");
                            break;
                        }
                    }
                }
                // 定时刷新
                _ = flush_interval.tick() => {
                    if !buffer.is_empty() {
                        self.flush(&mut buffer).await;
                    }
                }
            }
        }
    }

    /// 刷新缓冲区到数据库
    async fn flush(&self, buffer: &mut Vec<LogEntry>) {
        if buffer.is_empty() {
            return;
        }

        let entries = std::mem::take(buffer);
        let count = entries.len();

        match self.store.write_batch(entries).await {
            Ok(written) => {
                if written > 0 {
                    // 使用 tracing 的 target 避免递归日志
                    tracing::trace!(target: "log_writer", "已写入 {} 条日志到数据库", written);
                }
            }
            Err(e) => {
                // 使用 eprintln 避免递归日志
                eprintln!("[LogWriter] 写入日志失败: {:?}, 丢弃 {} 条日志", e, count);
            }
        }
    }
}

/// 启动日志清理任务
pub async fn start_log_cleanup_task(store: Arc<dyn LogStore>, retention_days: i64) {
    let cleanup_interval = Duration::from_secs(86400); // 每天执行一次

    loop {
        // 先等待，避免启动时立即执行
        tokio::time::sleep(cleanup_interval).await;

        match store.cleanup(retention_days).await {
            Ok(deleted) => {
                if deleted > 0 {
                    info!(
                        "日志清理完成: 删除了 {} 条过期日志 (保留 {} 天)",
                        deleted, retention_days
                    );
                }
            }
            Err(e) => {
                error!("日志清理失败: {:?}", e);
            }
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
    fn test_log_writer_config_from_env_custom_values() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvVarGuard::apply(&[
            ("LOG_DB_BATCH_SIZE", Some("500")),
            ("LOG_DB_FLUSH_INTERVAL_MS", Some("2000")),
            ("LOG_DB_RETENTION_DAYS", Some("2")),
        ]);

        let config = LogWriterConfig::from_env();
        assert_eq!(config.batch_size, 500);
        assert_eq!(config.flush_interval, Duration::from_millis(2000));
        assert_eq!(config.retention_days, 2);
        assert_eq!(config.cleanup_interval_secs, 86400);
    }

    #[test]
    fn test_log_writer_config_from_env_invalid_values_use_defaults() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvVarGuard::apply(&[
            ("LOG_DB_BATCH_SIZE", Some("0")),
            ("LOG_DB_FLUSH_INTERVAL_MS", Some("-1")),
            ("LOG_DB_RETENTION_DAYS", Some("0")),
        ]);

        let config = LogWriterConfig::from_env();
        assert_eq!(config.batch_size, 100);
        assert_eq!(config.flush_interval, Duration::from_millis(5000));
        assert_eq!(config.retention_days, 7);
    }
}
