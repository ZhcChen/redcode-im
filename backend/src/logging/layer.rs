use std::collections::HashSet;
use tokio::sync::mpsc;
use tracing::{field::Visit, Level, Subscriber};
use tracing_subscriber::Layer;

use super::store::LogEntry;

/// 日志级别配置
#[derive(Debug, Clone)]
pub struct LogLevelConfig {
    /// 启用的日志级别集合
    pub levels: HashSet<Level>,
}

impl Default for LogLevelConfig {
    fn default() -> Self {
        // 默认存储 DEBUG + WARN + ERROR
        let mut levels = HashSet::new();
        levels.insert(Level::DEBUG);
        levels.insert(Level::WARN);
        levels.insert(Level::ERROR);
        Self { levels }
    }
}

impl LogLevelConfig {
    /// 从环境变量解析日志级别配置
    /// 格式: LOG_DB_LEVELS=debug,warn,error
    pub fn from_env() -> Self {
        let levels_str =
            std::env::var("LOG_DB_LEVELS").unwrap_or_else(|_| "debug,warn,error".to_string());

        let mut levels = HashSet::new();
        for level in levels_str.split(',') {
            match level.trim().to_lowercase().as_str() {
                "trace" => {
                    levels.insert(Level::TRACE);
                }
                "debug" => {
                    levels.insert(Level::DEBUG);
                }
                "info" => {
                    levels.insert(Level::INFO);
                }
                "warn" => {
                    levels.insert(Level::WARN);
                }
                "error" => {
                    levels.insert(Level::ERROR);
                }
                _ => {}
            }
        }

        // 如果没有配置任何级别，使用默认值
        if levels.is_empty() {
            return Self::default();
        }

        Self { levels }
    }

    /// 检查是否应该记录该级别的日志
    pub fn should_log(&self, level: &Level) -> bool {
        self.levels.contains(level)
    }
}

/// 数据库日志 Layer
pub struct DatabaseLayer {
    sender: mpsc::Sender<LogEntry>,
    node_id: String,
    config: LogLevelConfig,
}

impl DatabaseLayer {
    pub fn new(sender: mpsc::Sender<LogEntry>, node_id: String, config: LogLevelConfig) -> Self {
        Self {
            sender,
            node_id,
            config,
        }
    }
}

impl<S> Layer<S> for DatabaseLayer
where
    S: Subscriber,
{
    fn on_event(&self, event: &tracing::Event<'_>, _ctx: tracing_subscriber::layer::Context<'_, S>) {
        let metadata = event.metadata();
        let level = metadata.level();

        // 检查是否应该记录该级别
        if !self.config.should_log(level) {
            return;
        }

        // 提取日志字段
        let mut visitor = FieldVisitor::new();
        event.record(&mut visitor);

        let message = visitor.message.unwrap_or_default();
        let fields = if visitor.fields.is_empty() {
            None
        } else {
            Some(serde_json::Value::Object(visitor.fields))
        };

        let entry = LogEntry::new(
            level.to_string().to_uppercase(),
            metadata.target().to_string(),
            message,
            fields,
            None, // span_id 暂不实现
            self.node_id.clone(),
        );

        // 非阻塞发送到 channel
        let _ = self.sender.try_send(entry);
    }
}

/// 日志字段访问器
struct FieldVisitor {
    message: Option<String>,
    fields: serde_json::Map<String, serde_json::Value>,
}

impl FieldVisitor {
    fn new() -> Self {
        Self {
            message: None,
            fields: serde_json::Map::new(),
        }
    }
}

impl Visit for FieldVisitor {
    fn record_str(&mut self, field: &tracing::field::Field, value: &str) {
        if field.name() == "message" {
            self.message = Some(value.to_string());
        } else {
            self.fields
                .insert(field.name().to_string(), serde_json::Value::String(value.to_string()));
        }
    }

    fn record_debug(&mut self, field: &tracing::field::Field, value: &dyn std::fmt::Debug) {
        let value_str = format!("{:?}", value);
        if field.name() == "message" {
            self.message = Some(value_str);
        } else {
            self.fields
                .insert(field.name().to_string(), serde_json::Value::String(value_str));
        }
    }

    fn record_i64(&mut self, field: &tracing::field::Field, value: i64) {
        self.fields.insert(
            field.name().to_string(),
            serde_json::Value::Number(serde_json::Number::from(value)),
        );
    }

    fn record_u64(&mut self, field: &tracing::field::Field, value: u64) {
        self.fields.insert(
            field.name().to_string(),
            serde_json::Value::Number(serde_json::Number::from(value)),
        );
    }

    fn record_bool(&mut self, field: &tracing::field::Field, value: bool) {
        self.fields
            .insert(field.name().to_string(), serde_json::Value::Bool(value));
    }

    fn record_f64(&mut self, field: &tracing::field::Field, value: f64) {
        if let Some(num) = serde_json::Number::from_f64(value) {
            self.fields
                .insert(field.name().to_string(), serde_json::Value::Number(num));
        }
    }

    fn record_error(
        &mut self,
        field: &tracing::field::Field,
        value: &(dyn std::error::Error + 'static),
    ) {
        self.fields.insert(
            field.name().to_string(),
            serde_json::Value::String(value.to_string()),
        );
    }
}
