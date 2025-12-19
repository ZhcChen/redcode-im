use crate::error::AppError;

/// 大文件分片直传阈值：<= 5MB 继续走单文件直传；> 5MB 才使用分片上传
pub const MULTIPART_THRESHOLD_BYTES: i64 = 5 * 1024 * 1024;

/// 默认分片大小：8MB（兼顾请求次数与内存占用）
pub const DEFAULT_PART_SIZE_BYTES: i64 = 8 * 1024 * 1024;

/// COS/S3 协议分片上传最小分片大小（除最后一片外）：1MB
pub const MIN_PART_SIZE_BYTES: i64 = 1 * 1024 * 1024;

/// COS/S3 分片上传最大分片数：10,000
pub const MAX_PARTS: i64 = 10_000;

fn div_ceil_i64(n: i64, d: i64) -> i64 {
    if d <= 0 {
        return 0;
    }
    (n + d - 1) / d
}

fn round_up_to_multiple(value: i64, multiple: i64) -> i64 {
    if multiple <= 0 {
        return value;
    }
    ((value + multiple - 1) / multiple) * multiple
}

/// 计算分片上传计划（part_size / total_parts）
pub fn plan_multipart_upload(file_size: i64) -> Result<(i32, i32), AppError> {
    if file_size <= 0 {
        return Err(AppError::ValidationError(
            "file_size 必须大于 0".to_string(),
        ));
    }

    if file_size <= MULTIPART_THRESHOLD_BYTES {
        return Err(AppError::ValidationError(format!(
            "文件大小 <= {} 字节，请使用单文件直传（非分片）",
            MULTIPART_THRESHOLD_BYTES
        )));
    }

    let mut part_size = DEFAULT_PART_SIZE_BYTES.max(MIN_PART_SIZE_BYTES);
    part_size = round_up_to_multiple(part_size, MIN_PART_SIZE_BYTES);

    let mut total_parts = div_ceil_i64(file_size, part_size);

    if total_parts > MAX_PARTS {
        // 计算一个“最低可行”的分片大小，使 total_parts <= MAX_PARTS
        let min_required = div_ceil_i64(file_size, MAX_PARTS).max(MIN_PART_SIZE_BYTES);
        part_size = round_up_to_multiple(min_required, MIN_PART_SIZE_BYTES);
        total_parts = div_ceil_i64(file_size, part_size);
    }

    // 若由于 round_up 等原因仍超出，继续增大分片大小直到满足
    while total_parts > MAX_PARTS {
        part_size = part_size.saturating_add(MIN_PART_SIZE_BYTES);
        total_parts = div_ceil_i64(file_size, part_size);
    }

    if part_size > i32::MAX as i64 || total_parts > i32::MAX as i64 {
        return Err(AppError::ValidationError(
            "文件过大，无法生成分片上传计划".to_string(),
        ));
    }

    Ok((part_size as i32, total_parts as i32))
}
