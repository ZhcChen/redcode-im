# API 1.0 遗留文档对齐收尾核对记录

## 标题信息

- 主题：`docs/reference/api/` 剩余 1.0 遗留文档与实际代码一致性核对与补齐
- 关联计划：`docs/plans/2026-08-05-001-docs-api-1-0-legacy-alignment-plan.md`
- 审查范围：`friends.md`、`chats.md`、`version-management.md`、
  `system.md`、`e2ee.md`、`admin-storage.md`、`file-upload-hash.md`、
  `api-reference.md`、`api-overview.md`、`README.md`，对照
  `api/src/routes.rs` 与 `api/src/handlers/*`
- 负责人：Codex
- 日期：2026-08-05

## 核对方法

- 提取 `api/src/routes.rs` 全部 237 条 `.route` 定义（去重后 233 条路径），
  与 `docs/reference/api/` 全部文档中的 `METHOD /path` 文本对比
- 对未命中项逐条人工裁决：区分“真缺失”与“表示形式差异”
- 抽查新增/变更接口的请求/响应字段与对应 handler 结构体一致
- 检查附录技术栈版本与 `api/Cargo.toml`、Compose 镜像版本一致
- 全部相对链接有效性检查

## 确认与代码一致的部分

- P0 四个专题文档补齐：`friends.md`（列表/备注/删除）、`chats.md`
  （未读计数/通知设置/房间置顶）、`version-management.md`
  （热更新客户端/管理接口）、`system.md`（`/readyz`/公开设置/上传策略）
- P1 抽查：`e2ee.md` 补齐 peer 设备列表与遗留 Key Bundle 链路；
  `admin-storage.md` 补齐存储提供商与存储配置管理表；
  `file-upload-hash.md` 与代码一致，无需改动
- 路由覆盖：233 条路径中 217 条直接命中文档；16 条经人工确认为
  “表示形式差异”且文档已覆盖（详见下表），无未裁决项
- 技术栈：Axum 0.8.6、Tokio 1.44、SQLx 0.8.6、redis 0.32.7、
  prost 0.14.1、jsonwebtoken 9.3、bcrypt 0.16、reqwest 0.12 均与
  `api/Cargo.toml` 一致；PostgreSQL 文档从 15 修正为 17（Compose 实际
  使用 `postgres:17-alpine`）
- 相对链接检查：35 个相对链接全部有效

## 本轮修复内容

1. `api-reference.md` 认证公开路由补管理员初始化引导：
   `GET /api/admin/bootstrap/status`、`POST /api/admin/bootstrap/init`，
   后续章节编号顺延
2. `api-reference.md` 角色权限管理补
   `GET /PUT /api/admin/roles/:role_id/permissions`
3. `api-reference.md` 管理员用户管理补
   `GET /PUT /api/admin/admin-users/:admin_user_id/roles`
4. `api-reference.md` 新增“地理位置服务管理”小节：ipinfo Token 系列
   （列表/创建/更新/删除/重置用量）、`POST /api/admin/test-geolocation-api`、
   `GET /PATCH /api/admin/ip-geolocation/enabled`、
   `POST /admin/data/cleanup/all`（仅开发环境）
5. `api-reference.md` 附录更新：路由统计（公开 28 / 认证 114 /
   管理后台 95 / 总计 237）、Handler 模块列表补全为 31 项、
   PostgreSQL 15 → 17、最后更新日期
6. `api-overview.md` 公共/基础区补 `GET /readyz` 与管理员初始化引导入口
7. `README.md` 最近更新时间更新

## 表示形式差异豁免清单

| 路由 | 文档位置 | 豁免理由 |
|---|---|---|
| `GET /` | api-reference.md 根路径接口 | 文档用 `GET /`，正则要求路径后跟字符 |
| `/api/admin/system/storage-config*` | admin-storage.md 表格 | 文档用表格 `\| 方法 \| 路径 \|` 形式 |
| `/api/admin/uploads/multipart/sessions*` | api-reference.md 管理员分片上传 | 以“前缀与用户路由相同”说明覆盖 |
| `/e2ee/mls/devices/{device_id}/approve` 等 | e2ee.md | 参数名写作 `{target_device_id}` |
| `/versions/hot-update-events` | version-management.md | 作为旧客户端兼容路径写明 |

## 验证结果

- 路由覆盖核对：无未裁决项
- 相对链接检查：35/35 有效
- `git diff --check`：通过
- 本次为纯文档变更，未改动源码、迁移或测试文件；未运行 `make api.test`

## 提交记录

- `4fdf0909` docs(plans): api 1.0 遗留文档对齐收尾计划
- `ea996506` docs(api): 好友专题文档补齐列表/备注/删除接口
- `f4b51260` docs(api): 会话专题文档补齐未读/通知设置/房间置顶
- `78935260` docs(api): 版本管理专题文档补齐热更新接口
- `2af4e598` docs(api): 系统专题文档补齐就绪检查与公开设置
- `48793114` docs(api): e2ee 与对象存储专题文档补齐缺失接口
