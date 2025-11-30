use crate::logger::log_message;
use futures_util::StreamExt;
use serde::Serialize;
#[cfg(unix)]
use std::fs::Permissions;
#[cfg(unix)]
use std::os::unix::prelude::PermissionsExt;
use std::{path::Path, path::PathBuf, process::Command};
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
        // 记录安装程序路径和文件信息
        let installer_exists = Path::new(&installer_path).exists();
        let installer_metadata = Path::new(&installer_path).metadata().ok();
        let installer_size = installer_metadata.as_ref().map(|m| m.len()).unwrap_or(0);

        log_message(format!(
            "[updater] Windows 安装程序路径: {}, 存在: {}, 大小: {} bytes",
            installer_path, installer_exists, installer_size
        ));

        // 检查安装包文件是否存在
        if !installer_exists {
            return Err(format!("Installer file not found: {}", installer_path));
        }

        // 检查文件大小是否合理（至少1MB）
        if installer_size < 1024 * 1024 {
            log_message(format!(
                "[updater] 警告：安装包文件过小: {} bytes",
                installer_size
            ));
        }

        // 获取更新器路径 (根据平台选择正确的文件名)
        let updater_name = if cfg!(target_os = "windows") {
            "updater.exe"
        } else {
            "updater"
        };

        // 先尝试从当前可执行文件目录查找
        let current_exe = std::env::current_exe().map_err(|e| e.to_string())?;
        let current_dir = current_exe
            .parent()
            .ok_or("Cannot get executable directory")?;
        let mut updater_exe_path = current_dir.join(updater_name);

        // 记录详细的路径信息用于调试
        log_message(format!(
            "[updater] 当前可执行文件: {}",
            current_exe.display()
        ));
        log_message(format!(
            "[updater] 可执行文件目录: {}",
            current_dir.display()
        ));
        log_message(format!(
            "[updater] 期望的updater路径: {}",
            updater_exe_path.display()
        ));
        log_message(format!(
            "[updater] updater文件存在: {}",
            updater_exe_path.exists()
        ));

        if !updater_exe_path.exists() {
            // 如果在当前目录找不到，尝试其他可能的位置
            let possible_paths = [
                // 尝试resources目录（开发环境）
                current_dir.join("resources").join(updater_name),
                // 尝试上级目录的resources
                current_dir
                    .parent()
                    .unwrap_or(current_dir)
                    .join("resources")
                    .join(updater_name),
                // 尝试target目录（构建环境）
                current_dir
                    .parent()
                    .unwrap_or(current_dir)
                    .join("target")
                    .join("release")
                    .join(updater_name),
            ];

            let mut found_path = None;
            for path in &possible_paths {
                log_message(format!(
                    "[updater] 检查替代路径: {} (存在: {})",
                    path.display(),
                    path.exists()
                ));
                if path.exists() {
                    found_path = Some(path.clone());
                    break;
                }
            }

            if let Some(path) = found_path {
                log_message(format!("[updater] 使用替代路径: {}", path.display()));
                updater_exe_path = path;
            } else {
                return Err(format!(
                    "Updater executable not found in any expected location. Searched paths: {:?}",
                    possible_paths
                        .iter()
                        .map(|p| p.display().to_string())
                        .collect::<Vec<_>>()
                ));
            }
        }

        log_message(format!(
            "[updater] 最终使用的updater路径: {}",
            updater_exe_path.display()
        ));
        log_message(format!("[updater] 传递安装程序路径: {}", installer_path));

        // 启动更新器GUI程序，传递安装程序路径作为参数
        let child = Command::new(&updater_exe_path)
            .arg(&installer_path)
            .spawn()
            .map_err(|e| {
                log_message(format!("[updater] 启动更新器失败: {}", e));
                format!("Failed to start updater: {}", e)
            })?;

        log_message(format!("[updater] 更新器进程已启动，PID: {}", child.id()));
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
