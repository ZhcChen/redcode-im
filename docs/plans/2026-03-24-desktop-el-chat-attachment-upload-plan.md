# Desktop EL Chat Attachment Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 聊天模块补齐附件发送最小闭环，支持选择单个文件、按大小自动直传或分片上传、上传完成后发送单附件消息。

**Architecture:** 继续坚持 Electron 仅作为宿主壳，business RPC 统一经 Go core 通过 stdio 与 backend 交互；renderer 只负责文件选择、基于 signed URL 直传存储、展示上传状态和触发最终消息发送。本轮不做多附件编辑、拖拽上传、视频缩略图、语音录制和本地缓存优化。

**Tech Stack:** Electron、Vue 3、TypeScript、Go 1.25、stdio RPC、Web Crypto、Fetch API、backend 上传签名 / Multipart API

---

### Task 1: 为 Go core 增加附件上传 RPC 与 `chat.send(parts)` 支持

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/docs/rpc-contract.md`

- [ ] **Step 1: 先写失败测试，覆盖附件上传 RPC 和 `chat.send(parts)`**

至少覆盖：
- `chat.send` 能透传 `parts`
- `chat.attachment.signature`
- `chat.attachment.multipart.initiate`
- `chat.attachment.multipart.part_signature`
- `chat.attachment.multipart.part_commit`
- `chat.attachment.multipart.complete`
- `chat.attachment.multipart.abort`
- `chat.attachment.upload.commit`

- [ ] **Step 2: 运行对应单测确认失败**

Run: `go test ./internal/app -run 'TestAppChat(SendPostsAttachmentPartsPayload|Attachment.*)'`
Expected: FAIL，提示方法未注册或请求体不匹配

- [ ] **Step 3: 写最小实现**

在 Go core 中补齐请求参数结构与 RPC：
- 发送消息支持 `content + parts + quoted_message_id`
- 附件上传相关 RPC 全部桥接 backend 既有接口

- [ ] **Step 4: 重跑单测确认通过**

Run: `go test ./internal/app -run 'TestAppChat(SendPostsAttachmentPartsPayload|Attachment.*)'`
Expected: PASS

- [ ] **Step 5: 更新 RPC 文档**

把新增方法和参数补入 `desktop-el/docs/rpc-contract.md`。

### Task 2: 扩展 renderer Chat API 与上传工具

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Add: `desktop-el/renderer/src/utils/fileHash.ts`
- Add: `desktop-el/renderer/src/utils/chat-attachment-upload.ts`

- [ ] **Step 1: 定义前端上传所需类型**

补齐：
- 上传签名返回结构
- 分片会话结构
- multipart part complete/abort 结构
- 发送消息 part 输入结构

- [ ] **Step 2: 实现最小 API**

在 `chat.ts` 中新增：
- `sendMessage`
- `requestAttachmentSignature`
- `initiateAttachmentMultipartUpload`
- `generateMultipartPartSignature`
- `commitMultipartPart`
- `completeMultipartUpload`
- `abortMultipartUpload`
- `commitAttachmentUpload`

- [ ] **Step 3: 实现上传工具**

在 utils 中补齐：
- `computeFileHash`（SHA-256，对应 `hash_alg = 2`）
- 文件类型推断
- direct upload helper
- multipart upload helper
- 发送附件 part 构造器

- [ ] **Step 4: 做一次 type-check**

Run: `bun run type-check`
Expected: PASS

### Task 3: 在 ChatPanel 接入文件选择与附件发送

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [ ] **Step 1: 先补最小交互状态**

增加：
- 发送附件按钮
- 文件选择入口
- 上传中状态与进度提示
- 发送期间禁用重复提交

- [ ] **Step 2: 实现单文件发送闭环**

流程固定为：
1. 选择文件
2. 计算哈希
3. 按阈值决定 direct upload 或 multipart
4. 上传后调用 `chat.attachment.upload.commit`
5. `chat.send(parts)` 发送单附件消息
6. 刷新当前会话消息与会话摘要

- [ ] **Step 3: 保持当前边界**

明确不做：
- 多附件组合发送
- 文本 + 附件混发
- 视频缩略图上传
- 录音、拖拽、粘贴上传

- [ ] **Step 4: 重新做 type-check 和 build**

Run: `bun run type-check`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 4: 验证、回填、提交

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [ ] **Step 1: 回填 backlog**

把 “附件发送最小闭环” 记入 `P0-2` 当前进度。

- [ ] **Step 2: 运行完整验证**

Run: `go test ./...`
Expected: PASS

Run: `bun run type-check`
Expected: PASS

Run: `bun run build`
Expected: PASS

- [ ] **Step 3: 清理残留进程**

Run: `make desktop-el-down`

Run: `screen -ls || true`

Run: `pgrep -fl \"desktop-el|electron|go-core\" || true`

Expected: 没有本轮遗留的 `desktop-el` / Electron / Go core 进程

- [ ] **Step 4: 提交并推送**

```bash
git add docs/plans/2026-03-24-desktop-el-chat-attachment-upload-plan.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/docs/rpc-contract.md \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/utils/fileHash.ts \
  desktop-el/renderer/src/utils/chat-attachment-upload.ts \
  desktop-el/renderer/src/components/ChatPanel.vue \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md
git commit -m "feat(desktop-el): support attachment message uploads"
git push
```
