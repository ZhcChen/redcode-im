# 全模块测试重建实施计划

**日期**: 2026-03-01
**关联设计**: `docs/plans/2026-03-01-full-module-test-rebuild-design.md`

## 0. 计划原则

1. 分批交付，每批可独立验收。
2. 测试优先（先写用例与验收，再补实现/修复）。
3. 所有外部依赖优先走本地模拟。
4. 每批完成即执行验证、提交、推送。

## 1. 批次 A：基础设施与模拟层

### A1. 外部依赖可配置化（Backend）

- 将下列硬编码外部地址改为环境可配置（保留默认线上值）：
  - Google/Apple JWKS URL
  - IPInfo Base URL
  - FCM Base URL
  - 腾讯 CI Base URL 或 Host Override
  - COS 请求协议（测试支持 HTTP）

### A2. 本地模拟服务（Go）

- 新增 `tests/mocks/external`：
  - COS Mock（对象/分片/CORS）
  - CI Mock（提交/查询）
  - JWKS Mock（Google/Apple）
  - OAuth Token Mock（Google）
  - FCM Mock（发送）
  - IPInfo Mock

### A3. 测试编排接入

- 更新 `tests/docker-compose.yml` 引入 `external-mock` 服务。
- 更新 `tests/run.sh`：确保 mock 服务先于 backend 与 go-tests 启动。
- 提供 mock 场景切换环境变量。

### A4. 基线验证

- 配置语法、服务可启动、基础 smoke 通过。

## 2. 批次 B：Backend 功能重建

### B1. 功能追踪矩阵

- 新建 `docs/reference/testing/matrix/backend.csv`（功能点/测试ID/验收ID）。

### B2. Go 黑盒契约测试

按业务域分目录重建：

- `auth`
- `users`
- `friends`
- `rooms`
- `messages`
- `uploads`
- `versions`
- `admin`
- `ws`

### B3. Rust 单测与集成

- 核心算法、策略、鉴权、上传策略、重试/并发等补齐。

### B4. Backend 验收

- 以业务链路验收：注册登录 -> 好友 -> 会话 -> 消息 -> 附件 -> 管理配置 -> 版本下载。

## 3. 批次 C：Admin 测试重建

### C1. 页面功能矩阵

- 新建 `docs/reference/testing/matrix/admin.csv`。

### C2. 测试实现

- API 契约复用 Go。
- 页面验收使用 Playwright（关键链路）。

### C3. 验收

- 后台核心运维链路完整通过。

## 4. 批次 D：Frontend（Flutter）测试重建

### D1. 功能矩阵

- 新建 `docs/reference/testing/matrix/frontend.csv`。

### D2. 测试实现

- `frontend/test` 单元。
- `frontend/integration_test` 集成。
- `frontend/patrol_test` 关键 E2E。

### D3. 验收

- 登录、聊天、联系人、设置等主链路通过。

## 5. 批次 E：Desktop + Website 测试重建

### E1. Desktop

- 新建 `docs/reference/testing/matrix/desktop.csv`。
- 补齐关键页面与核心交互测试。

### E2. Website

- 新建 `docs/reference/testing/matrix/website.csv`。
- 覆盖版本查询与下载链路。

### E3. 验收

- Desktop/Website 核心业务场景通过。

## 6. 批次执行与提交策略

每批固定顺序：

1. 更新模块功能分析与矩阵。
2. 先补测试与验收场景。
3. 执行回归，修复失败。
4. 更新文档。
5. `commit + push`。

## 7. 当前执行位置

- 批次 A（基础设施与模拟层）已完成并验收通过。
- 批次 B-1（`auth/users/friends`）已完成并验收通过。
- 当前进入 **批次 B-2**：`rooms/messages/uploads` 域测试重建。
