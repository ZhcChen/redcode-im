//! 通知相关命令

use tauri::{AppHandle, Manager, Window};

/// 播放系统提示音
#[tauri::command]
pub async fn play_notification_sound(_app: AppHandle) -> Result<(), String> {
    // 使用系统默认的通知声音
    // 在不同平台上播放默认的通知声音
    #[cfg(target_os = "macos")]
    {
        use std::process::Command;
        // 在 macOS 上使用 afplay 播放系统提示音
        let _ = Command::new("afplay")
            .arg("/System/Library/Sounds/Ping.aiff")
            .spawn();
    }

    #[cfg(target_os = "windows")]
    {
        use std::process::Command;
        // 在 Windows 上使用 PowerShell 播放系统声音
        let _ = Command::new("powershell")
            .args(&["-c", "(New-Object Media.SoundPlayer 'C:\\Windows\\Media\\notify.wav').PlaySync()"])
            .spawn();
    }

    #[cfg(target_os = "linux")]
    {
        use std::process::Command;
        // 在 Linux 上使用 paplay 或 aplay
        let _ = Command::new("paplay")
            .arg("/usr/share/sounds/freedesktop/stereo/message.oga")
            .spawn()
            .or_else(|_| {
                Command::new("aplay")
                    .arg("/usr/share/sounds/alsa/Front_Center.wav")
                    .spawn()
            });
    }

    Ok(())
}

/// 请求用户注意（任务栏闪烁/跳动）
#[tauri::command]
pub async fn request_attention(window: Window) -> Result<(), String> {
    // 获取主窗口
    if let Some(main_window) = window.app_handle().get_webview_window("main") {
        // 检查窗口是否最小化或未获得焦点
        if main_window.is_minimized().unwrap_or(false) || !main_window.is_focused().unwrap_or(true) {
            #[cfg(target_os = "macos")]
            {
                // 在 macOS 上，让 Dock 图标跳动
                use std::process::Command;
                // 使用 AppleScript 让应用请求注意
                let script = r#"
                tell application "System Events"
                    set frontmost of process "Chatly" to true
                end tell
                "#;
                let _ = Command::new("osascript")
                    .arg("-e")
                    .arg(script)
                    .spawn();

                // 或者使用 tauri 的原生方法（如果支持的话）
                // 注意：Tauri 2.x 可能还没有直接支持这个功能
            }

            #[cfg(target_os = "windows")]
            {
                // 在 Windows 上，闪烁任务栏
                use std::process::Command;
                // 使用 PowerShell 闪烁任务栏
                let script = r#"
                Add-Type -TypeDefinition @"
                using System;
                using System.Runtime.InteropServices;
                public class FlashWindow {
                    [DllImport("user32.dll")]
                    public static extern bool FlashWindow(IntPtr hwnd, bool bInvert);
                    [DllImport("user32.dll")]
                    public static extern bool FlashWindowEx(ref FLASHWINFO pwfi);
                    [StructLayout(LayoutKind.Sequential)]
                    public struct FLASHWINFO {
                        public uint cbSize;
                        public IntPtr hwnd;
                        public uint dwFlags;
                        public uint uCount;
                        public uint dwTimeout;
                    }
                }
                "@
                $hwnd = (Get-Process -Name "Chatly").MainWindowHandle
                if ($hwnd) {
                    $flash = New-Object FlashWindow.FLASHWINFO
                    $flash.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($flash)
                    $flash.hwnd = $hwnd
                    $flash.dwFlags = 0x0000000C  # FLASHW_ALL
                    $flash.uCount = 3
                    $flash.dwTimeout = 0
                    [FlashWindow]::FlashWindowEx([ref]$flash)
                }
                "#;
                let _ = Command::new("powershell")
                    .arg("-Command")
                    .arg(script)
                    .spawn();
            }

            #[cfg(target_os = "linux")]
            {
                // 在 Linux 上，尝试使用 wmctrl 或其他工具
                use std::process::Command;
                // 让窗口获得焦点
                let _ = Command::new("wmctrl")
                    .args(&["-a", "Chatly"])
                    .spawn();
            }
        }
    }

    Ok(())
}
