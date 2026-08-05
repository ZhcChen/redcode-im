use chrono::{Duration, Utc};
use serde::Serialize;
use serde_json::Value as JsonValue;
use std::cmp::Ordering;
use std::collections::BTreeMap;
use uuid::Uuid;

use crate::database::e2ee_runtime_store::{
    DeviceCapabilityRecord, E2eeRuntimeGateRecord, E2eeRuntimeStore,
};
use crate::error::AppError;
use crate::services::message_runtime::{
    load_message_runtime_settings, MESSAGE_CONTENT_AUDIT_MODE_KEY,
};
use crate::AppState;

pub const E2EE_GATE_STATE_PLAINTEXT: &str = "plaintext";
pub const E2EE_GATE_STATE_PREPARE: &str = "prepare";
pub const E2EE_GATE_STATE_ACTIVE: &str = "active";
pub const E2EE_READINESS_TTL_MINUTES: i64 = 10;

const DEFAULT_MIN_CLIENT_VERSIONS: &str =
    r#"{"android":"0.1.0","ios":"0.1.0","h5":"0.1.0","desktop":"0.1.0"}"#;

#[derive(Debug, Serialize, Clone)]
pub struct E2eeRuntimeGateView {
    pub state: String,
    pub content_audit_mode: String,
    pub readiness_revision: i64,
    pub readiness_computed_at: Option<String>,
    pub readiness_expired: bool,
    pub min_client_versions: BTreeMap<String, String>,
    pub required_coverage_percent: i16,
    pub key_package_low_watermark: i32,
    pub security_review_approved: bool,
    pub readiness: ReadinessView,
    pub updated_at: String,
    pub updated_by: Option<Uuid>,
}

#[derive(Debug, Serialize, Clone, PartialEq, Eq)]
pub struct ReadinessView {
    pub active_devices: i64,
    pub compliant_devices: i64,
    pub coverage_percent: i64,
    pub low_inventory_devices: i64,
    pub pending_approval_devices: i64,
    pub blocking_reasons: Vec<String>,
    pub ready: bool,
}

pub async fn get_e2ee_gate_view(state: &AppState) -> Result<E2eeRuntimeGateView, AppError> {
    let store = E2eeRuntimeStore::new(state.database.pool());
    let gate = store.read_gate().await?;
    let readiness = compute_readiness(&store, &gate).await?;
    build_gate_view(&gate, &readiness, state).await
}

pub async fn prepare_e2ee_runtime(
    state: &AppState,
    admin_id: Option<Uuid>,
) -> Result<E2eeRuntimeGateView, AppError> {
    let store = E2eeRuntimeStore::new(state.database.pool());
    let gate = store.read_gate().await?;
    let readiness = compute_readiness(&store, &gate).await?;
    let revision = gate.readiness_revision + 1;
    store
        .update_gate(
            E2EE_GATE_STATE_PREPARE,
            revision,
            Some(Utc::now()),
            admin_id,
        )
        .await?;
    let gate = store.read_gate().await?;
    build_gate_view(&gate, &readiness, state).await
}

pub async fn active_e2ee_runtime(
    state: &AppState,
    admin_id: Option<Uuid>,
) -> Result<E2eeRuntimeGateView, AppError> {
    let store = E2eeRuntimeStore::new(state.database.pool());
    let gate = store.read_gate().await?;
    if gate.state != E2EE_GATE_STATE_PREPARE {
        return Err(AppError::MessageRuntimeConflict(
            "E2EE 启用前必须先执行预检（prepare）".to_string(),
        ));
    }
    // active 时基于最新设备/库存重新校验，预检结果不能跨状态直接生效。
    let readiness = compute_readiness(&store, &gate).await?;
    if !readiness.ready {
        return Err(AppError::MessageRuntimeConflict(format!(
            "E2EE readiness 未通过：{}",
            readiness.blocking_reasons.join("；")
        )));
    }
    let revision = gate.readiness_revision + 1;
    activate_gate_transaction(state, revision, admin_id).await?;
    let gate = store.read_gate().await?;
    build_gate_view(&gate, &readiness, state).await
}

pub async fn rollback_e2ee_runtime(
    state: &AppState,
    admin_id: Option<Uuid>,
) -> Result<E2eeRuntimeGateView, AppError> {
    rollback_gate_transaction(state, admin_id).await?;
    let store = E2eeRuntimeStore::new(state.database.pool());
    let gate = store.read_gate().await?;
    let readiness = compute_readiness(&store, &gate).await?;
    build_gate_view(&gate, &readiness, state).await
}

async fn compute_readiness(
    store: &E2eeRuntimeStore<'_>,
    gate: &E2eeRuntimeGateRecord,
) -> Result<ReadinessView, AppError> {
    let min_versions = parse_min_client_versions(&gate.min_client_versions);
    let devices = store.list_active_device_capabilities().await?;
    let active_devices = devices.len() as i64;
    let compliant_devices = devices
        .iter()
        .filter(|device| is_compliant_device(device, &min_versions))
        .count() as i64;
    let coverage_percent = if active_devices == 0 {
        0
    } else {
        compliant_devices * 100 / active_devices
    };
    let low_inventory_devices = store
        .list_active_device_inventory(gate.key_package_low_watermark)
        .await?
        .len() as i64;
    let pending_approval_devices = store.count_pending_approval_devices().await?;

    let mut blocking_reasons: Vec<String> = Vec::new();
    if active_devices == 0 {
        blocking_reasons.push("没有已激活的 E2EE 设备".to_string());
    } else if coverage_percent < i64::from(gate.required_coverage_percent) {
        blocking_reasons.push(format!(
            "设备覆盖不足（{coverage_percent}% < {}%），存在旧版本或不支持 E2EE 的客户端",
            gate.required_coverage_percent
        ));
    }
    if low_inventory_devices > 0 {
        blocking_reasons.push(format!(
            "{low_inventory_devices} 台设备 KeyPackage 库存低于低水位 {}",
            gate.key_package_low_watermark
        ));
    }
    if pending_approval_devices > 0 {
        blocking_reasons.push(format!("存在 {pending_approval_devices} 台待批准设备"));
    }
    if !gate.security_review_approved {
        blocking_reasons.push("安全审查未通过".to_string());
    }

    let ready = active_devices > 0
        && coverage_percent >= i64::from(gate.required_coverage_percent)
        && low_inventory_devices == 0
        && pending_approval_devices == 0
        && gate.security_review_approved;

    Ok(ReadinessView {
        active_devices,
        compliant_devices,
        coverage_percent,
        low_inventory_devices,
        pending_approval_devices,
        blocking_reasons,
        ready,
    })
}

fn is_compliant_device(
    device: &DeviceCapabilityRecord,
    min_versions: &BTreeMap<String, String>,
) -> bool {
    let Some(platform) = device.client_platform.as_deref() else {
        return false;
    };
    let Some(version) = device.client_version.as_deref() else {
        return false;
    };
    let Some(min_version) = min_versions.get(platform) else {
        return false;
    };
    compare_versions(version, min_version) != Ordering::Less
}

fn parse_min_client_versions(value: &JsonValue) -> BTreeMap<String, String> {
    let fallback: BTreeMap<String, String> =
        serde_json::from_str(DEFAULT_MIN_CLIENT_VERSIONS).expect("默认最低版本常量必须是合法 JSON");
    let Some(object) = value.as_object() else {
        return fallback;
    };
    let mut parsed: BTreeMap<String, String> = BTreeMap::new();
    for (platform, version) in object {
        if let Some(version) = version.as_str() {
            if !version.trim().is_empty() {
                parsed.insert(platform.clone(), version.to_string());
            }
        }
    }
    if parsed.is_empty() {
        fallback
    } else {
        parsed
    }
}

/// 按点分数字段比较版本：不足段补 0，非数字段视为低于任何版本。
pub fn compare_versions(left: &str, right: &str) -> Ordering {
    let left_parts = parse_version_parts(left);
    let right_parts = parse_version_parts(right);
    let length = left_parts.len().max(right_parts.len());
    for index in 0..length {
        let l = left_parts.get(index).copied().unwrap_or(0);
        let r = right_parts.get(index).copied().unwrap_or(0);
        let ordering = l.cmp(&r);
        if ordering != Ordering::Equal {
            return ordering;
        }
    }
    Ordering::Equal
}

fn parse_version_parts(value: &str) -> Vec<i64> {
    value
        .split('.')
        .map(|part| part.trim().parse::<i64>().unwrap_or(-1))
        .collect()
}

async fn build_gate_view(
    gate: &E2eeRuntimeGateRecord,
    readiness: &ReadinessView,
    state: &AppState,
) -> Result<E2eeRuntimeGateView, AppError> {
    let settings_store =
        crate::database::settings_store::SettingsStore::new(state.database.clone());
    let runtime = load_message_runtime_settings(&settings_store).await?;
    let min_versions = parse_min_client_versions(&gate.min_client_versions);
    let readiness_expired = gate.readiness_computed_at.map_or(true, |computed| {
        Utc::now().signed_duration_since(computed) > Duration::minutes(E2EE_READINESS_TTL_MINUTES)
    });
    Ok(E2eeRuntimeGateView {
        state: gate.state.clone(),
        content_audit_mode: runtime.content_audit_mode.as_str().to_string(),
        readiness_revision: gate.readiness_revision,
        readiness_computed_at: gate.readiness_computed_at.map(|item| item.to_rfc3339()),
        readiness_expired,
        min_client_versions: min_versions,
        required_coverage_percent: gate.required_coverage_percent,
        key_package_low_watermark: gate.key_package_low_watermark,
        security_review_approved: gate.security_review_approved,
        readiness: readiness.clone(),
        updated_at: gate.updated_at.to_rfc3339(),
        updated_by: gate.updated_by,
    })
}

async fn activate_gate_transaction(
    state: &AppState,
    revision: i64,
    admin_id: Option<Uuid>,
) -> Result<(), AppError> {
    let mut tx = state
        .database
        .pool()
        .begin()
        .await
        .map_err(AppError::DatabaseError)?;
    sqlx::query(
        "UPDATE e2ee_runtime_gate
         SET state = 'active', readiness_revision = $1, readiness_computed_at = NOW(),
             updated_at = NOW(), updated_by = $2
         WHERE id = 1",
    )
    .bind(revision)
    .bind(admin_id)
    .execute(&mut *tx)
    .await
    .map_err(AppError::DatabaseError)?;
    sqlx::query(
        r#"
        INSERT INTO general_settings (key, value, description, updated_at, updated_by)
        VALUES ($1, $2, '消息内容审计模式（plaintext=明文可审计，e2ee=端侧加密）', NOW(), $3)
        ON CONFLICT (key) DO UPDATE SET
            value = EXCLUDED.value,
            description = EXCLUDED.description,
            updated_at = NOW(),
            updated_by = EXCLUDED.updated_by
        "#,
    )
    .bind(MESSAGE_CONTENT_AUDIT_MODE_KEY)
    .bind("e2ee")
    .bind(admin_id)
    .execute(&mut *tx)
    .await
    .map_err(AppError::DatabaseError)?;
    tx.commit().await.map_err(AppError::DatabaseError)
}

async fn rollback_gate_transaction(
    state: &AppState,
    admin_id: Option<Uuid>,
) -> Result<(), AppError> {
    let mut tx = state
        .database
        .pool()
        .begin()
        .await
        .map_err(AppError::DatabaseError)?;
    sqlx::query(
        "UPDATE e2ee_runtime_gate
         SET state = 'plaintext', updated_at = NOW(), updated_by = $1
         WHERE id = 1",
    )
    .bind(admin_id)
    .execute(&mut *tx)
    .await
    .map_err(AppError::DatabaseError)?;
    sqlx::query(
        r#"
        INSERT INTO general_settings (key, value, description, updated_at, updated_by)
        VALUES ($1, $2, '消息内容审计模式（plaintext=明文可审计，e2ee=端侧加密）', NOW(), $3)
        ON CONFLICT (key) DO UPDATE SET
            value = EXCLUDED.value,
            description = EXCLUDED.description,
            updated_at = NOW(),
            updated_by = EXCLUDED.updated_by
        "#,
    )
    .bind(MESSAGE_CONTENT_AUDIT_MODE_KEY)
    .bind("plaintext")
    .bind(admin_id)
    .execute(&mut *tx)
    .await
    .map_err(AppError::DatabaseError)?;
    tx.commit().await.map_err(AppError::DatabaseError)
}

#[cfg(test)]
mod tests {
    use super::{compare_versions, parse_min_client_versions};
    use std::cmp::Ordering;

    #[test]
    fn version_comparison_follows_dot_segments() {
        assert_eq!(compare_versions("0.1.0", "0.1.0"), Ordering::Equal);
        assert_eq!(compare_versions("0.1.0", "0.1"), Ordering::Equal);
        assert_eq!(compare_versions("0.2.0", "0.1.9"), Ordering::Greater);
        assert_eq!(compare_versions("0.1.10", "0.1.9"), Ordering::Greater);
        assert_eq!(compare_versions("1.0.0", "0.9.9"), Ordering::Greater);
        assert_eq!(compare_versions("0.1.0", "0.2"), Ordering::Less);
    }

    #[test]
    fn non_numeric_version_segments_rank_below_any_number() {
        assert_eq!(compare_versions("dev", "0.1.0"), Ordering::Less);
        assert_eq!(compare_versions("0.1.0", "dev"), Ordering::Greater);
    }

    #[test]
    fn empty_min_versions_falls_back_to_defaults() {
        let versions = parse_min_client_versions(&serde_json::json!({}));
        assert_eq!(versions.get("h5").map(String::as_str), Some("0.1.0"));
        assert_eq!(versions.get("desktop").map(String::as_str), Some("0.1.0"));
    }
}
