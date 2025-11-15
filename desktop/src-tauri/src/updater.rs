use futures_util::StreamExt;
use serde::Serialize;
use std::path::PathBuf;
use tauri::{AppHandle, Emitter, Manager};
use tokio::{fs, io::AsyncWriteExt, process::Command};

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
    auto_open: bool,
) -> Result<(), String> {
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

    if auto_open {
        if let Err(err) = Command::new("open")
            .arg(save_path.to_string_lossy().to_string())
            .spawn()
        {
            emit(
                &app,
                DownloadEvent {
                    status: "error",
                    received,
                    total,
                    progress: format_progress(received, total),
                    file_path: None,
                    message: Some(format!("无法打开安装包: {err}")),
                },
            );
            return Err(err.to_string());
        }
    }

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
    Ok(())
}
