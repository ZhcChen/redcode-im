# SPEC-005: 版本管理与热更新 API 测试技术规范

> 版本: 1.0
> 日期: 2026-01-22
> 对应 PRD: PRD-005

## 1. 概述

基于 PRD-005 需求，实现版本管理与热更新 API 测试模块 `version_tests.rs`。

## 2. API 路由分析

### 2.1 公开 API（无需认证）

| 方法 | 路由 | 说明 |
|------|------|------|
| GET | `/versions/latest` | 检查最新版本 |
| GET | `/versions/latest/download-url` | 获取最新版本下载链接 |
| GET | `/versions/hot-update` | 检查最新热更新 |
| GET | `/versions/download` | 下载版本（需 id） |
| GET | `/versions/hot-update/download` | 下载热更新（需 id） |
| POST | `/versions/hot-update/events` | 上报热更新事件 |

### 2.2 管理员 API（需管理员权限）

| 方法 | 路由 | 说明 |
|------|------|------|
| POST | `/api/admin/app-versions/upload/signature` | 获取上传签名 |
| GET | `/api/admin/app-versions` | 版本列表 |
| POST | `/api/admin/app-versions` | 创建版本 |
| GET | `/api/admin/app-versions/{id}` | 版本详情 |
| PATCH | `/api/admin/app-versions/{id}` | 更新版本 |
| DELETE | `/api/admin/app-versions/{id}` | 删除版本 |
| POST | `/api/admin/app-versions/{id}/deactivate` | 停用版本 |
| GET | `/api/admin/hot-updates` | 热更新列表 |
| POST | `/api/admin/hot-updates` | 创建热更新 |
| GET | `/api/admin/hot-updates/events` | 热更新事件列表 |
| GET | `/api/admin/hot-updates/{id}` | 热更新详情 |
| PATCH | `/api/admin/hot-updates/{id}` | 更新热更新 |
| DELETE | `/api/admin/hot-updates/{id}` | 删除热更新 |
| POST | `/api/admin/hot-updates/{id}/activate` | 激活热更新 |
| POST | `/api/admin/hot-updates/{id}/deactivate` | 停用热更新 |

## 3. 请求/响应结构

### 3.1 CreateAppVersionRequest（创建版本）

```rust
{
    "platform": "android",        // 必填: windows, macos, ios, android, linux
    "version": "1.0.0",           // 必填: 版本号
    "build_number": 100,          // 必填: 构建号
    "channel": "stable",          // 必填: 渠道 (stable, beta, dev)
    "download_key": "releases/android/stable/xxx.apk",  // download_key/download_url/app_store_url 至少一个
    "download_url": null,         // 可选: 直接下载链接
    "app_store_url": null,        // 可选: 应用商店链接
    "file_size": 10240,           // 可选: 文件大小
    "release_notes": "修复 bug", // 可选: 更新说明
    "min_os_version": "5.0",      // 可选: 最低系统版本
    "is_force_update": false      // 可选: 是否强制更新
}
```

### 3.2 ListAppVersionsQuery（版本列表查询）

```
GET /api/admin/app-versions?platform=android&channel=stable&limit=10&offset=0
```

- `platform`: **必填**，不支持则返回 422
- `channel`: 可选，筛选渠道
- `limit`: 可选，默认 10，范围 1-100
- `offset`: 可选，默认 0

### 3.3 LatestVersionQuery（最新版本检查）

```
GET /versions/latest?platform=android&channel=stable&current_version=1.0.0
```

### 3.4 HotUpdateEventReport（热更新事件上报）

```rust
{
    "platform": "android",           // 必填
    "base_version": "1.0.0",         // 必填
    "patch_version": "1.0.0-patch1", // 必填
    "event_type": "apply_success",   // 必填: download_success/download_failed/apply_success/apply_failed/rollback
    "channel": "stable",             // 可选
    "client_id": "device-xxx",       // 可选
    "message": "应用成功"            // 可选
}
```

## 4. 测试用例设计（14 用例）

### 4.1 版本列表测试

| 用例 | 方法 | 路由 | 预期 |
|------|------|------|------|
| `admin_list_app_versions_success` | GET | `/api/admin/app-versions?platform=android` | 200 |
| `admin_list_app_versions_missing_platform` | GET | `/api/admin/app-versions` | 422（platform 必填） |
| `admin_list_app_versions_requires_admin` | GET | `/api/admin/app-versions?platform=android` | 403（普通用户） |

### 4.2 版本详情/删除测试

| 用例 | 方法 | 路由 | 预期 |
|------|------|------|------|
| `admin_get_app_version_not_found` | GET | `/api/admin/app-versions/{fake_id}` | 404 |
| `admin_delete_app_version_not_found` | DELETE | `/api/admin/app-versions/{fake_id}` | 404 |

### 4.3 公开版本检查测试

| 用例 | 方法 | 路由 | 预期 |
|------|------|------|------|
| `latest_version_success` | GET | `/versions/latest?platform=android&channel=stable` | 200 |
| `latest_version_missing_platform` | GET | `/versions/latest?channel=stable` | 422 |
| `latest_version_missing_channel` | GET | `/versions/latest?platform=android` | 422 |

### 4.4 热更新列表/详情测试

| 用例 | 方法 | 路由 | 预期 |
|------|------|------|------|
| `admin_list_hot_updates_success` | GET | `/api/admin/hot-updates` | 200 |
| `admin_list_hot_updates_requires_admin` | GET | `/api/admin/hot-updates` | 403（普通用户） |
| `admin_get_hot_update_not_found` | GET | `/api/admin/hot-updates/{fake_id}` | 404 |
| `admin_list_hot_update_events_success` | GET | `/api/admin/hot-updates/events` | 200 |

### 4.5 热更新事件上报测试

| 用例 | 方法 | 路由 | 预期 |
|------|------|------|------|
| `report_hot_update_event_success` | POST | `/versions/hot-update/events` | 200 |
| `report_hot_update_event_invalid_type` | POST | `/versions/hot-update/events` | 422（无效事件类型） |

## 5. 测试实现要点

### 5.1 依赖与导入

```rust
use super::common::{
    empty_request, get_admin_token, json_request, login_user, read_json,
    register_user, test_router, test_state, unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;
```

### 5.2 管理员认证

使用 `get_admin_token()` 获取管理员 token：

```rust
let token = get_admin_token(app.clone()).await;
```

### 5.3 关键验证逻辑

1. **platform 必填验证**：`list_app_versions` 要求 `platform` 参数
2. **事件类型白名单**：仅支持 `download_success/download_failed/apply_success/apply_failed/rollback`
3. **版本创建需要存储**：创建版本需要先上传文件到存储，测试环境可能无法完成完整流程

### 5.4 测试限制说明

由于版本创建需要：
1. 配置默认存储提供商
2. 先上传文件到对象存储
3. 文件存在性校验

本阶段测试主要覆盖：
- 列表/详情/删除的参数校验
- 权限验证（管理员 vs 普通用户）
- 公开 API 的参数校验
- 热更新事件上报

## 6. 文件结构

```
backend/tests/api/
├── version_tests.rs   [NEW] 版本管理与热更新测试 (14)
└── mod.rs             [UPDATE] 添加 version_tests 模块
```

## 7. 验收标准

1. 新增 14 个测试用例
2. 所有测试通过 `cargo test --test api version_tests`
3. 无回归失败
4. 测试代码遵循现有模式

## 8. 预期结果

| 指标 | Phase 4 | Phase 5 | 增量 |
|------|---------|---------|------|
| 测试用例 | 141 | 155 | +14 |
| 测试模块 | 16 | 17 | +1 |
