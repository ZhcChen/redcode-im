#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::env;
use std::process::Command;
use tauri::App;

// 简单的日志记录函数（由于更新器是独立的，不使用主应用的logger）
fn log_message(message: String) {
    eprintln!("[UPDATER] {}", message);
}

// 防止与主应用冲突的窗口标识
static WINDOW_LABEL: &str = "updater";

fn main() {
    // 获取命令行参数：安装程序路径
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: updater <installer_path>");
        std::process::exit(1);
    }

    let installer_path = args[1].clone();

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .setup(move |app| {
            setup_updater_window(app, installer_path);
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running updater");
}

fn setup_updater_window(app: &mut App, installer_path: String) {
    // 在新线程中执行安装，避免阻塞UI
    std::thread::spawn(move || {
        execute_installer(&installer_path);
    });
}

fn execute_installer(installer_path: &str) {
    // 立即开始执行安装，让用户看到进度
    log_message(format!("[updater] 开始执行安装程序: {}", installer_path));
    log_message(format!("[updater] 安装程序存在: {}", std::path::Path::new(installer_path).exists()));

    // 根据平台执行安装程序
    #[cfg(target_os = "windows")]
    {
        // Windows: 使用PowerShell静默启动安装程序
        log_message("[updater] 使用PowerShell启动Windows安装程序".to_string());

        let powershell_command = format!("Start-Process -FilePath '{}' -Verb RunAs", installer_path.replace("'", "''"));
        log_message(format!("[updater] PowerShell命令: {}", powershell_command));

        let result = Command::new("powershell")
            .args([
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-WindowStyle",
                "Hidden",
                "-Command",
                &powershell_command,
            ])
            .spawn();

        match result {
            Ok(child) => {
                log_message(format!("[updater] PowerShell进程已启动，PID: {}", child.id()));
                // 安装程序已启动，等待一会儿让用户看到安装程序启动，然后退出更新器
                std::thread::sleep(std::time::Duration::from_millis(3000));
                log_message("[updater] 更新器正常退出".to_string());
                std::process::exit(0);
            }
            Err(e) => {
                log_message(format!("[updater] 启动安装程序失败: {}", e));
                eprintln!("Failed to start installer: {}", e);
                std::process::exit(1);
            }
        }
    }

    #[cfg(target_os = "macos")]
    {
        // macOS: 直接执行安装程序
        let result = Command::new("open")
            .arg(installer_path)
            .spawn();

        match result {
            Ok(_) => {
                std::thread::sleep(std::time::Duration::from_millis(2000));
                std::process::exit(0);
            }
            Err(e) => {
                eprintln!("Failed to start installer: {}", e);
                std::process::exit(1);
            }
        }
    }

    #[cfg(target_os = "linux")]
    {
        // Linux: 直接执行安装程序
        let result = Command::new(installer_path)
            .spawn();

        match result {
            Ok(_) => {
                std::thread::sleep(std::time::Duration::from_millis(2000));
                std::process::exit(0);
            }
            Err(e) => {
                eprintln!("Failed to start installer: {}", e);
                std::process::exit(1);
            }
        }
    }
}
