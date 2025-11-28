//! 通知相关命令

use std::{fs, path::PathBuf, process::Command};
use tauri::{AppHandle, Manager, Window};

// 内置提示音二进制（放置于 resources/notification_chime.wav）
const CHIME_BYTES: &[u8] = include_bytes!("../../resources/notification_chime.wav");

/// 确保提示音落地到可访问路径（缓存目录），并返回路径
fn ensure_chime_file(app: &AppHandle) -> Option<PathBuf> {
    let cache_dir = app.path().app_cache_dir().ok()?;
    let target = cache_dir.join("notification_chime.wav");

    // 若已存在且大小匹配，直接用
    if let Ok(meta) = fs::metadata(&target) {
        if meta.len() == CHIME_BYTES.len() as u64 {
            return Some(target);
        }
    }

    // 重写文件
    if let Some(parent) = target.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if fs::write(&target, CHIME_BYTES).is_ok() {
        return Some(target);
    }
    None
}

/// 播放系统提示音
#[tauri::command]
pub async fn play_notification_sound(app: AppHandle) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        if let Some(path) = ensure_chime_file(&app) {
            if Command::new("afplay")
                .arg(path.to_string_lossy().into_owned())
                .status()
                .is_ok()
            {
                return Ok(());
            }
        }
        // 退回系统自带音效
        for path in [
            "/System/Library/Sounds/Ping.aiff",
            "/System/Library/Sounds/Funk.aiff",
        ] {
            if Command::new("afplay").arg(path).status().is_ok() {
                return Ok(());
            }
        }
        // 最后兜底 beep
        if Command::new("osascript")
            .args(["-e", "beep 1"])
            .status()
            .is_ok()
        {
            return Ok(());
        }
        return Err("macOS: failed to play system sound".into());
    }

    #[cfg(target_os = "windows")]
    {
        let mut script_parts: Vec<String> = Vec::new();
        if let Some(path) = ensure_chime_file(&app) {
            let p = path.to_string_lossy().replace('\'', "''");
            script_parts.push(format!("(New-Object Media.SoundPlayer '{}').PlaySync()", p));
        }
        script_parts.push(
            "(New-Object Media.SoundPlayer 'C:\\Windows\\Media\\Windows Notify Calendar.wav').PlaySync()"
                .to_string(),
        );
        let joined = script_parts.join("; ");
        let play_wav = Command::new("powershell")
            .args(["-c", joined.as_str()])
            .status();
        if play_wav.is_ok() && play_wav.unwrap().success() {
            return Ok(());
        }
        let beep = Command::new("powershell")
            .args(["-c", "[console]::beep(1000,200)"])
            .status();
        if beep.is_ok() && beep.unwrap().success() {
            return Ok(());
        }
        return Err("windows: failed to play system sound".into());
    }

    #[cfg(target_os = "linux")]
    {
        // 优先播放内置音频
        if let Some(path) = ensure_chime_file(&app) {
            let p = path.to_string_lossy().to_string();
            for (bin, args) in [
                ("paplay", vec![p.as_str()]),
                ("aplay", vec![p.as_str()]),
                ("canberra-gtk-play", vec!["-i", "message-new-instant"]),
                (
                    "paplay",
                    vec!["/usr/share/sounds/freedesktop/stereo/message.oga"],
                ),
                ("aplay", vec!["/usr/share/sounds/alsa/Front_Center.wav"]),
            ] {
                let status = Command::new(bin).args(args).status();
                if status.is_ok() && status.unwrap().success() {
                    return Ok(());
                }
            }
        }
        return Err("linux: failed to play system sound".into());
    }

    #[allow(unreachable_code)]
    Err("unsupported platform".into())
}

/// 请求用户注意（任务栏闪烁/跳动）
#[tauri::command]
pub async fn request_attention(window: Window) -> Result<(), String> {
    // 获取主窗口
    if let Some(main_window) = window.app_handle().get_webview_window("main") {
        // 检查窗口是否最小化或未获得焦点
        if main_window.is_minimized().unwrap_or(false) || !main_window.is_focused().unwrap_or(true)
        {
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
                let _ = Command::new("osascript").arg("-e").arg(script).spawn();
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
                let _ = Command::new("wmctrl").args(&["-a", "Chatly"]).spawn();
            }
        }
    }

    Ok(())
}
