use crate::error::AppError;

/// 大文件分片直传阈值：<= 5MB 继续走单文件直传；> 5MB 才使用分片上传
pub const MULTIPART_THRESHOLD_BYTES: i64 = 5 * 1024 * 1024;

/// 默认分片大小：8MB（兼顾请求次数与内存占用）
pub const DEFAULT_PART_SIZE_BYTES: i64 = 8 * 1024 * 1024;

/// S3 兼容分片上传最小分片大小（除最后一片外）：1MB
pub const MIN_PART_SIZE_BYTES: i64 = 1 * 1024 * 1024;

/// S3 兼容分片上传最大分片数：10,000
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_div_ceil_i64_basic() {
        assert_eq!(div_ceil_i64(10, 3), 4);
        assert_eq!(div_ceil_i64(9, 3), 3);
        assert_eq!(div_ceil_i64(1, 1), 1);
        assert_eq!(div_ceil_i64(0, 5), 0);
    }

    #[test]
    fn test_div_ceil_i64_zero_divisor() {
        assert_eq!(div_ceil_i64(10, 0), 0);
        assert_eq!(div_ceil_i64(10, -1), 0);
    }

    #[test]
    fn test_round_up_to_multiple_basic() {
        assert_eq!(round_up_to_multiple(10, 5), 10);
        assert_eq!(round_up_to_multiple(11, 5), 15);
        assert_eq!(round_up_to_multiple(1, 1024), 1024);
    }

    #[test]
    fn test_round_up_to_multiple_edge_cases() {
        assert_eq!(round_up_to_multiple(10, 0), 10);
        assert_eq!(round_up_to_multiple(10, -1), 10);
    }

    #[test]
    fn test_plan_multipart_upload_small_file_rejected() {
        // 小于阈值的文件应该被拒绝
        let result = plan_multipart_upload(MULTIPART_THRESHOLD_BYTES);
        assert!(result.is_err());

        let result = plan_multipart_upload(1024 * 1024); // 1MB
        assert!(result.is_err());
    }

    #[test]
    fn test_plan_multipart_upload_zero_or_negative() {
        let result = plan_multipart_upload(0);
        assert!(result.is_err());

        let result = plan_multipart_upload(-100);
        assert!(result.is_err());
    }

    #[test]
    fn test_plan_multipart_upload_normal_file() {
        // 10MB 文件
        let file_size = 10 * 1024 * 1024;
        let result = plan_multipart_upload(file_size);
        assert!(result.is_ok());

        let (part_size, total_parts) = result.unwrap();
        assert!(part_size >= MIN_PART_SIZE_BYTES as i32);
        assert!(total_parts > 0);
        assert!(total_parts <= MAX_PARTS as i32);
        // 验证分片能覆盖整个文件
        assert!((part_size as i64) * (total_parts as i64) >= file_size);
    }

    #[test]
    fn test_plan_multipart_upload_large_file() {
        // 100GB 文件
        let file_size: i64 = 100 * 1024 * 1024 * 1024;
        let result = plan_multipart_upload(file_size);
        assert!(result.is_ok());

        let (part_size, total_parts) = result.unwrap();
        assert!(total_parts <= MAX_PARTS as i32);
        assert!((part_size as i64) * (total_parts as i64) >= file_size);
    }

    #[test]
    fn test_plan_multipart_upload_exact_threshold() {
        // 正好超过阈值 1 字节
        let file_size = MULTIPART_THRESHOLD_BYTES + 1;
        let result = plan_multipart_upload(file_size);
        assert!(result.is_ok());
    }

    #[test]
    fn test_constants() {
        // 验证常量值合理
        assert!(MULTIPART_THRESHOLD_BYTES > 0);
        assert!(DEFAULT_PART_SIZE_BYTES >= MIN_PART_SIZE_BYTES);
        assert!(MAX_PARTS > 0);
        assert_eq!(MIN_PART_SIZE_BYTES, 1024 * 1024); // 1MB
    }
}
