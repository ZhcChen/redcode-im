use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClipboardFileInfo {
    pub path: String,
    pub name: String,
    pub size: u64,
    pub mime: String,
}

#[tauri::command]
pub async fn clipboard_get_files() -> Result<Vec<ClipboardFileInfo>, String> {
    let mut result = Vec::new();

    let paths = collect_clipboard_file_paths();
    if paths.is_empty() {
        return Ok(result);
    }

    let mut seen = HashSet::<String>::new();

    for path in paths {
        let path_string = path.to_string_lossy().to_string();
        if path_string.is_empty() {
            continue;
        }
        if !seen.insert(path_string.clone()) {
            continue;
        }

        let meta = match std::fs::metadata(&path) {
            Ok(meta) => meta,
            Err(_) => continue,
        };

        if !meta.is_file() {
            continue;
        }

        let name = path
            .file_name()
            .and_then(|v| v.to_str())
            .unwrap_or_default()
            .to_string();

        let mime = mime_guess::from_path(&path)
            .first_or_octet_stream()
            .essence_str()
            .to_string();

        result.push(ClipboardFileInfo {
            path: path_string,
            name,
            size: meta.len(),
            mime,
        });
    }

    Ok(result)
}

#[cfg(target_os = "macos")]
fn collect_clipboard_file_paths() -> Vec<PathBuf> {
    use objc::runtime::Object;
    use objc::{class, msg_send, sel, sel_impl};
    use std::ffi::{CStr, CString};
    use std::os::raw::c_char;

    unsafe fn nsstring(value: &str) -> *mut Object {
        let cstr = CString::new(value).unwrap_or_else(|_| CString::new("").unwrap());
        let ns: *mut Object = msg_send![class!(NSString), stringWithUTF8String: cstr.as_ptr()];
        ns
    }

    unsafe fn nsstring_to_string(value: *mut Object) -> Option<String> {
        if value.is_null() {
            return None;
        }
        let c_ptr: *const c_char = msg_send![value, UTF8String];
        if c_ptr.is_null() {
            return None;
        }
        Some(CStr::from_ptr(c_ptr).to_string_lossy().into_owned())
    }

    unsafe fn file_url_string_to_path(url_string: *mut Object) -> Option<PathBuf> {
        if url_string.is_null() {
            return None;
        }

        // NSURL *url = [NSURL URLWithString:url_string];
        let url: *mut Object = msg_send![class!(NSURL), URLWithString: url_string];
        if url.is_null() {
            return None;
        }

        // NSString *path = [url path];
        let path_ns: *mut Object = msg_send![url, path];
        let path_string = nsstring_to_string(path_ns)?;
        if path_string.is_empty() {
            return None;
        }
        Some(PathBuf::from(path_string))
    }

    unsafe {
        let mut out: Vec<PathBuf> = Vec::new();

        let pasteboard: *mut Object = msg_send![class!(NSPasteboard), generalPasteboard];
        if pasteboard.is_null() {
            return out;
        }

        // 1) 优先读取 public.file-url（复制文件时最常见）
        let items: *mut Object = msg_send![pasteboard, pasteboardItems];
        if !items.is_null() {
            let count: usize = msg_send![items, count];
            for idx in 0..count {
                let item: *mut Object = msg_send![items, objectAtIndex: idx];
                if item.is_null() {
                    continue;
                }

                let file_url_type = nsstring("public.file-url");
                let url_string: *mut Object = msg_send![item, stringForType: file_url_type];
                if let Some(path) = file_url_string_to_path(url_string) {
                    out.push(path);
                    continue;
                }

                // 某些应用可能会用 public.url 作为文件 URL 的载体
                let url_type = nsstring("public.url");
                let url_string: *mut Object = msg_send![item, stringForType: url_type];
                if let Some(path) = file_url_string_to_path(url_string) {
                    out.push(path);
                }
            }
        }

        if !out.is_empty() {
            return out;
        }

        // 2) 兼容旧类型：NSFilenamesPboardType -> NSArray<NSString>
        let legacy_type = nsstring("NSFilenamesPboardType");
        let plist: *mut Object = msg_send![pasteboard, propertyListForType: legacy_type];
        if plist.is_null() {
            return out;
        }
        let count: usize = msg_send![plist, count];
        for idx in 0..count {
            let item: *mut Object = msg_send![plist, objectAtIndex: idx];
            if let Some(path_str) = nsstring_to_string(item) {
                if !path_str.is_empty() {
                    out.push(PathBuf::from(path_str));
                }
            }
        }

        out
    }
}

#[cfg(not(target_os = "macos"))]
fn collect_clipboard_file_paths() -> Vec<PathBuf> {
    Vec::new()
}
