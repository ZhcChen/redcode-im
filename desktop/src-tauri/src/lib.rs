use tauri::{AppHandle, Manager, Window, WindowEvent};

// 导入模块
mod account;
mod cache;
mod http;
mod logger;
mod message_search;
mod path_utils;
mod updater;
mod websocket;

use account::commands::*;
use account::AccountManager;
use http::client::create_http_client;
use http::commands::*;
use http::types::HttpClientConfig;
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

    // 获取当前尺寸
    let current_size = window.inner_size().map_err(|e| e.to_string())?;
    logger::log_message("[RUST_RESIZE] ========== 设置窗口尺寸 ==========");
    logger::log_message(format!(
        "[RUST_RESIZE] 调整前尺寸: {}x{}",
        current_size.width, current_size.height
    ));
    logger::log_message(format!("[RUST_RESIZE] 目标尺寸: {}x{}", width, height));

    window
        .set_size(LogicalSize::new(width, height))
        .map_err(|e| e.to_string())?;
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    window.center().map_err(|e| e.to_string())?;

    // 获取调整后的尺寸
    let after_size = window.inner_size().map_err(|e| e.to_string())?;
    logger::log_message(format!(
        "[RUST_RESIZE] 调整后尺寸: {}x{}",
        after_size.width, after_size.height
    ));
    logger::log_message("[RUST_RESIZE] ========== 设置完成 ==========");

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

// 自定义命令：生成视频首帧缩略图
#[tauri::command]
async fn generate_video_thumbnail(
  video_path: String,
  output_path: String,
  time_sec: f64,
) -> Result<String, String> {
    use std::process::Command;

    // 检查 ffmpeg 是否可用
    let ffmpeg_check = Command::new("ffmpeg").arg("-version").output();
    if let Err(e) = ffmpeg_check {
        return Err(format!("未找到 ffmpeg，请先安装 ffmpeg: {}", e));
    }

    // 使用 ffmpeg 生成缩略图
    let output = Command::new("ffmpeg")
        .args(&[
            "-i", &video_path,
            "-ss", &time_sec.to_string(),
            "-vframes", "1",
            "-vf", "scale=320:-1",
            "-q:v", "2",
            "-y", // 覆盖输出文件
            &output_path,
        ])
        .output()
        .map_err(|e| format!("执行 ffmpeg 失败: {}", e))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("ffmpeg 错误: {}", stderr));
    }

    Ok(output_path)
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
        // 注册状态
        .manage(http_client_state)
        .manage(ws_manager)
        .manage(account_manager)
        .invoke_handler(tauri::generate_handler![
            // 窗口相关命令
            force_center_window,
            set_window_size_and_center,
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
            // 缓存相关命令
            cache::cache_save_value,
            cache::cache_load_value,
            cache::cache_clear_value,
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
            // WebSocket 相关命令
            ws_connect,
            ws_disconnect,
            ws_join_room,
            ws_leave_room,
            ws_join_rooms,
            ws_get_status,
            ws_get_subscribed_rooms
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
