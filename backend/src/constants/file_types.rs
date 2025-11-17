/// 文件类型和大小限制常量

/// 头像文件大小限制（5MB）
pub const AVATAR_MAX_SIZE_BYTES: usize = 5 * 1024 * 1024;

/// 消息附件大小限制
pub const IMAGE_MAX_SIZE_BYTES: usize = 10 * 1024 * 1024; // 10MB
pub const AUDIO_MAX_SIZE_BYTES: usize = 20 * 1024 * 1024; // 20MB
pub const VIDEO_MAX_SIZE_BYTES: usize = 100 * 1024 * 1024; // 100MB
pub const FILE_MAX_SIZE_BYTES: usize = 50 * 1024 * 1024; // 50MB

/// 支持的头像文件类型
pub const AVATAR_ALLOWED_TYPES: &[&str] = &[
    "image/png",
    "image/jpeg",
    "image/jpg",
    "image/webp",
    "image/gif",
    "image/heic",
    "image/heif",
    "image/svg+xml",
];

/// 支持的图片文件类型
pub const IMAGE_ALLOWED_TYPES: &[&str] = &[
    "image/png",
    "image/jpeg",
    "image/jpg",
    "image/webp",
    "image/gif",
    "image/heic",
    "image/heif",
    "image/svg+xml",
    "image/bmp",
    "image/tiff",
];

/// 支持的音频文件类型
pub const AUDIO_ALLOWED_TYPES: &[&str] = &[
    "audio/webm",
    "audio/ogg",
    "audio/wav",
    "audio/mp3",
    "audio/mpeg",
    "audio/mp4",
    "audio/m4a",
    "audio/aac",
    "audio/flac",
    "audio/x-flac",
];

/// 支持的视频文件类型
pub const VIDEO_ALLOWED_TYPES: &[&str] = &[
    "video/mp4",
    "video/webm",
    "video/ogg",
    "video/quicktime",
    "video/x-msvideo",  // avi
    "video/x-matroska", // mkv
];

/// 支持的文档文件类型
pub const DOCUMENT_ALLOWED_TYPES: &[&str] = &[
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "text/plain",
    "text/csv",
];

/// 支持的压缩包文件类型
pub const ARCHIVE_ALLOWED_TYPES: &[&str] = &[
    "application/zip",
    "application/x-zip-compressed",
    "application/x-rar-compressed",
    "application/x-rar",
    "application/vnd.rar",
    "application/x-7z-compressed",
    "application/x-tar",
    "application/gzip",
    "application/x-gzip",
    "application/x-bzip2",
    "application/x-xz",
    "application/x-compress",
    "application/x-compressed",
    "application/x-zip",
    "application/x-cab",
    "application/x-iso9660-image",
    "application/x-apple-diskimage",
];

/// 危险文件类型黑名单（不允许上传）
pub const DANGEROUS_FILE_TYPES: &[&str] = &[
    "application/x-executable",
    "application/x-msdownload",
    "application/x-msdos-program",
    "application/x-sh",
    "application/x-bat",
    "application/x-csh",
    "application/x-ksh",
    "application/x-tcsh",
    "application/x-perl",
    "application/x-python",
    "application/x-ruby",
    "application/x-php",
    "application/javascript",
    "text/javascript",
    "application/java-archive",
    "application/vnd.android.package-archive",
];

/// 根据内容类型获取文件大小限制
pub fn get_max_size_by_content_type(content_type: &str) -> usize {
    let content_type = content_type.to_ascii_lowercase();

    if AVATAR_ALLOWED_TYPES.contains(&content_type.as_str()) {
        AVATAR_MAX_SIZE_BYTES
    } else if IMAGE_ALLOWED_TYPES.contains(&content_type.as_str()) {
        IMAGE_MAX_SIZE_BYTES
    } else if AUDIO_ALLOWED_TYPES.contains(&content_type.as_str()) {
        AUDIO_MAX_SIZE_BYTES
    } else if VIDEO_ALLOWED_TYPES.contains(&content_type.as_str()) {
        VIDEO_MAX_SIZE_BYTES
    } else if DOCUMENT_ALLOWED_TYPES.contains(&content_type.as_str()) {
        FILE_MAX_SIZE_BYTES
    } else if ARCHIVE_ALLOWED_TYPES.contains(&content_type.as_str()) {
        FILE_MAX_SIZE_BYTES
    } else {
        FILE_MAX_SIZE_BYTES // 默认限制
    }
}

/// 检查文件类型是否被允许
pub fn is_content_type_allowed(content_type: &str) -> bool {
    let content_type = content_type.to_ascii_lowercase();

    if DANGEROUS_FILE_TYPES.contains(&content_type.as_str()) {
        return false;
    }

    AVATAR_ALLOWED_TYPES.contains(&content_type.as_str())
        || IMAGE_ALLOWED_TYPES.contains(&content_type.as_str())
        || AUDIO_ALLOWED_TYPES.contains(&content_type.as_str())
        || VIDEO_ALLOWED_TYPES.contains(&content_type.as_str())
        || DOCUMENT_ALLOWED_TYPES.contains(&content_type.as_str())
        || ARCHIVE_ALLOWED_TYPES.contains(&content_type.as_str())
}

/// 检查文件类型是否为图片
#[allow(dead_code)]
pub fn is_image_content_type(content_type: &str) -> bool {
    let content_type = content_type.to_ascii_lowercase();
    IMAGE_ALLOWED_TYPES.contains(&content_type.as_str())
}

/// 检查文件类型是否为音频
#[allow(dead_code)]
pub fn is_audio_content_type(content_type: &str) -> bool {
    let content_type = content_type.to_ascii_lowercase();
    AUDIO_ALLOWED_TYPES.contains(&content_type.as_str())
}

/// 检查文件类型是否为视频
#[allow(dead_code)]
pub fn is_video_content_type(content_type: &str) -> bool {
    let content_type = content_type.to_ascii_lowercase();
    VIDEO_ALLOWED_TYPES.contains(&content_type.as_str())
}
