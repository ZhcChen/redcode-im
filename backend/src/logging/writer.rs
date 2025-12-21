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
        let batch_size = std::env::var("LOG_DB_BATCH_SIZE")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(100);

        let flush_interval_ms = std::env::var("LOG_DB_FLUSH_INTERVAL_MS")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(5000);

        let retention_days = std::env::var("LOG_DB_RETENTION_DAYS")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(7);

        Self {
            batch_size,
            flush_interval: Duration::from_millis(flush_interval_ms),
            retention_days,
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
                    info!("日志清理完成: 删除了 {} 条过期日志 (保留 {} 天)", deleted, retention_days);
                }
            }
            Err(e) => {
                error!("日志清理失败: {:?}", e);
            }
        }
    }
}
