# AI 交接文档（完整续接版）

日期：2026-03-06  
工作树：`/Users/chen/code/redcode-im/.worktrees/full-test-rebuild`  
分支：`feat/full-test-rebuild`

> 历史说明：本文形成于仓库仍以 Superpowers 为默认工作流的阶段。当前仓库默认流程已切换为 **Compound Engineering (CE)**；阅读本文时请以最新 `AGENTS.md` 为准理解现行流程规范。

## 1. 这份文档的用途

本交接文档用于把当前测试重建与验收工作的上下文，完整移交给下一位 AI。  
目标不是“理解一个大概”，而是让下一位 AI 可以：

- 直接进入正确工作树，不在 `main` 主工作区误操作；
- 直接理解用户当前目标、约束、优先级与已经确认过的决策；
- 直接从当前 Frontend 测试重建主线继续，而不是重复分析；
- 直接复用已经通过的测试命令、真机信息、文档入口与矩阵；
- 避免回滚已知必要改动，尤其是 Flutter/macOS 集成测试相关文件。

## 2. 当前任务主线

用户当前的主线任务不是新功能开发，而是：

- 先整理当前项目功能；
- 再按模块重建测试；
- 对每个模块做“功能分析 -> 测试设计 -> 执行测试 -> 验收 -> 汇总”；
- 所有模块最终都要完成测试重建；
- 在外部依赖不存在时，允许开发本地模拟模块支撑测试与验收；
- 用户明确要求尽量不要频繁确认，方案确定后持续推进。

当前主线已经从“全模块测试基础重建”推进到“Frontend 功能全量盘点后，继续补聊天域深交互测试”。

## 3. 用户已明确确认过的关键决策

以下决策已经被用户明确确认，后续 AI 不需要再次反复确认：

### 3.1 架构与流程

- 本文成文时，当前仓库工作流架构采用 **Superpowers**，不再使用旧的 devflow。
- `bear-chat-tauri`、`bear-chat-uniapp` 两个参考模块允许删除。
- `devflow-notifier` 已要求移除。
- 需结合本文历史上下文，并以仓库最新 `AGENTS.md` 作为当前流程规范来源。

### 3.2 测试策略

- 用户接受“移除旧测试并从头构建测试代码和文档”。
- 已明确移除旧的 dashboard 可视化测试模块。
- 目标是按软件工程测试规范重建，不是保留旧的杂乱测试流程。
- 已接受按模块逐步重建并逐步验收，而不是一次性全做完。
- 用户强调要尽可能覆盖完整功能，而不是只做少量冒烟。

### 3.3 外部依赖与模拟

- 没有真实对象存储资源时，可以本地开发模拟模块用于系统调用。
- 如果还有其他外部模块依赖，也允许继续补模拟。
- 当前测试栈中外部依赖模拟已在此前阶段接入并用于全模块回归。

### 3.4 Frontend 真机联调

- 用户当前默认真机设备为：`Pixel 8 Pro (3A091FDJG001DN)`。
- 用户要求真机 API 基地址使用“本机内网 IP + 后端端口”。
- 真机与本机处于同一局域网。
- 用户已经同意方案 C，并同意继续做真实设备冒烟/联调测试。

## 4. 必须先知道的仓库规则

这些规则来自仓库根 `AGENTS.md`，后续 AI 必须遵守：

- 默认使用简体中文沟通、文档、说明。
- 本文对应阶段的仓库默认流程为 Superpowers；当前默认流程已切换为 CE。
- 本仓库只保留流程产出目录：`docs/plans/`。
- 测试入口与矩阵以 `docs/reference/testing/README.md` 为准。
- Backend 本地开发、Admin 启停方式、Docker Compose 约定都在根 `AGENTS.md` 中有明确规定。
- 不要擅自改端口；有冲突应先停止占用进程。
- 本仓库当前本地 Backend 开发容器与测试栈是分离的，不要混用。

## 5. 实际工作位置

**非常重要：真正的工作内容在 git worktree，不在主工作区。**

- 主仓库路径：`/Users/chen/code/redcode-im`
- 实际工作树：`/Users/chen/code/redcode-im/.worktrees/full-test-rebuild`
- 实际分支：`feat/full-test-rebuild`

当前 `main` 工作区基本是干净的，下一位 AI 如果在主仓库直接继续，很容易看不到正在进行的改动。

## 6. 当前全局进展概览

### 6.1 已完成的阶段性成果

按现有文档与验收记录，可认为以下阶段已完成：

- 当时的 Superpowers 工作流架构重构已完成。
- 旧测试 dashboard 已移除，统一测试架构文档已建立。
- Backend / Admin / Desktop / Website 已完成一轮较完整的测试重建与回归。
- 全模块回归验收文档已存在，见：`docs/reports/2026-03-04-full-module-regression-acceptance.md`
- Frontend 第一轮基础测试重建已完成，并且已经进入第二轮“按功能清单继续补齐”的阶段。

### 6.2 当前唯一主焦点

当前最应该继续的不是 Backend，也不是 Admin，而是：

- **Frontend 模块的全功能分析后续补测**；
- 重点先补 **聊天域 ChatDetailV2 深交互**；
- 然后继续补联系人、设置、认证、发现页等仍有覆盖缺口的部分。

## 7. Frontend 当前状态（接手重点）

### 7.1 Frontend 已完成的基础盘点文档

以下文档已经建立，接手时必须先读：

- 功能清单：`docs/reports/2026-03-05-frontend-function-inventory.md`
- 全量测试设计：`docs/plans/2026-03-05-frontend-full-test-design.md`
- 执行报告：`docs/reports/2026-03-05-frontend-test-execution-report.md`
- 测试矩阵：`docs/reference/testing/matrix/frontend.csv`
- 测试入口说明：`docs/reference/testing/README.md`

### 7.2 Frontend 当前自动化状态

最新状态不是旧报告里的 `27 passed`，而是已经推进到：

- `flutter test`：**PASS，113 passed**
- `flutter test integration_test/smoke_test.dart -d macos`：**PASS，2 passed**
- `flutter test integration_test/network_connectivity_test.dart -d 3A091FDJG001DN ... --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true`：此前已 **PASS**
- `flutter test integration_test/smoke_test.dart -d 3A091FDJG001DN ...`：此前已 **PASS**

### 7.3 Frontend 当前新增测试文件

当前 worktree 中 Frontend 新增/重建的测试文件已经较多，重点包括：

#### 聊天域

- `frontend/test/chat/chat_conversation_test.dart`
- `frontend/test/chat/chat_input_widget_test.dart`
- `frontend/test/chat/chat_list_item_test.dart`
- `frontend/test/chat/chat_message_bubble_test.dart`
- `frontend/test/chat/chat_message_model_test.dart`
- `frontend/test/chat/chat_model_test.dart`
- `frontend/test/chat/chat_provider_test.dart`
- `frontend/test/chat/message_model_test.dart`
- `frontend/test/chat/message_reader_test.dart`
- `frontend/test/chat/reaction_picker_test.dart`
- `frontend/test/chat/voice_message_widget_test.dart`

#### 核心/服务/模型

- `frontend/test/core/chat_cache_test.dart`
- `frontend/test/core/environment_config_test.dart`
- `frontend/test/core/feedback_service_test.dart`
- `frontend/test/core/file_hash_test.dart`
- `frontend/test/core/upload_policy_service_test.dart`
- `frontend/test/features/auth_models_test.dart`
- `frontend/test/features/emoji_pack_models_test.dart`

#### 基础组件

- `frontend/test/widgets/app_badge_test.dart`
- `frontend/test/widgets/bottom_picker_test.dart`
- `frontend/test/widgets/confirm_action_dialog_test.dart`
- `frontend/test/widgets/custom_switch_test.dart`
- `frontend/test/widgets/input_dialog_test.dart`
- `frontend/test/widgets/styled_text_field_test.dart`
- `frontend/test/widgets/tip_dialog_test.dart`

当前统计：

- `frontend/test` 下共 `34` 个测试文件
- `frontend/integration_test` 下共 `2` 个集成测试文件

## 8. 本轮最后完成的关键改动

这是最容易丢失上下文的部分，必须明确记录。

### 8.1 `InputDialog` 生产代码修复

文件：`frontend/lib/core/widgets/input_dialog.dart:160`

修复内容：

- 原逻辑在 `showDialog<String>` 场景下，某些确认/取消路径可能向路由返回 `bool`；
- 会导致 `type 'bool' is not a subtype of type 'String?'` 类型异常；
- 已修复为始终绑定 `_handleConfirm`，避免路由返回类型错配。

### 8.2 `VoiceMessageWidget` 生产代码修复

文件：`frontend/lib/features/chat/widgets/voice_message_widget.dart:132`

修复原因：

- 新增语音气泡宽度断言时，触发了小时长场景下的 `RenderFlex overflow`；
- 溢出根因是最小宽度气泡里，图标、间距、波形条、时长文本组合后在窄空间下超宽。

修复方式：

- 根据气泡宽度启用紧凑布局：
  - `isCompact`
  - 更小的 `padding`
  - 更小的 `iconSize`
  - 更小的 `gap`
  - 更小的 `durationFontSize`
- 波形区域在极窄空间下直接降级隐藏，避免继续挤压布局；
- `Row` 改为 `MainAxisSize.max`，与 `Expanded` 搭配更稳定。

### 8.3 `ChatProvider` 测试扩展

文件：`frontend/test/chat/chat_provider_test.dart:258`

在原有搜索过滤、列表同步、`loadChats` 委托的基础上，又补了：

- `sendRichMessage` 文本 trim 后委托发送；
- 空白文本无附件时直接拦截；
- `forwardMessage` 保留既有 `forwardInfo`；
- `deleteMessage` 正确委托到 `markMessageDeleted`。

### 8.4 `VoiceMessageWidget` 测试新增

文件：`frontend/test/chat/voice_message_widget_test.dart:1`

新增覆盖：

- 时长文案格式显示；
- 默认播放图标渲染；
- 小时长宽度边界；
- 长时长宽度边界。

## 9. 当前未提交改动快照

接手时，工作树是 **dirty** 状态，不要误以为这些是意外脏改动。

### 9.1 已修改文件

- `docs/reference/testing/README.md`
- `docs/reference/testing/matrix/frontend.csv`
- `frontend/lib/core/widgets/input_dialog.dart`
- `frontend/lib/features/chat/widgets/voice_message_widget.dart`
- `frontend/macos/Runner.xcodeproj/project.pbxproj`
- `frontend/macos/Runner.xcworkspace/contents.xcworkspacedata`

### 9.2 未跟踪文件

- `docs/plans/2026-03-05-frontend-full-test-design.md`
- `docs/reports/2026-03-05-frontend-function-inventory.md`
- `docs/reports/2026-03-05-frontend-test-execution-report.md`
- `frontend/macos/Podfile.lock`
- `frontend/test/chat/*`
- `frontend/test/widgets/*`
- `frontend/test/core/chat_cache_test.dart`
- `frontend/test/core/environment_config_test.dart`
- `frontend/test/core/feedback_service_test.dart`
- `frontend/test/core/file_hash_test.dart`
- `frontend/test/core/upload_policy_service_test.dart`
- `frontend/test/features/auth_models_test.dart`
- `frontend/test/features/emoji_pack_models_test.dart`

### 9.3 关于 macOS 工程文件

以下文件是 Flutter 集成测试过程中产生/更新的，**不要轻易回滚**：

- `frontend/macos/Runner.xcodeproj/project.pbxproj`
- `frontend/macos/Runner.xcworkspace/contents.xcworkspacedata`
- `frontend/macos/Podfile.lock`

如果下一位 AI 没有非常明确的理由，不要把它们当成“无关改动”删掉。

## 10. 已验证通过的关键命令

以下命令已经在当前工作树验证通过，下一位 AI 可以直接复用。

### 10.1 Frontend 单测

```bash
cd /Users/chen/code/redcode-im/.worktrees/full-test-rebuild/frontend && flutter test
```

结果：PASS，`113 passed`

### 10.2 Frontend macOS 集成 smoke

```bash
cd /Users/chen/code/redcode-im/.worktrees/full-test-rebuild/frontend && flutter test integration_test/smoke_test.dart -d macos
```

结果：PASS，`2 passed`

### 10.3 Frontend 指定聊天域测试

```bash
cd /Users/chen/code/redcode-im/.worktrees/full-test-rebuild/frontend && flutter test test/chat/chat_provider_test.dart
cd /Users/chen/code/redcode-im/.worktrees/full-test-rebuild/frontend && flutter test test/chat/voice_message_widget_test.dart
```

结果：均 PASS。

### 10.4 真机 smoke（此前已通过）

```bash
LAN_IFACE=$(route -n get default | awk '/interface:/{print $2}')
LAN_IP=$(ipconfig getifaddr ${LAN_IFACE})
cd /Users/chen/code/redcode-im/.worktrees/full-test-rebuild/frontend && flutter test integration_test/smoke_test.dart -d 3A091FDJG001DN \
  --dart-define=API_BASE_URL=http://${LAN_IP}:8010 \
  --dart-define=WS_URL=ws://${LAN_IP}:8010/ws
```

### 10.5 真机网络连通性（此前已通过）

```bash
LAN_IFACE=$(route -n get default | awk '/interface:/{print $2}')
LAN_IP=$(ipconfig getifaddr ${LAN_IFACE})
cd /Users/chen/code/redcode-im/.worktrees/full-test-rebuild/frontend && flutter test integration_test/network_connectivity_test.dart -d 3A091FDJG001DN \
  --dart-define=API_BASE_URL=http://${LAN_IP}:8010 \
  --dart-define=WS_URL=ws://${LAN_IP}:8010/ws \
  --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true
```

说明：上一轮成功时使用过的内网 IP 是 `192.168.31.107`，但后续应动态获取，不要写死。

## 11. 已知注意事项 / 坑点

### 11.1 集成测试最好单文件运行

之前已经出现过：

- 同一条命令串行执行多个 Flutter integration 文件时，第二个文件偶发 debug 连接异常；
- 解决方式是 **按文件拆开跑**；
- 因此后续不要把多个 integration test 文件塞进同一个命令里跑。

### 11.2 `custom_switch_test.dart` 的 loading 场景

- 不要对持续动画场景用 `pumpAndSettle()`；
- 会被 `CircularProgressIndicator` 持续动画拖住；
- 应改用 `pump()`。

### 11.3 `styled_text_field_test.dart`

- 不要直接从 `TextFormField` 读取某些不暴露的样式字段断言；
- 更稳妥的方式是通过 UI 行为和布局结果断言。

### 11.4 `VoiceMessageWidget` 短宽度气泡

- 这是一个真实布局边界问题，不只是测试假问题；
- 如果后续继续增强语音消息测试，仍应保留紧凑布局思路，避免再次回归 overflow。

## 12. 下一步任务建议（高优先级顺序）

下一位 AI 不要重新发散，建议按下面顺序继续：

### 第一步：继续 Frontend 聊天域深交互

重点文件：`frontend/lib/features/chat/chat_detail_page_v2.dart`

优先补这些功能的自动化测试：

- FE-FUNC-CHAT-005：文本/附件发送链路
- FE-FUNC-CHAT-006：引用、转发、删除、重发
- FE-FUNC-CHAT-007：表情反应完整链路
- FE-FUNC-CHAT-008：@ 提及成员面板
- FE-FUNC-CHAT-009：typing 广播与订阅 UI
- FE-FUNC-CHAT-010：已读回执查看
- FE-FUNC-CHAT-011：媒体消息渲染
- FE-FUNC-CHAT-015~026：群管理、多选、搜索、Pinned、Provider 编排等

其中最推荐的切入点：

- 先补 **可隔离、无重平台依赖** 的 widget/unit 逻辑；
- 然后再推进需要更多服务 mock 的页面交互链路。

### 第二步：补联系人/设置/认证/发现页缺口

按当前设计文档中的缺口继续推进：

- Auth 登录页复杂交互
- Contacts 页面 UI 与交互
- Settings 业务流程页面
- Discover mock 页面

### 第三步：同步矩阵、执行报告、设计文档

每补完一轮，都要同时更新：

- `docs/reference/testing/matrix/frontend.csv`
- `docs/reports/2026-03-05-frontend-test-execution-report.md`
- `docs/plans/2026-03-05-frontend-full-test-design.md`

## 13. 继续工作时建议的执行方式

推荐下一位 AI 采用以下固定节奏：

1. 打开 `frontend-function-inventory`、`frontend-full-test-design`、`frontend.csv`
2. 选一个未补完的功能组
3. 先分析该组功能与当前已有覆盖
4. 先补单元/组件级测试
5. 跑局部测试
6. 再跑 `flutter test`
7. 必要时再跑 `integration_test/smoke_test.dart -d macos`
8. 如果涉及真实网络链路，再跑真机命令
9. 最后同步文档矩阵与执行报告

## 14. 推荐下一位 AI 的起手提示词

如果要把任务交给另一个 AI，建议直接给它下面这段提示词：

```text
你现在接手 RedCode IM 的测试重建工作。
请先进入工作树 /Users/chen/code/redcode-im/.worktrees/full-test-rebuild，分支是 feat/full-test-rebuild，不要在主仓库 main 上操作。

先阅读以下文档：
1. docs/reports/2026-03-06-ai-handoff-full-test-rebuild.md
2. docs/reports/2026-03-05-frontend-function-inventory.md
3. docs/plans/2026-03-05-frontend-full-test-design.md
4. docs/reports/2026-03-05-frontend-test-execution-report.md
5. docs/reference/testing/matrix/frontend.csv
6. docs/reference/testing/README.md

当前主线是继续 Frontend 测试重建，重点补 chat_detail_page_v2 的深交互测试。
要求沿用现有工作流：功能分析 -> 测试设计 -> 编写测试 -> 执行测试 -> 验收 -> 同步文档。
不要回滚 Flutter macOS 集成测试相关改动。
优先补可隔离的 unit/widget 测试，再做更重的 integration/device 链路。
``` 

## 15. 交接结论

截至 2026-03-06，这个任务不是“刚开始”，而是已经完成了：

- 全模块测试基础重建；
- 全模块一轮回归验收；
- Frontend 全功能盘点；
- Frontend 第二轮测试扩展中的大量基础覆盖；
- Frontend 聊天域又补了一轮关键测试与生产代码修复。

真正需要下一位 AI 接着做的，是：

- 不要重复搭架子；
- 不要重复功能盘点；
- 直接进入 Frontend 剩余功能缺口；
- 继续沿着 `ChatDetailPageV2` 深交互测试往下推进；
- 补完后持续更新矩阵、报告、设计文档。
