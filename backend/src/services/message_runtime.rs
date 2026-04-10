use chrono::{DateTime, Utc};
use uuid::Uuid;

use crate::database::settings_store::SettingsStore;
use crate::error::AppError;
use crate::AppState;

pub const MESSAGE_SERVER_STORAGE_MODE_KEY: &str = "message_server_storage_mode";
pub const MESSAGE_CONTENT_AUDIT_MODE_KEY: &str = "message_content_audit_mode";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MessageServerStorageMode {
    Persist,
    RelayOnly,
}

impl MessageServerStorageMode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Persist => "persist",
            Self::RelayOnly => "relay_only",
        }
    }

    pub fn parse(raw: &str) -> Result<Self, AppError> {
        match raw.trim().to_ascii_lowercase().as_str() {
            "persist" => Ok(Self::Persist),
            "relay_only" => Ok(Self::RelayOnly),
            _ => Err(AppError::ValidationError(
                "server_storage_mode 仅支持 persist / relay_only".to_string(),
            )),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MessageContentAuditMode {
    Plaintext,
    E2ee,
}

impl MessageContentAuditMode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Plaintext => "plaintext",
            Self::E2ee => "e2ee",
        }
    }

    pub fn parse(raw: &str) -> Result<Self, AppError> {
        match raw.trim().to_ascii_lowercase().as_str() {
            "plaintext" => Ok(Self::Plaintext),
            "e2ee" => Ok(Self::E2ee),
            _ => Err(AppError::ValidationError(
                "content_audit_mode 仅支持 plaintext / e2ee".to_string(),
            )),
        }
    }
}

#[derive(Debug, Clone)]
pub struct MessageRuntimeSettings {
    pub server_storage_mode: MessageServerStorageMode,
    pub content_audit_mode: MessageContentAuditMode,
    pub updated_at: Option<DateTime<Utc>>,
    pub updated_by: Option<String>,
}

impl Default for MessageRuntimeSettings {
    fn default() -> Self {
        Self {
            server_storage_mode: MessageServerStorageMode::Persist,
            content_audit_mode: MessageContentAuditMode::Plaintext,
            updated_at: None,
            updated_by: None,
        }
    }
}

impl MessageRuntimeSettings {
    pub fn is_relay_only(&self) -> bool {
        self.server_storage_mode == MessageServerStorageMode::RelayOnly
    }
}

pub fn relay_only_unsupported(action: &str) -> AppError {
    AppError::ValidationError(format!("relay_only 模式暂不支持{}", action))
}

fn merge_message_runtime_metadata(
    left: Option<&crate::database::models::GeneralSettingRecord>,
    right: Option<&crate::database::models::GeneralSettingRecord>,
) -> (Option<DateTime<Utc>>, Option<String>) {
    let chosen = match (left, right) {
        (Some(l), Some(r)) => {
            if l.updated_at >= r.updated_at {
                Some(l)
            } else {
                Some(r)
            }
        }
        (Some(l), None) => Some(l),
        (None, Some(r)) => Some(r),
        (None, None) => None,
    };

    (
        chosen.map(|record| record.updated_at),
        chosen.and_then(|record| record.updated_by.map(|value| value.to_string())),
    )
}

pub async fn load_message_runtime_settings(
    store: &SettingsStore,
) -> Result<MessageRuntimeSettings, AppError> {
    let server_storage = store
        .get_general_setting(MESSAGE_SERVER_STORAGE_MODE_KEY)
        .await?;
    let content_audit = store
        .get_general_setting(MESSAGE_CONTENT_AUDIT_MODE_KEY)
        .await?;
    let (updated_at, updated_by) =
        merge_message_runtime_metadata(server_storage.as_ref(), content_audit.as_ref());

    let server_storage_mode = server_storage
        .as_ref()
        .map(|record| MessageServerStorageMode::parse(&record.value))
        .transpose()?
        .unwrap_or(MessageServerStorageMode::Persist);
    let content_audit_mode = content_audit
        .as_ref()
        .map(|record| MessageContentAuditMode::parse(&record.value))
        .transpose()?
        .unwrap_or(MessageContentAuditMode::Plaintext);

    Ok(MessageRuntimeSettings {
        server_storage_mode,
        content_audit_mode,
        updated_at,
        updated_by,
    })
}

pub async fn is_relay_only_runtime(state: &AppState) -> Result<bool, AppError> {
    let store = SettingsStore::new(state.database.clone());
    Ok(load_message_runtime_settings(&store).await?.is_relay_only())
}

pub async fn update_message_runtime_settings(
    store: &SettingsStore,
    server_storage_mode: MessageServerStorageMode,
    content_audit_mode: MessageContentAuditMode,
    updated_by: Option<Uuid>,
) -> Result<MessageRuntimeSettings, AppError> {
    store
        .upsert_general_setting(
            MESSAGE_SERVER_STORAGE_MODE_KEY,
            server_storage_mode.as_str(),
            "消息服务器存储模式（persist=落库，relay_only=仅转发）",
            updated_by,
        )
        .await?;
    store
        .upsert_general_setting(
            MESSAGE_CONTENT_AUDIT_MODE_KEY,
            content_audit_mode.as_str(),
            "消息内容审计模式（plaintext=明文可审计，e2ee=端侧加密）",
            updated_by,
        )
        .await?;

    load_message_runtime_settings(store).await
}

#[cfg(test)]
mod tests {
    use super::{MessageContentAuditMode, MessageRuntimeSettings, MessageServerStorageMode};

    #[test]
    fn message_server_storage_mode_parse_accepts_supported_values() {
        assert_eq!(
            MessageServerStorageMode::parse("persist")
                .expect("persist should be valid")
                .as_str(),
            "persist"
        );
        assert_eq!(
            MessageServerStorageMode::parse("relay_only")
                .expect("relay_only should be valid")
                .as_str(),
            "relay_only"
        );
    }

    #[test]
    fn message_content_audit_mode_parse_accepts_supported_values() {
        assert_eq!(
            MessageContentAuditMode::parse("plaintext")
                .expect("plaintext should be valid")
                .as_str(),
            "plaintext"
        );
        assert_eq!(
            MessageContentAuditMode::parse("e2ee")
                .expect("e2ee should be valid")
                .as_str(),
            "e2ee"
        );
    }

    #[test]
    fn message_runtime_mode_parse_rejects_invalid_values() {
        assert!(MessageServerStorageMode::parse("other").is_err());
        assert!(MessageContentAuditMode::parse("secret").is_err());
    }

    #[test]
    fn default_message_runtime_is_persist_plaintext() {
        let settings = MessageRuntimeSettings::default();
        assert_eq!(
            settings.server_storage_mode,
            MessageServerStorageMode::Persist
        );
        assert_eq!(
            settings.content_audit_mode,
            MessageContentAuditMode::Plaintext
        );
        assert!(!settings.is_relay_only());
    }
}
