use chrono::{Duration, Utc};
use once_cell::sync::OnceCell;
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;

use crate::database::settings_store::SettingsStore;
use crate::AppState;

const SETTING_UPLOAD_POLICY: &str = "upload_policy";
const UPLOAD_POLICY_RUNTIME_TTL_SECONDS: i64 = 60;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioOnlyPolicy {
    pub enabled: bool,
    pub force_single_attachment: bool,
    pub allow_text: bool,
}

impl Default for AudioOnlyPolicy {
    fn default() -> Self {
        Self {
            enabled: true,
            force_single_attachment: true,
            allow_text: false,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UploadPolicyMimeByPartType {
    #[serde(default)]
    pub image: Vec<String>,
    #[serde(default)]
    pub video: Vec<String>,
    #[serde(default)]
    pub audio: Vec<String>,
    #[serde(default)]
    pub file: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UploadPolicyMaxSizeMbByPartType {
    pub image: i32,
    pub video: i32,
    pub audio: i32,
    pub file: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UploadPolicy {
    pub version: String,
    pub max_total_size_mb: i32,
    pub max_attachments_per_message: i32,
    pub max_size_mb_by_part_type: UploadPolicyMaxSizeMbByPartType,
    pub mime_by_part_type: UploadPolicyMimeByPartType,
    pub audio_only: AudioOnlyPolicy,
}

impl UploadPolicy {
    pub fn mime_whitelist(&self) -> Vec<String> {
        use std::collections::BTreeSet;

        let mut set: BTreeSet<String> = BTreeSet::new();
        for item in self
            .mime_by_part_type
            .image
            .iter()
            .chain(self.mime_by_part_type.video.iter())
            .chain(self.mime_by_part_type.audio.iter())
            .chain(self.mime_by_part_type.file.iter())
        {
            let trimmed = item.trim().to_ascii_lowercase();
            if trimmed.is_empty() {
                continue;
            }
            set.insert(trimmed);
        }
        set.into_iter().collect()
    }

    pub fn max_size_bytes_for_part_type(&self, part_type: &str) -> Option<usize> {
        let mb = match part_type {
            "image" => self.max_size_mb_by_part_type.image,
            "video" => self.max_size_mb_by_part_type.video,
            "audio" => self.max_size_mb_by_part_type.audio,
            "file" => self.max_size_mb_by_part_type.file,
            _ => return None,
        };
        let mb = mb.clamp(1, 10_000) as usize;
        Some(mb * 1024 * 1024)
    }

    pub fn is_mime_allowed_for_part_type(&self, part_type: &str, mime: &str) -> bool {
        let normalized = mime.trim().to_ascii_lowercase();
        if normalized.is_empty() {
            return false;
        }

        let list = match part_type {
            "image" => &self.mime_by_part_type.image,
            "video" => &self.mime_by_part_type.video,
            "audio" => &self.mime_by_part_type.audio,
            "file" => &self.mime_by_part_type.file,
            _ => return false,
        };

        list.iter()
            .any(|v| v.trim().eq_ignore_ascii_case(normalized.as_str()))
    }

    pub fn default_policy() -> Self {
        // 默认以服务端现有限制为准，避免多端不一致。
        let image_mb = (crate::constants::AVATAR_MAX_SIZE_BYTES / 1024 / 1024) as i32; // 5MB
        let audio_mb = (crate::constants::AUDIO_MAX_SIZE_BYTES / 1024 / 1024) as i32; // 20MB
        let video_mb = (crate::constants::VIDEO_MAX_SIZE_BYTES / 1024 / 1024) as i32; // 100MB
        let file_mb = (crate::constants::FILE_MAX_SIZE_BYTES / 1024 / 1024) as i32; // 50MB

        let mut image: Vec<String> = crate::constants::IMAGE_ALLOWED_TYPES
            .iter()
            .map(|v| v.to_string())
            .collect();
        let mut video: Vec<String> = crate::constants::VIDEO_ALLOWED_TYPES
            .iter()
            .map(|v| v.to_string())
            .collect();
        let mut audio: Vec<String> = crate::constants::AUDIO_ALLOWED_TYPES
            .iter()
            .map(|v| v.to_string())
            .collect();

        let mut file: Vec<String> = Vec::new();
        file.extend(
            crate::constants::DOCUMENT_ALLOWED_TYPES
                .iter()
                .map(|v| v.to_string()),
        );
        file.extend(
            crate::constants::ARCHIVE_ALLOWED_TYPES
                .iter()
                .map(|v| v.to_string()),
        );

        image.sort();
        image.dedup();
        video.sort();
        video.dedup();
        audio.sort();
        audio.dedup();
        file.sort();
        file.dedup();

        Self {
            version: "builtin-v1".to_string(),
            max_total_size_mb: 100,
            max_attachments_per_message: 10,
            max_size_mb_by_part_type: UploadPolicyMaxSizeMbByPartType {
                image: image_mb,
                video: video_mb,
                audio: audio_mb,
                file: file_mb,
            },
            mime_by_part_type: UploadPolicyMimeByPartType {
                image,
                video,
                audio,
                file,
            },
            audio_only: AudioOnlyPolicy::default(),
        }
    }
}

#[derive(Debug)]
struct UploadPolicyRuntime {
    loaded_at: chrono::DateTime<Utc>,
    policy: UploadPolicy,
}

impl Default for UploadPolicyRuntime {
    fn default() -> Self {
        Self {
            loaded_at: Utc::now() - Duration::seconds(UPLOAD_POLICY_RUNTIME_TTL_SECONDS * 10),
            policy: UploadPolicy::default_policy(),
        }
    }
}

static UPLOAD_POLICY_RUNTIME: OnceCell<RwLock<UploadPolicyRuntime>> = OnceCell::new();

fn upload_policy_lock() -> &'static RwLock<UploadPolicyRuntime> {
    UPLOAD_POLICY_RUNTIME.get_or_init(|| RwLock::new(UploadPolicyRuntime::default()))
}

async fn load_upload_policy_from_db(state: &AppState) -> Option<UploadPolicy> {
    let store = SettingsStore::new(state.database.clone());
    let record = store
        .get_general_setting(SETTING_UPLOAD_POLICY)
        .await
        .ok()
        .flatten()?;
    let raw = record.value.trim();
    if raw.is_empty() {
        return None;
    }

    match serde_json::from_str::<UploadPolicy>(raw) {
        Ok(mut policy) => {
            // 兜底防御：如果管理员误填 0 或负数，回退到默认值。
            let default = UploadPolicy::default_policy();

            if policy.version.trim().is_empty() {
                policy.version = default.version;
            }
            policy.max_total_size_mb = policy.max_total_size_mb.clamp(1, 10_000);
            policy.max_attachments_per_message = policy.max_attachments_per_message.clamp(0, 200);

            policy.max_size_mb_by_part_type.image =
                policy.max_size_mb_by_part_type.image.clamp(1, 10_000);
            policy.max_size_mb_by_part_type.video =
                policy.max_size_mb_by_part_type.video.clamp(1, 10_000);
            policy.max_size_mb_by_part_type.audio =
                policy.max_size_mb_by_part_type.audio.clamp(1, 10_000);
            policy.max_size_mb_by_part_type.file =
                policy.max_size_mb_by_part_type.file.clamp(1, 10_000);

            policy
                .mime_by_part_type
                .image
                .retain(|v| !v.trim().is_empty());
            policy
                .mime_by_part_type
                .video
                .retain(|v| !v.trim().is_empty());
            policy
                .mime_by_part_type
                .audio
                .retain(|v| !v.trim().is_empty());
            policy
                .mime_by_part_type
                .file
                .retain(|v| !v.trim().is_empty());

            Some(policy)
        }
        Err(e) => {
            tracing::warn!("UploadPolicy: 解析 DB 配置失败，使用默认策略: {}", e);
            None
        }
    }
}

pub async fn get_upload_policy(state: &AppState) -> UploadPolicy {
    let now = Utc::now();
    {
        let guard = upload_policy_lock().read().await;
        if guard.loaded_at > now - Duration::seconds(UPLOAD_POLICY_RUNTIME_TTL_SECONDS) {
            return guard.policy.clone();
        }
    }

    let mut guard = upload_policy_lock().write().await;
    if guard.loaded_at > now - Duration::seconds(UPLOAD_POLICY_RUNTIME_TTL_SECONDS) {
        return guard.policy.clone();
    }

    let policy = load_upload_policy_from_db(state)
        .await
        .unwrap_or_else(UploadPolicy::default_policy);

    guard.policy = policy;
    guard.loaded_at = Utc::now();
    guard.policy.clone()
}

pub async fn invalidate_upload_policy_cache() {
    let mut guard = upload_policy_lock().write().await;
    guard.loaded_at = Utc::now() - Duration::seconds(UPLOAD_POLICY_RUNTIME_TTL_SECONDS * 10);
}
