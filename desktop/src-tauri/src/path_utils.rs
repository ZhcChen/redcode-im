/**
 * 路径工具模块
 * 提供获取用户目录（下载目录、桌面目录等）的功能
 */
use tauri::{AppHandle, Manager};

/// 获取用户下载目录
#[tauri::command]
pub async fn get_user_download_dir(app: AppHandle) -> Result<String, String> {
    let download_dir = app
        .path()
        .download_dir()
        .map_err(|e| format!("获取下载目录失败: {}", e))?;

    Ok(download_dir.to_string_lossy().to_string())
}

/// 获取用户桌面目录
#[tauri::command]
pub async fn get_user_desktop_dir(app: AppHandle) -> Result<String, String> {
    let desktop_dir = app
        .path()
        .desktop_dir()
        .map_err(|e| format!("获取桌面目录失败: {}", e))?;

    Ok(desktop_dir.to_string_lossy().to_string())
}

/// 检查目录是否存在
#[tauri::command]
pub async fn check_dir_exists(path: String) -> Result<bool, String> {
    use std::path::Path;
    Ok(Path::new(&path).exists() && Path::new(&path).is_dir())
}

/// 检查文件是否存在
#[tauri::command]
pub async fn check_file_exists(path: String) -> Result<bool, String> {
    use std::path::Path;
    Ok(Path::new(&path).exists() && Path::new(&path).is_file())
}

/// 创建目录（如果不存在）
#[tauri::command]
pub async fn create_dir(path: String, recursive: bool) -> Result<(), String> {
    use std::path::Path;
    let path = Path::new(&path);

    if recursive {
        std::fs::create_dir_all(path).map_err(|e| format!("创建目录失败: {}", e))
    } else {
        std::fs::create_dir(path).map_err(|e| format!("创建目录失败: {}", e))
    }
}

/// 打开文件所在目录（在文件管理器中显示）
#[tauri::command]
pub async fn open_file_directory(file_path: String) -> Result<(), String> {
    use std::path::Path;
    use std::process::Command;

    let path = Path::new(&file_path);
    let is_file = path.is_file();

    // 获取文件所在目录
    let dir_path = if is_file {
        path.parent()
            .ok_or_else(|| "无法获取文件所在目录".to_string())?
    } else if path.is_dir() {
        path
    } else {
        return Err("路径不存在".to_string());
    };

    // 根据平台打开目录
    #[cfg(target_os = "macos")]
    {
        Command::new("open")
            .arg(dir_path)
            .spawn()
            .map_err(|e| format!("打开目录失败: {}", e))?;
    }

    #[cfg(target_os = "windows")]
    {
        // Windows 上使用 explorer /select, 可以选中文件（如果传入的是文件路径）
        // 如果传入的是目录，直接打开目录
        if is_file {
            // 如果是文件，打开目录并选中文件
            let file_path_str = path.to_string_lossy().to_string();
            Command::new("explorer")
                .args(["/select,", &file_path_str])
                .spawn()
                .map_err(|e| format!("打开目录失败: {}", e))?;
        } else {
            // 如果是目录，直接打开
            let dir_path_str = dir_path.to_string_lossy().to_string();
            Command::new("explorer")
                .arg(&dir_path_str)
                .spawn()
                .map_err(|e| format!("打开目录失败: {}", e))?;
        }
    }

    #[cfg(target_os = "linux")]
    {
        // Linux 上尝试使用 xdg-open
        Command::new("xdg-open")
            .arg(dir_path)
            .spawn()
            .map_err(|e| format!("打开目录失败: {}", e))?;
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "linux")))]
    {
        return Err("不支持的操作系统".to_string());
    }

    Ok(())
}
