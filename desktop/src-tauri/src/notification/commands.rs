//! 通知相关命令

use std::{fs, path::PathBuf, process::Command};
use tauri::{AppHandle, Manager, Window};

// 内置提示音资源（mp3 主音色，wav 兼容声）
const CHIME_MP3: &[u8] = include_bytes!("../../resources/notification_chime.mp3");
const CHIME_WAV: &[u8] = include_bytes!("../../resources/notification_chime.wav");

fn write_if_needed(target: &PathBuf, bytes: &[u8]) -> Option<PathBuf> {
    if let Ok(meta) = fs::metadata(target) {
        if meta.len() == bytes.len() as u64 {
            return Some(target.clone());
        }
    }
    if let Some(parent) = target.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if fs::write(target, bytes).is_ok() {
        return Some(target.clone());
    }
    None
}

fn ensure_mp3_file(app: &AppHandle) -> Option<PathBuf> {
    let cache = app.path().app_cache_dir().ok()?;
    let target = cache.join("notification_chime.mp3");
    write_if_needed(&target, CHIME_MP3)
}

fn ensure_wav_file(app: &AppHandle) -> Option<PathBuf> {
    let cache = app.path().app_cache_dir().ok()?;
    let target = cache.join("notification_chime.wav");
    write_if_needed(&target, CHIME_WAV)
}

/// 播放系统提示音
#[tauri::command]
pub async fn play_notification_sound(app: AppHandle) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        // 优先播放内置 mp3，其次 wav，再退系统音
        if let Some(path) = ensure_mp3_file(&app) {
            if Command::new("afplay")
                .arg(path.to_string_lossy().into_owned())
                .status()
                .is_ok()
            {
                return Ok(());
            }
        }
        if let Some(path) = ensure_wav_file(&app) {
            if Command::new("afplay")
                .arg(path.to_string_lossy().into_owned())
                .status()
                .is_ok()
            {
                return Ok(());
            }
        }
        for path in [
            "/System/Library/Sounds/Ping.aiff",
            "/System/Library/Sounds/Funk.aiff",
        ] {
            if Command::new("afplay").arg(path).status().is_ok() {
                return Ok(());
            }
        }
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
        // 尝试 mp3（MediaPlayer），再尝试 wav（SoundPlayer），再 Beep
        if let Some(path) = ensure_mp3_file(&app) {
            let p = path.to_string_lossy().replace('\'', "''");
            let script = format!(
                r#"
Add-Type -AssemblyName presentationcore;
$player = New-Object System.Windows.Media.MediaPlayer;
$player.Open([Uri] "file:///{mp3}");
$player.Volume = 1.0;
$player.Play();
Start-Sleep -Milliseconds 700;
"#,
                mp3 = p
            );
            let status = Command::new("powershell")
                .args(["-c", script.as_str()])
                .status();
            if status.is_ok() && status.unwrap().success() {
                return Ok(());
            }
        }

        if let Some(path) = ensure_wav_file(&app) {
            let p = path.to_string_lossy().replace('\'', "''");
            let script = format!("(New-Object Media.SoundPlayer '{}').PlaySync()", p);
            let status = Command::new("powershell")
                .args(["-c", script.as_str()])
                .status();
            if status.is_ok() && status.unwrap().success() {
                return Ok(());
            }
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
        // 尝试 mp3 -> wav -> 常规
        if let Some(path) = ensure_mp3_file(&app) {
            let p = path.to_string_lossy().to_string();
            for (bin, args) in [
                ("paplay", vec![p.as_str()]),
                ("aplay", vec![p.as_str()]),
                ("canberra-gtk-play", vec!["-i", "message-new-instant"]),
            ] {
                let status = Command::new(bin).args(args).status();
                if status.is_ok() && status.unwrap().success() {
                    return Ok(());
                }
            }
        }

        if let Some(path) = ensure_wav_file(&app) {
            let p = path.to_string_lossy().to_string();
            for (bin, args) in [
                ("paplay", vec![p.as_str()]),
                ("aplay", vec![p.as_str()]),
                ("canberra-gtk-play", vec!["-i", "message-new-instant"]),
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
    if let Some(main_window) = window.app_handle().get_webview_window("main") {
        if main_window.is_minimized().unwrap_or(false) || !main_window.is_focused().unwrap_or(true)
        {
            #[cfg(target_os = "macos")]
            {
                let script = r#"
                tell application "System Events"
                    set frontmost of process "Chatly" to true
                end tell
                "#;
                let _ = Command::new("osascript").arg("-e").arg(script).spawn();
            }

            #[cfg(target_os = "windows")]
            {
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
                let _ = Command::new("wmctrl").args(&["-a", "Chatly"]).spawn();
            }
        }
    }

    Ok(())
}
