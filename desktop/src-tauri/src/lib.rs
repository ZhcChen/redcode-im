use tauri::{AppHandle, Manager, Window, WindowEvent};

mod cache;

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

    window
        .set_size(LogicalSize::new(width, height))
        .map_err(|e| e.to_string())?;
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    window.center().map_err(|e| e.to_string())?;
    Ok(())
}

// 自定义命令：应用准备就绪
#[tauri::command]
async fn app_ready(app: AppHandle) -> Result<(), String> {
    println!("应用已准备就绪，准备显示主窗口");

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
    println!("关闭启动画面");

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
    println!("设置窗口标题: {}", title);

    if let Some(main_window) = app.get_webview_window("main") {
        main_window.set_title(&title).map_err(|e| e.to_string())?;
    }

    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_http::init())
        .invoke_handler(tauri::generate_handler![
            force_center_window,
            set_window_size_and_center,
            app_ready,
            close_splashscreen,
            set_window_title,
            hide_to_tray,
            show_from_tray,
            quit_app,
            cache::cache_save_value,
            cache::cache_load_value,
            cache::cache_clear_value
        ])
        .setup(|app| {
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
                println!("[Rust Setup] 自动关闭启动画面...");

                // 关闭启动画面
                if let Some(splash_window) = app_handle.get_webview_window("splashscreen") {
                    let _ = splash_window.close();
                    println!("[Rust Setup] ✅ 启动画面已关闭");
                }

                // 显示主窗口
                if let Some(main_window) = app_handle.get_webview_window("main") {
                    let _ = main_window.show();
                    let _ = main_window.set_focus();
                    println!("[Rust Setup] ✅ 主窗口已显示");
                }
            });

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

                    println!("[Main Window] 窗口已隐藏到系统托盘");
                }
                // splashscreen 等其他窗口正常关闭,不拦截
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
