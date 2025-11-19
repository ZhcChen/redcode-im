#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::env;
use std::process::Command;
use tauri::App;

// 简单的日志记录函数（由于更新器是独立的，不使用主应用的logger）
fn log_message(message: String) {
    eprintln!("[UPDATER] {}", message);
}

fn main() {
    // 获取命令行参数：安装程序路径
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: updater <installer_path>");
        std::process::exit(1);
    }

    let installer_path = args[1].clone();

    // 直接执行安装，不显示任何GUI
    execute_installer(&installer_path);
}

fn execute_installer(installer_path: &str) {
    // 短暂延迟，让用户看到加载界面
    std::thread::sleep(std::time::Duration::from_millis(500));

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
                // 等待1秒让安装程序启动，然后退出更新器
                std::thread::sleep(std::time::Duration::from_millis(1000));
                log_message("[updater] 更新器退出".to_string());
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
                // 等待1秒让安装程序启动，然后退出更新器
                std::thread::sleep(std::time::Duration::from_millis(1000));
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
                // 等待1秒让安装程序启动，然后退出更新器
                std::thread::sleep(std::time::Duration::from_millis(1000));
                std::process::exit(0);
            }
            Err(e) => {
                eprintln!("Failed to start installer: {}", e);
                std::process::exit(1);
            }
        }
    }
}
