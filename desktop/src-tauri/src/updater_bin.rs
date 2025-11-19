// 移除 windows_subsystem 属性
// 原因：updater 不再需要 GUI 窗口，直接作为后台进程执行
// 保留此属性会导致创建空白窗口进程，引起雪花界面问题

use std::env;
use std::process::Command;

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

        // 先尝试直接执行（大多数NSIS安装程序不需要管理员权限）
        // 如果失败，再尝试使用管理员权限
        let direct_command = format!("& \"{}\"", installer_path.replace("\"", "`\""));
        log_message(format!("[updater] 尝试直接执行: {}", direct_command));

        let mut result = Command::new("powershell")
            .args([
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-WindowStyle",
                "Hidden",
                "-Command",
                &direct_command,
            ])
            .spawn();

        // 如果直接执行失败，尝试使用管理员权限
        if result.is_err() {
            log_message("[updater] 直接执行失败，尝试使用管理员权限".to_string());
            let admin_command = format!("Start-Process -FilePath \"{}\" -Verb RunAs -Wait", installer_path.replace("\"", "`\""));
            log_message(format!("[updater] 管理员权限命令: {}", admin_command));

            result = Command::new("powershell")
                .args([
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-WindowStyle",
                    "Hidden",
                    "-Command",
                    &admin_command,
                ])
                .spawn();
        }

        match result {
            Ok(child) => {
                log_message(format!("[updater] PowerShell进程已启动，PID: {}", child.id()));
                // 等待2秒让安装程序完全启动
                std::thread::sleep(std::time::Duration::from_millis(2000));
                log_message("[updater] 更新器正常退出".to_string());
                std::process::exit(0);
            }
            Err(e) => {
                log_message(format!("[updater] 启动安装程序失败: {}", e));
                log_message(format!("[updater] 安装程序路径: {}", installer_path));
                log_message(format!("[updater] 工作目录: {:?}", std::env::current_dir()));
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
