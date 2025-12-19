use tauri::{AppHandle, Manager, Window, WindowEvent};

// 导入模块
mod account;
mod audio;
mod cache;
mod clipboard;
mod http;
mod logger;
mod message_search;
mod notification;
mod path_utils;
mod updater;
mod websocket;

use account::commands::*;
use account::AccountManager;
use audio::commands::*;
use audio::recorder::AudioRecorderState;
use clipboard::commands::clipboard_get_files;
use http::client::create_http_client;
use http::commands::*;
use http::types::HttpClientConfig;
use notification::commands::*;
use path_utils::*;
use updater::{download_update, install_update};
use websocket::commands::*;
use websocket::WebSocketManager;

// 自定义命令：隐藏到系统托盘
#[tauri::command]
async fn hide_to_tray(window: Window) -> Result<(), String> {
    window.hide().map_err(|e| e.to_string())?;
    Ok(())
}

// 自定义命令：从托盘恢复窗口
#[tauri::command]
async fn show_from_tray(window: Window) -> Result<(), String> {
    window.show().map_err(|e| e.to_string())?;
    window.set_focus().map_err(|e| e.to_string())?;
    Ok(())
}

// 自定义命令：完全退出应用
#[tauri::command]
async fn quit_app(app: AppHandle) -> Result<(), String> {
    app.exit(0);
    Ok(())
}

// 自定义命令：强制窗口居中
#[tauri::command]
async fn force_center_window(window: Window) -> Result<(), String> {
    window.center().map_err(|e| e.to_string())?;
    Ok(())
}

// 自定义命令：设置窗口大小并居中
#[tauri::command]
async fn set_window_size_and_center(window: Window, width: f64, height: f64) -> Result<(), String> {
    use tauri::LogicalSize;

    logger::log_message("[RUST_RESIZE] ========== 设置窗口尺寸 ==========");

    // 获取当前窗口信息
    let current_size = window.inner_size().map_err(|e| e.to_string())?;
    let scale_factor = window.scale_factor().map_err(|e| e.to_string())?;
    let is_resizable = window.is_resizable().map_err(|e| e.to_string())?;
    let is_maximized = window.is_maximized().map_err(|e| e.to_string())?;

    // 记录当前状态
    logger::log_message(format!(
        "[RUST_RESIZE] 当前物理尺寸: {}x{}",
        current_size.width, current_size.height
    ));
    logger::log_message(format!("[RUST_RESIZE] DPI 缩放因子: {}", scale_factor));
    logger::log_message(format!(
        "[RUST_RESIZE] 当前逻辑尺寸: {}x{}",
        (current_size.width as f64 / scale_factor) as i32,
        (current_size.height as f64 / scale_factor) as i32
    ));
    logger::log_message(format!("[RUST_RESIZE] 窗口可调整: {}", is_resizable));
    logger::log_message(format!("[RUST_RESIZE] 窗口最大化: {}", is_maximized));
    logger::log_message(format!("[RUST_RESIZE] 目标逻辑尺寸: {}x{}", width, height));

    // 如果窗口不可调整，先设置为可调整
    if !is_resizable {
        logger::log_message("[RUST_RESIZE] 窗口不可调整，尝试设置为可调整");
        if let Err(e) = window.set_resizable(true) {
            logger::log_message(format!("[RUST_RESIZE] 设置可调整失败: {}", e));
        } else {
            logger::log_message("[RUST_RESIZE] 成功设置为可调整");
            // 等待状态生效
            tokio::time::sleep(tokio::time::Duration::from_millis(50)).await;
        }
    }

    // 设置窗口尺寸
    logger::log_message(format!(
        "[RUST_RESIZE] 执行 set_size({}, {})",
        width, height
    ));
    window
        .set_size(LogicalSize::new(width, height))
        .map_err(|e| {
            logger::log_message(format!("[RUST_RESIZE] set_size 失败: {}", e));
            e.to_string()
        })?;

    // 等待尺寸生效
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

    // 居中窗口
    logger::log_message("[RUST_RESIZE] 居中窗口");
    window.center().map_err(|e| {
        logger::log_message(format!("[RUST_RESIZE] center 失败: {}", e));
        e.to_string()
    })?;

    // 获取调整后的尺寸
    let after_size = window.inner_size().map_err(|e| e.to_string())?;
    let after_scale = window.scale_factor().map_err(|e| e.to_string())?;

    logger::log_message(format!(
        "[RUST_RESIZE] 调整后物理尺寸: {}x{}",
        after_size.width, after_size.height
    ));
    logger::log_message(format!(
        "[RUST_RESIZE] 调整后逻辑尺寸: {}x{}",
        (after_size.width as f64 / after_scale) as i32,
        (after_size.height as f64 / after_scale) as i32
    ));

    // 验证是否成功
    let actual_logical_width = (after_size.width as f64 / after_scale) as i32;
    let actual_logical_height = (after_size.height as f64 / after_scale) as i32;
    let success = (actual_logical_width as f64 - width).abs() < 5.0
        && (actual_logical_height as f64 - height).abs() < 5.0;

    logger::log_message(format!(
        "[RUST_RESIZE] 设置结果: {}",
        if success {
            "成功"
        } else {
            "尺寸偏差较大"
        }
    ));
    logger::log_message("[RUST_RESIZE] ========== 设置完成 ==========");

    Ok(())
}

// 自定义命令：启动画面准备就绪
#[tauri::command]
async fn splashscreen_ready(app: AppHandle) -> Result<(), String> {
    if let Some(splash_window) = app.get_webview_window("splashscreen") {
        splash_window.show().map_err(|e| e.to_string())?;
        splash_window.set_focus().map_err(|e| e.to_string())?;
    }
    Ok(())
}

// 自定义命令：应用准备就绪
#[tauri::command]
async fn app_ready(app: AppHandle) -> Result<(), String> {
    logger::log_message("应用已准备就绪，准备显示主窗口");

    // 关闭启动画面并显示主窗口
    if let Some(splash_window) = app.get_webview_window("splashscreen") {
        let _ = splash_window.close();
    }

    if let Some(main_window) = app.get_webview_window("main") {
        let _ = main_window.show();
        let _ = main_window.set_focus();
    }

    Ok(())
}

// 自定义命令：关闭启动画面
#[tauri::command]
async fn close_splashscreen(app: AppHandle) -> Result<(), String> {
    logger::log_message("关闭启动画面");

    if let Some(splash_window) = app.get_webview_window("splashscreen") {
        let _ = splash_window.close();
    }

    if let Some(main_window) = app.get_webview_window("main") {
        let _ = main_window.show();
        let _ = main_window.set_focus();
    }

    Ok(())
}

// 自定义命令：设置窗口标题
#[tauri::command]
async fn set_window_title(app: AppHandle, title: String) -> Result<(), String> {
    logger::log_message(format!("设置窗口标题: {}", title));

    if let Some(main_window) = app.get_webview_window("main") {
        main_window.set_title(&title).map_err(|e| e.to_string())?;
    }

    Ok(())
}

// 自定义命令：生成视频首帧缩略图（通过 Tauri sidecar 调用本地 ffmpeg）
#[tauri::command]
async fn generate_video_thumbnail(
    app: AppHandle,
    video_path: String,
    output_path: String,
    time_sec: f64,
) -> Result<String, String> {
    use std::path::PathBuf;
    use tauri::async_runtime::spawn_blocking;

    use std::path::Path;

    logger::log_message(format!(
        "[VideoThumbnail] 开始生成缩略图, video_path={}, output_path={}, time_sec={}",
        video_path, output_path, time_sec
    ));

    // 确保输出目录存在
    if let Some(parent) = Path::new(&output_path).parent() {
        if !parent.exists() {
            std::fs::create_dir_all(parent).map_err(|e| format!("创建缩略图目录失败: {e}"))?;
        }
    }

    let time_arg = time_sec.to_string();

    // 根据平台确定 ffmpeg 二进制文件名
    #[cfg(all(target_os = "macos", target_arch = "aarch64"))]
    const FFMPEG_BIN: &str = "ffmpeg-aarch64-apple-darwin";
    #[cfg(all(target_os = "macos", target_arch = "x86_64"))]
    const FFMPEG_BIN: &str = "ffmpeg-x86_64-apple-darwin";
    #[cfg(all(target_os = "windows", target_arch = "x86_64"))]
    const FFMPEG_BIN: &str = "ffmpeg-x86_64-pc-windows-msvc.exe";
    #[cfg(not(any(
        all(target_os = "macos", target_arch = "aarch64"),
        all(target_os = "macos", target_arch = "x86_64"),
        all(target_os = "windows", target_arch = "x86_64")
    )))]
    const FFMPEG_BIN: &str = "";

    if FFMPEG_BIN.is_empty() {
        let msg =
            "VideoThumbnail(FFMPEG_UNSUPPORTED): 当前平台暂不支持 ffmpeg 缩略图生成".to_string();
        logger::log_message(&msg);
        return Err(msg);
    }

    // 1. 优先尝试从 resource 目录查找（打包后场景）
    let mut candidates: Vec<PathBuf> = Vec::new();
    if let Ok(mut res_dir) = app.path().resource_dir() {
        res_dir.push("binaries");
        res_dir.push(FFMPEG_BIN);
        candidates.push(res_dir);
    }

    // 2. 开发环境下，直接使用 CARGO_MANIFEST_DIR 下的 binaries 目录
    let mut dev_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    dev_path.push("binaries");
    dev_path.push(FFMPEG_BIN);
    candidates.push(dev_path);

    let ffmpeg_path = match candidates.iter().find(|p| p.exists()) {
        Some(p) => p.clone(),
        None => {
            let msg = format!(
                "VideoThumbnail(FFMPEG_NOT_FOUND): 未找到 ffmpeg 二进制, candidates={:?}",
                candidates
            );
            logger::log_message(&msg);
            return Err(msg);
        }
    };

    // 在线程池中执行阻塞的 ffmpeg 调用
    let video_path_cloned = video_path.clone();
    let output_path_cloned = output_path.clone();

    let handle = spawn_blocking(move || -> Result<String, String> {
        use std::process::Command;

        let output = Command::new(&ffmpeg_path)
            .args([
                "-y",
                "-ss",
                &time_arg,
                "-i",
                &video_path_cloned,
                "-frames:v",
                "1",
                "-vf",
                "scale=320:-1",
                "-vcodec",
                "mjpeg",
                "-q:v",
                "2",
                &output_path_cloned,
            ])
            .output()
            .map_err(|e| {
                let msg = format!("VideoThumbnail(SPAWN): 启动 ffmpeg 失败: {e}");
                logger::log_message(&msg);
                msg
            })?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            // 提取前几行 stderr 作为摘要，避免日志过长
            let mut summary_lines = Vec::new();
            for line in stderr.lines().take(6) {
                summary_lines.push(line.trim());
            }
            let mut stderr_summary = summary_lines.join(" | ");
            if stderr_summary.len() > 800 {
                stderr_summary.truncate(800);
                stderr_summary.push_str("...<truncated>");
            }

            // 简单分类 ffmpeg 错误类型，便于排查
            let kind = if stderr.contains("No such file or directory")
                || stderr.contains("Error opening input")
            {
                "input_not_found"
            } else if stderr.contains("Invalid data found when processing input") {
                "invalid_input"
            } else if stderr.contains("Permission denied") {
                "permission_denied"
            } else {
                "unknown"
            };

            let code = output.status.code();

            logger::log_message(format!(
                "[VideoThumbnail] ffmpeg 执行失败 kind={}, exit_code={:?}, stderr={}",
                kind, code, stderr_summary
            ));

            return Err(format!(
                "VideoThumbnail(FFMPEG_ERROR): kind={}, exit_code={:?}, stderr={}",
                kind, code, stderr_summary
            ));
        }

        Ok(output_path_cloned)
    });

    let generated_path = handle
        .await
        .map_err(|e| format!("执行缩略图任务失败: {e}"))??;

    logger::log_message(format!(
        "[VideoThumbnail] 缩略图生成成功, output_path={}",
        generated_path
    ));

    Ok(generated_path)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // 创建 HTTP 客户端配置
    let http_config = HttpClientConfig::default();

    // 初始化 HTTP 客户端
    let http_client_state = create_http_client(http_config).expect("Failed to create HTTP client");

    // 初始化 WebSocket 管理器
    let ws_manager = WebSocketManager::new();

    // 初始化账号管理器
    let account_manager = AccountManager::new();

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_http::init())
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            let _ = app
                .get_webview_window("main")
                .expect("no main window")
                .set_focus();
        }))
        // 注册状态
        .manage(http_client_state)
        .manage(ws_manager)
        .manage(account_manager)
        .manage(AudioRecorderState::default())
        .invoke_handler(tauri::generate_handler![
            // 窗口相关命令
            force_center_window,
            set_window_size_and_center,
            splashscreen_ready,
            app_ready,
            close_splashscreen,
            set_window_title,
            hide_to_tray,
            show_from_tray,
            quit_app,
            generate_video_thumbnail,
            client_debug,
            // 账号管理命令
            account_init,
            account_add,
            account_get_all,
            account_get_current,
            account_set_current,
            account_remove,
            account_update_unread,
            account_get_settings,
            account_update_order,
            account_load_data,
            // 缓存相关命令
            cache::cache_save_value,
            cache::cache_load_value,
            cache::cache_clear_value,
            // 系统剪贴板相关命令
            clipboard_get_files,
            // 消息搜索相关命令
            message_search::index_message,
            message_search::index_messages,
            message_search::remove_message_index,
            message_search::clear_all_indices,
            message_search::search_messages,
            message_search::get_search_suggestions,
            message_search::get_search_stats,
            message_search::optimize_search_db,
            // HTTP 相关命令
            http_initialize,
            http_set_token,
            http_clear_token,
            http_get,
            http_post,
            http_put,
            http_patch,
            http_delete,
            http_upload,
            http_download,
            http_request,
            http_health,
            http_stats,
            http_batch,
            download_update,
            install_update,
            // 路径工具相关命令
            get_user_download_dir,
            get_user_desktop_dir,
            check_dir_exists,
            check_file_exists,
            create_dir,
            open_file_directory,
            // WebSocket 相关命令（多账号版本）
            ws_connect,
            ws_disconnect,
            ws_disconnect_all,
            ws_set_current_user,
            ws_join_room,
            ws_leave_room,
            ws_join_rooms,
            ws_get_status,
            ws_get_all_status,
            ws_get_subscribed_rooms,
            ws_get_connected_count,
            ws_get_current_user,
            // 通知相关命令
            play_notification_sound,
            request_attention,
            // 音频录制相关命令
            check_microphone_permission,
            request_microphone_permission,
            start_recording,
            stop_recording,
            cancel_recording,
            get_recording_status,
            get_recording_duration
        ])
        .setup(|app| {
            let log_path = logger::init_logger(&app.handle())
                .map_err(|e| -> Box<dyn std::error::Error> { Box::new(e) })?;
            logger::log_message(&format!("日志输出: {}", log_path.display()));

            // 创建系统托盘
            let tray = app.tray_by_id("main-tray").unwrap();

            // 设置托盘菜单
            use tauri::menu::{MenuBuilder, MenuItemBuilder};
            let show_item = MenuItemBuilder::with_id("show", "显示主窗口").build(app)?;
            let quit_item = MenuItemBuilder::with_id("quit", "退出").build(app)?;
            let menu = MenuBuilder::new(app)
                .item(&show_item)
                .separator()
                .item(&quit_item)
                .build()?;

            let _ = tray.set_menu(Some(menu));

            // 托盘菜单点击事件
            let app_handle = app.handle().clone();
            tray.on_menu_event(move |app, event| match event.id().as_ref() {
                "show" => {
                    if let Some(main_window) = app.get_webview_window("main") {
                        let _ = main_window.show();
                        let _ = main_window.set_focus();
                    }
                }
                "quit" => {
                    app_handle.exit(0);
                }
                _ => {}
            });

            // 托盘双击事件
            tray.on_tray_icon_event(|tray, event| {
                if let tauri::tray::TrayIconEvent::DoubleClick { .. } = event {
                    if let Some(main_window) = tray.app_handle().get_webview_window("main") {
                        let _ = main_window.show();
                        let _ = main_window.set_focus();
                    }
                }
            });

            // 设置主窗口并强制居中
            if let Some(main_window) = app.get_webview_window("main") {
                // 强制居中窗口
                let window_clone = main_window.clone();
                tauri::async_runtime::spawn(async move {
                    tokio::time::sleep(tokio::time::Duration::from_millis(200)).await;
                    let _ = window_clone.center();
                });
            }

            // 自动关闭启动画面(作为备用方案)
            let app_handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                // 等待主窗口加载
                tokio::time::sleep(tokio::time::Duration::from_millis(1500)).await;
                logger::log_message("[Rust Setup] 自动关闭启动画面...");

                // 关闭启动画面
                if let Some(splash_window) = app_handle.get_webview_window("splashscreen") {
                    let _ = splash_window.close();
                    logger::log_message("[Rust Setup] ✅ 启动画面已关闭");
                }

                // 显示主窗口
                if let Some(main_window) = app_handle.get_webview_window("main") {
                    let _ = main_window.show();
                    let _ = main_window.set_focus();
                    logger::log_message("[Rust Setup] ✅ 主窗口已显示");
                }
            });

            logger::log_message("Tauri setup 完成");
            Ok(())
        })
        .on_window_event(|window, event| {
            // 拦截窗口关闭事件(仅针对主窗口)
            if let WindowEvent::CloseRequested { api, .. } = event {
                // 只有主窗口才隐藏到托盘,其他窗口正常关闭
                if window.label() == "main" {
                    // 阻止默认关闭行为
                    api.prevent_close();

                    // 隐藏窗口到系统托盘
                    let _ = window.hide();

                    logger::log_message("[Main Window] 窗口已隐藏到系统托盘");
                }
                // splashscreen 等其他窗口正常关闭,不拦截
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
#[tauri::command]
async fn client_debug(payload: serde_json::Value) -> Result<(), String> {
    logger::log_event("CLIENT_DEBUG", payload);
    Ok(())
}
