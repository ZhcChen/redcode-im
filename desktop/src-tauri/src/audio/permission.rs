//! 麦克风权限检查模块
//!
//! 提供跨平台的麦克风权限检查和请求功能。

use serde::{Deserialize, Serialize};

/// 权限状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PermissionStatus {
    /// 已授权
    Granted,
    /// 已拒绝
    Denied,
    /// 未确定（尚未请求过）
    Undetermined,
    /// 受限（系统策略限制）
    Restricted,
}

impl std::fmt::Display for PermissionStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            PermissionStatus::Granted => write!(f, "granted"),
            PermissionStatus::Denied => write!(f, "denied"),
            PermissionStatus::Undetermined => write!(f, "undetermined"),
            PermissionStatus::Restricted => write!(f, "restricted"),
        }
    }
}

/// macOS 麦克风权限检查
#[cfg(target_os = "macos")]
pub mod macos {
    use super::PermissionStatus;
    use objc::class;
    use objc::runtime::{Class, Object};
    use objc::{msg_send, sel, sel_impl};

    /// 检查麦克风权限状态
    pub fn check_permission() -> PermissionStatus {
        unsafe {
            let av_class = match Class::get("AVCaptureDevice") {
                Some(class) => class,
                None => return PermissionStatus::Undetermined,
            };

            // AVMediaTypeAudio
            let media_type: *const Object =
                msg_send![class!(NSString), stringWithUTF8String: b"soun\0".as_ptr()];

            // authorizationStatusForMediaType:
            let status: i64 = msg_send![av_class, authorizationStatusForMediaType: media_type];

            // AVAuthorizationStatus:
            // 0 = NotDetermined
            // 1 = Restricted
            // 2 = Denied
            // 3 = Authorized
            match status {
                0 => PermissionStatus::Undetermined,
                1 => PermissionStatus::Restricted,
                2 => PermissionStatus::Denied,
                3 => PermissionStatus::Granted,
                _ => PermissionStatus::Undetermined,
            }
        }
    }

    /// 请求麦克风权限
    pub fn request_permission() -> Result<bool, String> {
        use std::sync::mpsc;

        unsafe {
            let av_class = match Class::get("AVCaptureDevice") {
                Some(class) => class,
                None => return Err("AVCaptureDevice 类不可用".to_string()),
            };

            let media_type: *const Object =
                msg_send![class!(NSString), stringWithUTF8String: b"soun\0".as_ptr()];

            let (tx, rx) = mpsc::channel();

            // 创建一个 block 来接收回调
            let block = block::ConcreteBlock::new(move |granted: bool| {
                let _ = tx.send(granted);
            });
            let block = block.copy();

            // requestAccessForMediaType:completionHandler:
            let _: () = msg_send![av_class, requestAccessForMediaType: media_type completionHandler: &*block];

            // 等待回调结果（最多等待 30 秒）
            match rx.recv_timeout(std::time::Duration::from_secs(30)) {
                Ok(granted) => Ok(granted),
                Err(_) => Err("请求权限超时".to_string()),
            }
        }
    }
}

/// Windows 麦克风权限检查
#[cfg(target_os = "windows")]
pub mod windows {
    use super::PermissionStatus;

    /// 检查麦克风权限状态
    ///
    /// Windows 上使用 cpal 尝试枚举设备来检测权限。
    /// 如果能成功获取输入设备列表，则认为有权限。
    pub fn check_permission() -> PermissionStatus {
        use cpal::traits::{DeviceTrait, HostTrait};

        let host = cpal::default_host();

        // 尝试获取默认输入设备
        match host.default_input_device() {
            Some(device) => {
                // 尝试获取支持的配置
                match device.supported_input_configs() {
                    Ok(_) => PermissionStatus::Granted,
                    Err(_) => PermissionStatus::Denied,
                }
            }
            None => PermissionStatus::Denied,
        }
    }

    /// 请求麦克风权限
    ///
    /// Windows 10/11 会在首次访问麦克风时自动弹出权限请求对话框。
    /// 这里通过尝试打开音频流来触发系统权限请求。
    pub fn request_permission() -> Result<bool, String> {
        use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

        let host = cpal::default_host();

        let device = host
            .default_input_device()
            .ok_or_else(|| "未找到可用的麦克风设备".to_string())?;

        let config = device
            .default_input_config()
            .map_err(|e| format!("获取麦克风配置失败: {}", e))?;

        // 尝试创建输入流来触发权限请求
        let stream = device
            .build_input_stream_raw(
                &config.into(),
                cpal::SampleFormat::F32,
                move |_data: &cpal::Data, _info: &cpal::InputCallbackInfo| {
                    // 空回调，仅用于触发权限
                },
                move |err| {
                    eprintln!("音频流错误: {}", err);
                },
                None,
            )
            .map_err(|e| format!("创建音频流失败: {}", e))?;

        // 尝试播放流
        stream
            .play()
            .map_err(|e| format!("启动音频流失败: {}", e))?;

        // 立即停止
        drop(stream);

        // 如果到这里没有错误，说明权限已授予
        Ok(true)
    }
}

/// Linux 麦克风权限检查（Linux 通常不需要显式权限）
#[cfg(target_os = "linux")]
pub mod linux {
    use super::PermissionStatus;

    pub fn check_permission() -> PermissionStatus {
        use cpal::traits::{DeviceTrait, HostTrait};

        let host = cpal::default_host();

        match host.default_input_device() {
            Some(device) => match device.supported_input_configs() {
                Ok(_) => PermissionStatus::Granted,
                Err(_) => PermissionStatus::Denied,
            },
            None => PermissionStatus::Denied,
        }
    }

    pub fn request_permission() -> Result<bool, String> {
        // Linux 不需要显式请求权限
        Ok(check_permission() == PermissionStatus::Granted)
    }
}

/// 跨平台权限检查
pub fn check_microphone_permission() -> PermissionStatus {
    #[cfg(target_os = "macos")]
    {
        macos::check_permission()
    }

    #[cfg(target_os = "windows")]
    {
        windows::check_permission()
    }

    #[cfg(target_os = "linux")]
    {
        linux::check_permission()
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "linux")))]
    {
        PermissionStatus::Undetermined
    }
}

/// 跨平台权限请求
pub fn request_microphone_permission() -> Result<bool, String> {
    #[cfg(target_os = "macos")]
    {
        macos::request_permission()
    }

    #[cfg(target_os = "windows")]
    {
        windows::request_permission()
    }

    #[cfg(target_os = "linux")]
    {
        linux::request_permission()
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "linux")))]
    {
        Err("不支持的平台".to_string())
    }
}
