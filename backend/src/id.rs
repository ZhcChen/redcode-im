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
