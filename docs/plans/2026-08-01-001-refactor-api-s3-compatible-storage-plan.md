---
title: "refactor: API 图片存储统一为 S3 兼容协议"
date: 2026-08-01
type: refactor
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
execution: code
---

# refactor: API 图片存储统一为 S3 兼容协议

## Goal Capsule

- **目标：** 将 API 的图片与附件对象存储从 Backblaze B2 专用实现泛化为标准 S3-compatible 实现，使 RustFS 可通过 endpoint、region、access key、secret key 和 bucket 直接接入。
- **范围：** API 存储 provider、运行时配置、管理接口、上传审核、Compose 测试配置及对象存储文档。
- **兼容策略：** 数据库 `provider_type=5` 原位解释为 S3-compatible，避免破坏已有外键和上传记录；旧 `REDCODE_IM_B2_*` 环境变量只作为迁移期 fallback。
- **停止条件：** 若 RustFS 所需操作无法由当前 `aws-sdk-s3` 覆盖，停止引入并行 SDK，先记录具体协议差异。

---

## Product Contract

### Summary

当前 API 已使用 `aws-sdk-s3` 完成对象上传、删除、签名、下载和 multipart，但 provider、环境变量、错误文案及运行时探测仍绑定 Backblaze B2，并依赖 B2 专有 `b2_authorize_account`。RustFS 支持 S3 协议，不支持该专有授权接口，因此需要移除供应商耦合。

### Requirements

- R1. API 对象存储只暴露 `s3_compatible` provider，不提供服务端本地文件 provider。
- R2. RustFS 可使用 HTTP 或 HTTPS endpoint、path-style addressing、自定义 region 和静态访问密钥。
- R3. 保持现有头像、群头像、消息附件、举报附件、版本文件和 multipart 的签名与 commit API 契约不变。
- R4. 运行时配置探测只使用标准 S3 API，不调用 B2 专有授权接口。
- R5. 新部署使用 `REDCODE_IM_S3_*` 环境变量；旧 B2 变量只作为迁移 fallback，并在文档中标记废弃。
- R6. 已存在的 `storage_providers.provider_type=5` 无需数据迁移即可继续读取。
- R7. `avatar_local_path` 等客户端缓存字段不属于 API 对象存储 provider，本轮不删除。

### Scope Boundaries

- 不部署 RustFS 本身，不管理 RustFS 用户和策略。
- 不修改客户端本地媒体缓存。
- 不改变对象 key、哈希去重、上传审计及 multipart 数据模型。
- 不新增数据库 enum，也不修改已有 migration。

---

## Planning Contract

### Key Technical Decisions

- KTD1. **复用 `aws-sdk-s3`。** 当前依赖已覆盖 RustFS 所需操作，不新增 MinIO/RustFS 专用 SDK。
- KTD2. **原位迁移 provider 数值。** 将 Rust 枚举值 `5` 从供应商品牌语义改为 `S3Compatible`，避免修改存量数据和外键关系。
- KTD3. **endpoint 保留 scheme。** 不再通过全局 `REDCODE_IM_STORAGE_SCHEME` 重建 URL；每个 provider 的 endpoint 自身决定 HTTP/HTTPS。
- KTD4. **标准 S3 探测。** 使用 `ListBuckets`、`HeadBucket` 和可选 `CreateBucket` 验证连接与 bucket，不推断 B2 capability 列表。
- KTD5. **环境变量双读单写。** 代码优先读取 `REDCODE_IM_S3_*`，缺失时回退旧 B2 名称；示例和部署文档只推荐新名称。

### Sequence

1. 泛化底层 S3 storage service 和 provider 枚举。
2. 泛化运行时配置、探测、bucket 初始化和 provider 同步。
3. 更新管理接口、审核链路、Compose 环境与文档。
4. 运行 API 单元、集成和 smoke 测试，检查旧变量 fallback。

---

## Implementation Units

### U1. Generic S3 storage service

- **Goal:** 将 `api/src/storage/b2.rs` 泛化为供应商无关的 S3-compatible service。
- **Files:** `api/src/storage/mod.rs`、`api/src/storage/s3.rs`、`api/src/database/models.rs`。
- **Test Scenarios:** HTTP RustFS endpoint；HTTPS endpoint；path-style URL；缺少 bucket；签名 TTL；未知 provider 拒绝；存量数值 5 可读取。
- **Verification:** Rust 单元测试和格式检查。

### U2. Runtime configuration and probe

- **Goal:** 移除 B2 authorize_account，改用标准 S3 API 探测和 bucket 初始化。
- **Files:** `api/src/services/storage_config.rs`、`api/src/database/storage_provider_store.rs`、`api/src/services/file_upload_audit.rs`。
- **Test Scenarios:** 新 S3 环境变量优先；旧 B2 fallback；显式 HTTP endpoint；bucket 存在/缺失；创建成功/失败；凭据错误。
- **Verification:** storage config 单元测试及 Compose external mock 集成测试。

### U3. API contract and deployment configuration

- **Goal:** 管理 API、开发栈和测试栈统一使用 `s3_compatible` 术语与配置。
- **Files:** `api/src/handlers/admin.rs`、`api/docker/dev/docker-compose.yml`、`tests/docker-compose.test.yml`、`tests/mocks/external/`、`docs/reference/api/`、`docs/reference/testing/README.md`。
- **Test Scenarios:** 创建/更新 provider 使用 `s3_compatible`，迁移期兼容旧输入 `backblaze_b2`；bucket 必填；旧数据库记录响应为新类型；上传签名和下载 URL 契约不变。
- **Verification:** `make api.test`、API smoke、文档搜索无活动 B2-only 配置说明。

---

## Verification Contract

| 验证层 | 方法 | 通过信号 |
| --- | --- | --- |
| 静态质量 | `cargo fmt --check`、`git diff --check` | 无格式和语法问题 |
| API 测试 | `make api.test` | Rust 单元与集成测试通过 |
| S3 契约 | external mock 运行上传、head、delete、presign、multipart | 原有上传能力无回归 |
| 配置兼容 | 新旧环境变量优先级测试 | S3 新变量优先，B2 旧变量可回退 |
| 数据兼容 | provider 数值 5 的模型测试 | 无 migration 即可解析为 `s3_compatible` |

---

## Definition of Done

- D1. API 中不存在可创建或选择的 local storage provider。
- D2. RustFS 无需 B2 专有接口即可完成连接探测、bucket 初始化和全部上传流程。
- D3. 新配置与文档使用 `REDCODE_IM_S3_*` 和 `s3_compatible`。
- D4. 旧 B2 环境变量在迁移期仍可启动，但不再作为推荐配置。
- D5. 现有上传路由、响应字段、object key 和数据库引用保持兼容。
- D6. API 存储相关测试、Admin 类型/构建检查、专项 E2E、格式检查和文档一致性检查通过。

## 执行结果

- `cargo check --manifest-path api/Cargo.toml`：通过。
- `cargo test --manifest-path api/Cargo.toml storage:: --lib`：5 项通过。
- `cargo test --manifest-path api/Cargo.toml services::storage_config:: --lib`：9 项通过。
- `tests/mocks/external` 执行 `go test ./...`：通过。
- Admin `npm run type:check`、`npm run build:check`：通过。
- Admin S3 存储配置专项 Playwright：1 项通过。
- `make api.test`：存储相关单元、数据库迁移及 API 集成测试通过；最终被既有 WebSocket 用例阻断，`relay_only_message_broadcasts_without_server_persistence` 期望 HTTP 400，当前消息运行时返回 HTTP 409。本轮未改动该链路。
