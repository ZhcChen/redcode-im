# Flutter 首版功能完整性与 API 联调验收报告

日期：2026-07-23

## 结论

Flutter `app/` 当前作为第一个版本的正式移动端主线继续维护。基于本轮检查和真实设备联调，Flutter 端直接使用的 REST API path 已与 `api/src/routes.rs` 闭合；首版核心账号、好友、群、消息、设置和 Push device mock 合同可用。

`ios-app` / `android-app` 原生迁移暂时暂停；现有代码和任务文档保留，不进入当前首版发布门禁。

## 本轮修复

- `RoomService.updateRule` 改为 `PATCH /rooms/{room_id}/rules/{rule_id}`。
- `RoomService.updateGroupSettings` 改为 `PATCH /rooms/{room_id}/settings`。
- `RoomService` 的群管理 void 操作改为接受 API 当前合同使用的 `200 OK` / `204 No Content`，避免 `202/206` 等非最终完成响应被误判为成功。
- `RoomService.fetchGroupSettings` 合并 API 顶层 `my_mute`，保证个人禁言状态可初始化。
- 新增 `app/integration_test/api_contract_flow_test.dart` 覆盖首版核心 API 合同链路。
- contract 测试对 settings / upload policy 等 fallback-prone 接口改用 raw HTTP，严格断言 `200` 与关键 JSON 字段。
- contract 测试对 upload policy per-type 字段、群设置、群规、管理员、个人禁言、消息编辑、pin/unpin、reaction、删除、Push device 注册/注销等关键合同增加读回或响应状态断言。
- contract 测试加入 best-effort 后端清理：注销 push device、删除测试群、停用测试账号，并输出 cleanup 非 2xx 诊断，降低 dev 数据库噪声。
- 新增 `make app.test.api-paths`，将 Flutter REST path 与 `api/src/routes.rs` 的机械化对照沉淀为可复跑入口。
- 新增 Makefile / 脚本入口：
  - `make app.test.integration.contract`
  - `make app.test.integration.device.contract`（设备联调别名）
  - `app/scripts/test_integration.sh contract`

## API 合同闭合情况

- Flutter `app/lib` 与 `app/integration_test` 提取 REST path：85 个。
- API `api/src/routes.rs` 注册 path：208 个。
- 归一化比对结果：`app_paths=85 api_routes=208 missing=0`。
- 可复跑入口：`make app.test.api-paths`。
- Flutter 端未发现残留 `PUT` 调用：`rg -n "\.put\(|http\.put\(" app/lib app/integration_test` 输出为空。

## 真实联调覆盖范围

本轮使用 Pixel 8 Pro `3A091FDJG001DN`，真机前重新检测 LAN IP：`192.168.1.63`。

`api_contract_flow_test.dart` 覆盖：

- 普通账号密码注册、登录。
- settings：通用设置、App 名称、隐私协议、用户协议、登录验证码开关；使用 raw HTTP 严格断言真实接口响应，避免客户端 fallback 掩盖失败。
- upload policy：使用 raw HTTP 严格断言真实接口响应，并验证 Flutter `UploadPolicy.fromJson` 可解析 per-type size / MIME。
- feedback 提交。
- 好友：搜索、申请、接受、好友列表、创建私聊。
- 群：创建、详情、设置、群规、管理员、个人禁言、禁言列表、入群申请列表、操作日志；更新/删除后读回确认状态变化。
- 消息：发送、加载、编辑、reaction、pin/unpin、已读、读者列表、聊天列表、全文搜索、删除；关键 mutation 后读回或断言返回状态。
- Push device mock：注册和注销设备 token，并断言注册响应与真实注销响应成功；不依赖真实 FCM/APNs。
- network integration 额外覆盖 API healthz 与 WebSocket handshake。

说明：当前 API 对用户、房间采用软删除，feedback / 好友关系 / 消息等审计类历史数据仍可能在 dev 数据库保留为历史记录。需要“无历史残留”的基线时，使用 `docker compose -f api/docker/dev/docker-compose.yml down -v` 重建 dev 栈，或后续补 disposable live API 栈。

## 验证结果

已通过：

- `make app.check`
- `make app.test.scripts`
- `make app.test.api-paths`：`app_paths=85 api_routes=208 missing=0`
- `make app.test.unit`：157 passed
- `make api.up`
- `make api.wait`
- `make app.test.integration.auth`：Pixel 8 Pro 通过
- `make app.test.integration.contract`：Pixel 8 Pro 通过
- `make app.test.integration.network`：Pixel 8 Pro 通过，2 passed
- `make api.test`：API 单元 172 passed；集成 admin/auth/migration/health/smoke/users/websocket 全部通过

## 不作为当前阻塞项

- 真实 FCM/APNs token、云端 Push 投递、系统通知点击/冷启动深链：当前本地联调用 mock，不阻塞 Flutter 首版 API 合同。
- 相机、麦克风、厂商 ROM 文件选择器差异、release 签名和商店发布链路：需要真机/发布资源时单独补验。
- 邮箱验证码二次验证、Google 登录、Apple 登录：不进入当前默认主线；当前主线为普通账号密码注册/登录。
