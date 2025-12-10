//! Tauri 命令
//!
//! 提供给前端调用的录音相关命令。

use super::permission::{self, PermissionStatus};
use super::recorder::{AudioRecorderState, RecordingResult, RecordingStatus};
use tauri::State;

/// 检查麦克风权限状态
#[tauri::command]
pub async fn check_microphone_permission() -> Result<PermissionStatus, String> {
    Ok(permission::check_microphone_permission())
}

/// 请求麦克风权限
#[tauri::command]
pub async fn request_microphone_permission() -> Result<bool, String> {
    permission::request_microphone_permission()
}

/// 开始录音
#[tauri::command]
pub async fn start_recording(state: State<'_, AudioRecorderState>) -> Result<(), String> {
    let recorder = state.recorder.lock().map_err(|e| e.to_string())?;
    recorder.start()
}

/// 停止录音并返回录音数据
#[tauri::command]
pub async fn stop_recording(
    state: State<'_, AudioRecorderState>,
) -> Result<RecordingResult, String> {
    let recorder = state.recorder.lock().map_err(|e| e.to_string())?;
    recorder.stop()
}

/// 取消录音
#[tauri::command]
pub async fn cancel_recording(state: State<'_, AudioRecorderState>) -> Result<(), String> {
    let recorder = state.recorder.lock().map_err(|e| e.to_string())?;
    recorder.cancel()
}

/// 获取录音状态
#[tauri::command]
pub async fn get_recording_status(
    state: State<'_, AudioRecorderState>,
) -> Result<RecordingStatus, String> {
    let recorder = state.recorder.lock().map_err(|e| e.to_string())?;
    Ok(recorder.status())
}

/// 获取当前录音时长（毫秒）
#[tauri::command]
pub async fn get_recording_duration(state: State<'_, AudioRecorderState>) -> Result<u64, String> {
    let recorder = state.recorder.lock().map_err(|e| e.to_string())?;
    Ok(recorder.get_duration_ms())
}
