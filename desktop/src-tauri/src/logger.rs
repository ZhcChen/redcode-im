use chrono::Local;
use once_cell::sync::Lazy;
use serde_json::Value;
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::sync::Mutex;
use tauri::{AppHandle, Manager};

static LOG_FILE: Lazy<Mutex<Option<File>>> = Lazy::new(|| Mutex::new(None));
const APP_VERSION: &str = env!("CARGO_PKG_VERSION");

pub fn init_logger(app: &AppHandle) -> std::io::Result<PathBuf> {
    let mut log_dir = app
        .path()
        .app_data_dir()
        .map_err(|e| std::io::Error::other(e.to_string()))?;
    log_dir.push("logs");
    std::fs::create_dir_all(&log_dir)?;

    let log_path = log_dir.join("app.log");
    if log_path.exists() {
        let archive_name = format!("app_{}.log", Local::now().format("%Y%m%d%H%M%S"));
        let archive_path = log_dir.join(archive_name);
        std::fs::rename(&log_path, archive_path)?;
    }

    let file = OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .open(&log_path)?;

    {
        let mut guard = LOG_FILE.lock().unwrap();
        *guard = Some(file);
    }

    log_message(format!(
        "==== App started (build {APP_VERSION}, ts={}) ====",
        Local::now().timestamp()
    ));
    Ok(log_path)
}

pub fn log_message(message: impl AsRef<str>) {
    let ts = Local::now().format("%Y-%m-%d %H:%M:%S%.3f");
    let line = format!("[{ts}] {}", message.as_ref());

    if let Some(file) = LOG_FILE.lock().unwrap().as_mut() {
        let _ = writeln!(file, "{line}");
        let _ = file.flush();
    }
}

pub fn log_event(tag: &str, payload: Value) {
    let entry = Value::Object(
        [
            ("tag".into(), Value::String(tag.to_string())),
            ("payload".into(), payload),
        ]
        .into_iter()
        .collect(),
    );
    log_message(entry.to_string());
}
