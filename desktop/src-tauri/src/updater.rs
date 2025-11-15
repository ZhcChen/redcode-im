use futures_util::StreamExt;
use serde::Serialize;
use std::{fs::Permissions, os::unix::prelude::PermissionsExt, path::PathBuf, process::Command};
use tauri::{AppHandle, Emitter, Manager};
use tokio::{fs, io::AsyncWriteExt};

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

    let client = reqwest::Client::new();
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
        return Err(message);
    }

    let total = response.content_length();
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

    while let Some(chunk) = stream.next().await {
        let data = chunk.map_err(|e| e.to_string())?;
        file.write_all(&data).await.map_err(|e| e.to_string())?;
        received += data.len() as u64;
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
    }

    file.flush().await.map_err(|e| e.to_string())?;

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
pub async fn install_update(app: AppHandle, installer_path: String) -> Result<(), String> {
    if installer_path.trim().is_empty() {
        return Err("Installer path is empty".into());
    }

    if !std::path::Path::new(&installer_path).exists() {
        return Err("Installer file not found".into());
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
    fs::set_permissions(&script_path, Permissions::from_mode(0o755))
        .await
        .map_err(|e| e.to_string())?;

    let script = script_path.to_string_lossy().to_string();
    Command::new("sh")
        .arg(script)
        .arg(installer_path)
        .spawn()
        .map_err(|e| e.to_string())?;

    Ok(())
}
