//! 统一的主键生成工具，默认使用 UUID v7。
//!
//! 后续若接入独立的 ID 分配服务（如雪花算法或集中式 ID 中心），
//! 可在此处扩展并替换默认实现，减少业务代码改动。

use uuid::Uuid;

/// 生成一个全局唯一的标识符。
#[inline]
pub fn generate() -> Uuid {
    Uuid::now_v7()
}

/// 可选的生成器接口，便于未来扩展为可插拔实现。
#[allow(dead_code)]
pub trait IdGenerator {
    fn generate(&self) -> Uuid;
}

/// 默认实现：使用 UUID v7，具备时间有序性，适合分布式场景。
#[allow(dead_code)]
#[derive(Clone, Copy, Debug, Default)]
pub struct UuidV7Generator;

impl IdGenerator for UuidV7Generator {
    #[inline]
    fn generate(&self) -> Uuid {
        Uuid::now_v7()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    #[test]
    fn test_generate_returns_valid_uuid() {
        let id = generate();
        // UUID v7 的版本号应该是 7
        assert_eq!(id.get_version_num(), 7);
    }

    #[test]
    fn test_generate_returns_unique_ids() {
        let mut ids = HashSet::new();
        for _ in 0..1000 {
            let id = generate();
            assert!(ids.insert(id), "生成的 ID 应该唯一");
        }
    }

    #[test]
    fn test_generate_is_time_ordered() {
        let id1 = generate();
        let id2 = generate();
        // UUID v7 是时间有序的，后生成的应该大于等于先生成的
        assert!(id2 >= id1, "后生成的 ID 应该大于等于先生成的");
    }

    #[test]
    fn test_uuid_v7_generator_trait() {
        let generator = UuidV7Generator;
        let id = generator.generate();
        assert_eq!(id.get_version_num(), 7);
    }

    #[test]
    fn test_uuid_v7_generator_default() {
        let generator = UuidV7Generator::default();
        let id = generator.generate();
        assert_eq!(id.get_version_num(), 7);
    }
}
