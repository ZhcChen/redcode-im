# CE Review: Android 聊天扩展

范围：当前 `ANDROID-P1-01 聊天扩展` 未提交 diff。

结论：已修复 review 中发现的当前切片问题，剩余一项后端既有授权问题转入后续安全任务。

## 已修复

- 真机默认设备与 API/WS 地址策略不一致：Makefile 自动按设备解析 LAN API/WS，真机无 LAN IP 时 fail-fast。
- 文档固化历史 LAN IP：已改为 `<LAN_IP>` 和禁止复用历史 IP。
- 快速连续修改聊天偏好丢失更新：新增 `updateChatPreferences` 原子合并入口并补测试。
- 贴纸加载/发送失败路径缺测试：补 ViewModel 失败路径测试。
- DataStore 损坏 JSON / roomId key 碰撞缺测试：补回退和 hash key 碰撞测试。
- `StickerItem.fileName()` 重复规则：抽到 core model `attachmentFileName()`。
- 背景 label/color 重复映射：集中到 `ChatBackgroundOption`。
- Compose testTag 外部自动化不可见：聊天详情根节点启用 `testTagsAsResourceId`，新增交互补 `contentDescription`。
- 自动下载附件无界并发：改为 ViewModel 串行去重队列。
- emoji 网络请求无超时：OkHttp 增加 connect/read/write/call timeout。
- 登出清理 fail-fast：改为 best-effort 全部执行后再抛首个错误。
- 贴纸 `image_url` 裸下载风险：Android 发送链路只接受 `imageObjectKey` 并走后端签名 URL。
- 贴纸下载大小上限：`HttpRequest.maxResponseBytes` + streaming 限制。
- Emoji endpoint URL 编码缺测试：补 `EmojiAPIEndpoint.downloadUrl` 单测。

## 预留后续

- `api/src/handlers/emoji_pack.rs` 下载 URL 接口只校验前缀、未校验 object key 是否属于当前用户已拥有/可访问的表情包。该问题是后端既有授权缺口，不混入本 Android 客户端提交，后续进入 API 安全任务处理。

## 已验证

- `make android-app.test.unit`
- `make android-app.connected-test`
- `make android-app.lint`
- `make android-app.smoke.emulator ANDROID_APP_USE_REMOTE_AUTH=true`
- `make api.up && make api.wait && make android-app.test.live && make android-app.test.interop && make android-app.coverage`
- `make android-app.resolve.network`
- `make android-app.resolve.network ANDROID_APP_DEVICE=physical-test ANDROID_APP_LAN_IP=`（预期失败，exit 66）
- `git diff --check`
