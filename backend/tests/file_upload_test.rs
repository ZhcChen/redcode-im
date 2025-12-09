//! 文件上传相关校验逻辑测试（不依赖 HTTP / COS）
//!
//! 覆盖点：
//! - 头像允许的 MIME 类型与大小限制常量；
//! - 消息附件允许的 MIME 类型、危险类型黑名单；
//! - `get_max_size_by_content_type` 的分支逻辑。

use redcode_im_backend::constants::*;

#[test]
fn avatar_allowed_types_and_size_constants() {
    // 头像大小常量为 5MB
    assert_eq!(AVATAR_MAX_SIZE_BYTES, 5 * 1024 * 1024);

    // 常见头像类型应该被允许
    assert!(AVATAR_ALLOWED_TYPES.contains(&"image/png"));
    assert!(AVATAR_ALLOWED_TYPES.contains(&"image/jpeg"));
    assert!(AVATAR_ALLOWED_TYPES.contains(&"image/webp"));

    // 非图片类型例如 PDF 不在头像白名单中
    assert!(!AVATAR_ALLOWED_TYPES.contains(&"application/pdf"));
}

#[test]
fn message_attachment_allowed_and_dangerous_types() {
    // 普通图片/音频/视频类型应被允许
    assert!(is_content_type_allowed("image/png"));
    assert!(is_content_type_allowed("audio/webm"));
    assert!(is_content_type_allowed("video/mp4"));

    // 文档 & 压缩包类型应被允许（用于文件发送）
    assert!(is_content_type_allowed("application/pdf"));
    assert!(is_content_type_allowed("application/zip"));

    // 危险类型应被拒绝
    assert!(!is_content_type_allowed("application/x-msdownload"));
    assert!(!is_content_type_allowed("application/javascript"));

    // 未知类型默认不允许
    assert!(!is_content_type_allowed("application/octet-stream"));
}

#[test]
fn max_size_by_content_type_matches_category() {
    // 头像类型 → 使用 AVATAR_MAX_SIZE_BYTES
    assert_eq!(
        get_max_size_by_content_type("image/png"),
        AVATAR_MAX_SIZE_BYTES
    );

    // 普通图片类型 → IMAGE_MAX_SIZE_BYTES
    assert_eq!(
        get_max_size_by_content_type("image/bmp"),
        IMAGE_MAX_SIZE_BYTES
    );

    // 音频类型 → AUDIO_MAX_SIZE_BYTES
    assert_eq!(
        get_max_size_by_content_type("audio/webm"),
        AUDIO_MAX_SIZE_BYTES
    );

    // 视频类型 → VIDEO_MAX_SIZE_BYTES
    assert_eq!(
        get_max_size_by_content_type("video/mp4"),
        VIDEO_MAX_SIZE_BYTES
    );

    // 文档 / 压缩包 → FILE_MAX_SIZE_BYTES
    assert_eq!(
        get_max_size_by_content_type("application/pdf"),
        FILE_MAX_SIZE_BYTES
    );
    assert_eq!(
        get_max_size_by_content_type("application/zip"),
        FILE_MAX_SIZE_BYTES
    );

    // 未知类型 → 默认 FILE_MAX_SIZE_BYTES
    assert_eq!(
        get_max_size_by_content_type("application/octet-stream"),
        FILE_MAX_SIZE_BYTES
    );
}
