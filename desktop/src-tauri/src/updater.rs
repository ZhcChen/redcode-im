use crate::logger::log_message;
use futures_util::StreamExt;
use serde::Serialize;
use std::{
    path::Path,
    path::PathBuf,
    process::Command,
};
#[cfg(unix)]
use std::fs::Permissions;
#[cfg(unix)]
use std::os::unix::prelude::PermissionsExt;
use tauri::{AppHandle, Emitter, Manager};
use tokio::{
    fs,
    io::AsyncWriteExt,
    time::{sleep, Duration, Instant},
};

const SPEED_LIMIT_PER_SEC: u64 = 4 * 1024 * 1024;
const LOG_PROGRESS_EVERY: u64 = 5 * 1024 * 1024;

#[derive(Serialize, Clone)]
struct DownloadEvent {
    status: &'static str,
    received: u64,
    total: Option<u64>,
    progress: Option<f64>,
    file_path: Option<String>,
    message: Option<String>,
}

fn emit(app: &AppHandle, payload: DownloadEvent) {
    let _ = app.emit("update-download-progress", payload);
}

fn format_progress(received: u64, total: Option<u64>) -> Option<f64> {
    total.map(|t| {
        if t == 0 {
            0.0
        } else {
            (received as f64 / t as f64) * 100.0
        }
    })
}

#[tauri::command]
pub async fn download_update(
    app: AppHandle,
    url: String,
    file_name: String,
) -> Result<String, String> {
    let download_dir = app
        .path()
        .app_cache_dir()
        .map_err(|e| e.to_string())?
        .join("updates");
    fs::create_dir_all(&download_dir)
        .await
        .map_err(|e| e.to_string())?;

    let target_name = if file_name.trim().is_empty() {
        "Chatly-latest.dmg".to_string()
    } else {
        file_name
    };
    let save_path: PathBuf = download_dir.join(&target_name);

    log_message(format!("[updater] 开始下载: {}", url));

    let client = reqwest::ClientBuilder::new()
        .redirect(reqwest::redirect::Policy::limited(10))
        .build()
        .map_err(|e| e.to_string())?;
    let response = client.get(&url).send().await.map_err(|e| e.to_string())?;

    if !response.status().is_success() {
        let message = format!("下载失败: {}", response.status());
        emit(
            &app,
            DownloadEvent {
                status: "error",
                received: 0,
                total: None,
                progress: None,
                file_path: None,
                message: Some(message.clone()),
            },
        );
        log_message(format!("[updater] 下载失败，状态码: {}", response.status()));
        return Err(message);
    }

    let total = response.content_length();
    log_message(format!(
        "[updater] 下载响应成功，content-length={:?}",
        total
    ));
    emit(
        &app,
        DownloadEvent {
            status: "started",
            received: 0,
            total,
            progress: Some(0.0),
            file_path: None,
            message: None,
        },
    );

    let mut stream = response.bytes_stream();
    let mut file = fs::File::create(&save_path)
        .await
        .map_err(|e| e.to_string())?;
    let mut received: u64 = 0;
    let mut bytes_this_window: u64 = 0;
    let mut window_start = Instant::now();

    while let Some(chunk) = stream.next().await {
        let data = chunk.map_err(|e| e.to_string())?;
        file.write_all(&data).await.map_err(|e| e.to_string())?;
        received += data.len() as u64;
        bytes_this_window += data.len() as u64;

        if received % LOG_PROGRESS_EVERY == 0 {
            log_message(format!(
                "[updater] 已下载 {:.2} MB",
                received as f64 / (1024.0 * 1024.0)
            ));
        }

        emit(
            &app,
            DownloadEvent {
                status: "progress",
                received,
                total,
                progress: format_progress(received, total),
                file_path: None,
                message: None,
            },
        );

        if bytes_this_window >= SPEED_LIMIT_PER_SEC {
            let elapsed = window_start.elapsed();
            if elapsed < Duration::from_secs(1) {
                let delay = Duration::from_secs(1) - elapsed;
                log_message(format!("[updater] 达到限速阈值，睡眠 {:?}", delay));
                sleep(delay).await;
            }
            bytes_this_window = 0;
            window_start = Instant::now();
        }
    }

    file.flush().await.map_err(|e| e.to_string())?;
    log_message(format!(
        "[updater] 下载完成，总大小 {:.2} MB",
        received as f64 / (1024.0 * 1024.0)
    ));

    emit(
        &app,
        DownloadEvent {
            status: "finished",
            received,
            total,
            progress: Some(100.0),
            file_path: Some(save_path.to_string_lossy().to_string()),
            message: None,
        },
    );
    Ok(save_path.to_string_lossy().to_string())
}

const INSTALLER_SCRIPT: &str = r#"#!/bin/bash
set -euo pipefail
DMG="$1"
APP_NAME="Chatly.app"
APP_PATH="/Applications/$APP_NAME"
MOUNT_DIR=$(mktemp -d /tmp/chatly-update-XXXX)

osascript -e 'tell application "Chatly" to quit'
sleep 2

if hdiutil attach "$DMG" -mountpoint "$MOUNT_DIR" -nobrowse >/dev/null; then
  if [ -d "$MOUNT_DIR/$APP_NAME" ]; then
    rm -rf "$APP_PATH"
    cp -R "$MOUNT_DIR/$APP_NAME" "$APP_PATH"
  fi
  hdiutil detach "$MOUNT_DIR" >/dev/null || true
  open "$APP_PATH"
fi
"#;

#[tauri::command]
pub async fn install_update(
    app: AppHandle,
    installer_path: String,
    platform: Option<String>,
) -> Result<(), String> {
    if installer_path.trim().is_empty() {
        return Err("Installer path is empty".into());
    }

    if !Path::new(&installer_path).exists() {
        return Err("Installer file not found".into());
    }

    let platform = platform.unwrap_or_else(|| "macos".into());
    log_message(format!(
        "[updater] 准备执行安装, 文件: {}, 平台: {}",
        installer_path, platform
    ));

    if platform.eq_ignore_ascii_case("windows") {
        Command::new("powershell")
            .args([
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-Command",
                "Start-Process -FilePath \"$args[0]\" -Wait",
                &installer_path,
            ])
            .spawn()
            .map_err(|e| e.to_string())?;
        log_message("[updater] Windows 安装程序已启动".to_string());
        return Ok(());
    }

    let scripts_dir = app
        .path()
        .app_cache_dir()
        .map_err(|e| e.to_string())?
        .join("updates");
    fs::create_dir_all(&scripts_dir)
        .await
        .map_err(|e| e.to_string())?;

    let script_path = scripts_dir.join("install-update.sh");
    fs::write(&script_path, INSTALLER_SCRIPT)
        .await
        .map_err(|e| e.to_string())?;
    #[cfg(unix)]
    fs::set_permissions(&script_path, Permissions::from_mode(0o755))
        .await
        .map_err(|e| e.to_string())?;

    let script = script_path.to_string_lossy().to_string();
    Command::new("sh")
        .arg(script)
        .arg(installer_path)
        .spawn()
        .map_err(|e| e.to_string())?;

    log_message("[updater] macOS 安装脚本已启动".to_string());
    Ok(())
}
