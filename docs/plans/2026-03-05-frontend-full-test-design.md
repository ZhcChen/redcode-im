# Frontend 全功能测试设计与执行计划

> 基于 `docs/reports/2026-03-05-frontend-function-inventory.md` 的全功能清单制定。  
> 目标：每个功能点都有明确测试层级（unit/widget/integration/device）、用例归属与执行结论。

## 1. 分层策略

- **L0 Unit/Widget（快速反馈）**：模型、服务解析、缓存、关键弹窗与基础聊天组件。
- **L1 Integration（端内链路）**：AuthStateBus、缓存异步链路、网络连通性。
- **L2 Device Smoke（真机）**：真实局域网 API/WS 连通，验证真机可达与网络参数注入。

## 2. 功能 -> 测试用例矩阵

| 测试ID | 功能ID | 层级 | 设计与断言 | 自动化文件 | 状态 |
|---|---|---|---|---|---|
| TC-FE-ST-001 | FE-FUNC-ST-001 | integration | 启动基础链路 smoke（事件总线/缓存异步） | `frontend/integration_test/smoke_test.dart` | PASS |
| TC-FE-ST-002 | FE-FUNC-ST-005 | unit | 版本模型解析、异常状态 | `frontend/test/core/version_service_test.dart` + `frontend/test/core/hot_update_models_test.dart` | PASS |
| TC-FE-ST-003 | FE-FUNC-ST-002 | unit | AppName 读取优先级：内存>本地>API | `frontend/test/core/app_config_service_test.dart` | PASS |
| TC-FE-ST-004 | FE-FUNC-ST-004 | integration | 会话状态总线可消费事件 | `frontend/integration_test/smoke_test.dart` | PASS |
| TC-FE-NET-001 | FE-FUNC-CORE-009 | device | 真机 HTTP `/healthz` 200 且 body=ok | `frontend/integration_test/network_connectivity_test.dart` | PASS（Pixel 8 Pro） |
| TC-FE-NET-002 | FE-FUNC-CORE-009 | device | 真机 WS 握手可建立连接 | `frontend/integration_test/network_connectivity_test.dart` | PASS（Pixel 8 Pro） |
| TC-FE-AUTH-001 | FE-FUNC-AUTH-007 | unit | AuthUser fromJson/toJson 字段一致 | `frontend/test/features/auth_models_test.dart` | PASS |
| TC-FE-AUTH-002 | FE-FUNC-AUTH-007 | unit | displayName 昵称优先，copyWith 清理本地头像 | `frontend/test/features/auth_models_test.dart` | PASS |
| TC-FE-AUTH-003 | FE-FUNC-AUTH-007 | unit | AuthSession token/user/refreshToken 存储一致 | `frontend/test/features/auth_models_test.dart` | PASS |
| TC-FE-AUTH-004 | FE-FUNC-AUTH-008 | unit | TokenStorage 会话保存/读取/损坏回收 | `frontend/test/core/token_storage_test.dart` | PASS |
| TC-FE-CHAT-001 | FE-FUNC-CHAT-004 | unit | 会话 displayTime 与 copyWith 规则 | `frontend/test/chat/chat_model_test.dart` | PASS |
| TC-FE-CHAT-002 | FE-FUNC-CHAT-003 | widget | 会话项标题优先级 + 收藏夹文案 + 未读角标 | `frontend/test/chat/chat_list_item_test.dart` | PASS |
| TC-FE-CHAT-003 | FE-FUNC-CHAT-012 | widget | 系统消息与普通消息渲染、反应点击回调 | `frontend/test/chat/chat_message_bubble_test.dart` | PASS |
| TC-FE-CHAT-004 | FE-FUNC-CHAT-013 | unit | ForwardInfo 来源解析与显示兜底 | `frontend/test/chat/message_model_test.dart` | PASS |
| TC-FE-CHAT-005 | FE-FUNC-CHAT-013 | unit | QuotedMessage 预览文本（删除/文本/图片） | `frontend/test/chat/message_model_test.dart` | PASS |
| TC-FE-CHAT-006 | FE-FUNC-CHAT-013 | unit | Message 时间戳/头像显示 5 分钟规则 | `frontend/test/chat/message_model_test.dart` | PASS |
| TC-FE-CHAT-007 | FE-FUNC-CHAT-013 | unit | Message.fromCacheJson 还原引用/转发/分片/反应 | `frontend/test/chat/message_model_test.dart` | PASS |
| TC-FE-CHAT-008 | FE-FUNC-CORE-013 | unit | 附件 URL 缓存 set/get/remove/ttl cleanup | `frontend/test/core/attachment_url_cache_test.dart` | PASS |
| TC-FE-CHAT-009 | FE-FUNC-CHAT-007 | widget | reaction picker 选择回调与外部点击关闭 | `frontend/test/chat/reaction_picker_test.dart` | PASS |
| TC-FE-CHAT-010 | FE-FUNC-CHAT-012 | unit | ChatMessage copyWith 与 reaction 序列化默认值 | `frontend/test/chat/chat_message_model_test.dart` | PASS |
| TC-FE-CHAT-011 | FE-FUNC-CHAT-001 | unit | ChatConversation 时间标签（当日/历史）与 copyWith | `frontend/test/chat/chat_conversation_test.dart` | PASS |
| TC-FE-CHAT-012 | FE-FUNC-CHAT-010 | unit | MessageReader 显示名优先级与 read_at 本地化 | `frontend/test/chat/message_reader_test.dart` | PASS |
| TC-FE-CHAT-013 | FE-FUNC-CHAT-005 | widget | ChatInputWidget 输入框行为：发送/更多切换、禁言态、发送中 loading | `frontend/test/chat/chat_input_widget_test.dart` | PASS |
| TC-FE-CHAT-014 | FE-FUNC-CHAT-026 | unit | ChatProvider 搜索过滤、消息服务同步、loadChats 委托链路 | `frontend/test/chat/chat_provider_test.dart` | PASS |
| TC-FE-CHAT-015 | FE-FUNC-CHAT-026 | unit | ChatProvider 发送/转发/删除消息委托链路 | `frontend/test/chat/chat_provider_test.dart` | PASS |
| TC-FE-CHAT-016 | FE-FUNC-CHAT-025 | widget | VoiceMessageWidget 时长文案与宽度边界渲染 | `frontend/test/chat/voice_message_widget_test.dart` | PASS |
| TC-FE-CON-001 | FE-FUNC-CON-004 | unit | 好友申请状态大小写/兜底转换 | `frontend/test/features/friend_models_test.dart` | PASS |
| TC-FE-CON-002 | FE-FUNC-CON-004 | unit | EnsureChatResult 默认字段 | `frontend/test/features/friend_models_test.dart` | PASS |
| TC-FE-CON-003 | FE-FUNC-CON-004 | unit | incoming counterparty 解析正确 | `frontend/test/features/friend_models_test.dart` | PASS |
| TC-FE-EMJ-001 | FE-FUNC-EMJ-001 | unit | EmojiPack/EmojiItem 解析与默认值 | `frontend/test/features/emoji_pack_models_test.dart` | PASS |
| TC-FE-SET-001 | FE-FUNC-SET-009 | widget | 关键字确认前按钮禁用/匹配后可提交 | `frontend/test/widgets/confirm_action_dialog_test.dart` | PASS |
| TC-FE-SET-002 | FE-FUNC-SET-009 | widget | 取消返回 false | `frontend/test/widgets/confirm_action_dialog_test.dart` | PASS |
| TC-FE-SET-003 | FE-FUNC-SET-010 | widget | 确认/取消返回值正确 | `frontend/test/widgets/tip_dialog_test.dart` | PASS |
| TC-FE-SET-004 | FE-FUNC-SET-010 | widget | onConfirm=false 保持弹窗开启 | `frontend/test/widgets/tip_dialog_test.dart` | PASS |
| TC-FE-SET-005 | FE-FUNC-CORE-003 | unit | fetchAppName 成功/失败 | `frontend/test/core/settings_service_test.dart` | PASS |
| TC-FE-SET-006 | FE-FUNC-CORE-003 | unit | 隐私协议 payload 解析与异常格式抛错 | `frontend/test/core/settings_service_test.dart` | PASS |
| TC-FE-SET-007 | FE-FUNC-CORE-003 | unit | require_captcha 异常 payload 默认 false | `frontend/test/core/settings_service_test.dart` | PASS |
| TC-FE-SET-008 | FE-FUNC-CORE-005 | unit | 反馈内容为空/未登录拦截 | `frontend/test/core/feedback_service_test.dart` | PASS |
| TC-FE-SET-009 | FE-FUNC-CORE-005 | unit | feedback 提交 header/body trim 校验 | `frontend/test/core/feedback_service_test.dart` | PASS |
| TC-FE-SET-010 | FE-FUNC-CORE-005 | unit | feedback 非 200 错误消息提取与兜底 | `frontend/test/core/feedback_service_test.dart` | PASS |
| TC-FE-SET-011 | FE-FUNC-SET-010 | widget | InputDialog 输入校验失败不关闭、成功后关闭、回调可阻止关闭 | `frontend/test/widgets/input_dialog_test.dart` | PASS |
| TC-FE-UPD-001 | FE-FUNC-CORE-002 | unit | checkLatest query + payload 解析 | `frontend/test/core/version_service_test.dart` | PASS |
| TC-FE-UPD-002 | FE-FUNC-CORE-002 | unit | checkLatest 非 200 抛异常 | `frontend/test/core/version_service_test.dart` | PASS |
| TC-FE-UPD-003 | FE-FUNC-CORE-002 | unit | fetchDownloadUrl 成功/失败分支 | `frontend/test/core/version_service_test.dart` | PASS |
| TC-FE-UPL-001 | FE-FUNC-CORE-006 | unit | UploadPolicy 默认白名单与边界 | `frontend/test/core/upload_policy_service_test.dart` | PASS |
| TC-FE-UPL-002 | FE-FUNC-CORE-006 | unit | UploadPolicy.fromJson 标准化与兜底 | `frontend/test/core/upload_policy_service_test.dart` | PASS |
| TC-FE-UPL-003 | FE-FUNC-CORE-006 | unit | UploadPolicyService 未登录走 builtin | `frontend/test/core/upload_policy_service_test.dart` | PASS |
| TC-FE-UPL-004 | FE-FUNC-CORE-006 | unit | UploadPolicyService 登录后远端策略拉取 | `frontend/test/core/upload_policy_service_test.dart` | PASS |
| TC-FE-CORE-001 | FE-FUNC-CORE-014 | unit | 热更新模型与 manifest 解析 | `frontend/test/core/hot_update_models_test.dart` | PASS |
| TC-FE-CORE-002 | FE-FUNC-CORE-013 | unit | 头像颜色计算稳定与首字母规则 | `frontend/test/core/avatar_color_utils_test.dart` | PASS |
| TC-FE-CORE-003 | FE-FUNC-CORE-001 | unit | 环境默认值 smoke | `frontend/test/smoke_test.dart` | PASS |
| TC-FE-CORE-004 | FE-FUNC-CORE-013 | unit | 文件哈希（SHA-256）结果与稳定性 | `frontend/test/core/file_hash_test.dart` | PASS |
| TC-FE-CORE-005 | FE-FUNC-CORE-013 | widget | AppBadge 显示规则（99+、单字符 padding、自定义文本） | `frontend/test/widgets/app_badge_test.dart` | PASS |
| TC-FE-CORE-006 | FE-FUNC-CORE-013 | unit | ChatCache 持久化排序、兼容字段与过期清理 | `frontend/test/core/chat_cache_test.dart` | PASS |
| TC-FE-CORE-007 | FE-FUNC-EMJ-001 | unit | EmojiPack/EmojiItem 解析与默认值 | `frontend/test/features/emoji_pack_models_test.dart` | PASS |
| TC-FE-CORE-008 | FE-FUNC-CORE-001 | unit | EnvironmentConfig 默认环境与 URL/开关一致性 | `frontend/test/core/environment_config_test.dart` | PASS |
| TC-FE-CORE-009 | FE-FUNC-CORE-001 | widget | CustomSwitch 点击切换、loading 禁用、禁用态透明度 | `frontend/test/widgets/custom_switch_test.dart` | PASS |
| TC-FE-CORE-010 | FE-FUNC-CORE-001 | widget | StyledTextField 多行高度约束与禁用态不可编辑 | `frontend/test/widgets/styled_text_field_test.dart` | PASS |
| TC-FE-CORE-011 | FE-FUNC-CORE-001 | widget | BottomPicker 选项点击与取消回调 | `frontend/test/widgets/bottom_picker_test.dart` | PASS |

## 3. 已执行命令（带结果）

1. `cd frontend && flutter test`
   - 结果：PASS（unit + widget 全量，当前 `113 passed`）
2. `cd frontend && flutter test integration_test/smoke_test.dart -d macos`
   - 结果：PASS（macOS 集成）
3. `cd frontend && flutter test integration_test/smoke_test.dart -d 3A091FDJG001DN --dart-define=API_BASE_URL=http://<LAN_IP>:8010 --dart-define=WS_URL=ws://<LAN_IP>:8010/ws`
   - 结果：PASS（Pixel 8 Pro 真机）
4. `cd frontend && flutter test integration_test/network_connectivity_test.dart -d 3A091FDJG001DN --dart-define=API_BASE_URL=http://<LAN_IP>:8010 --dart-define=WS_URL=ws://<LAN_IP>:8010/ws --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true`
   - 结果：PASS（Pixel 8 Pro 真机，HTTP/WS 实网）
5. `cd frontend && flutter test integration_test/network_connectivity_test.dart -d macos`
   - 结果：PASS（默认 skip 网络用例，符合预期）
6. `cd frontend && flutter test test/chat/chat_input_widget_test.dart`
   - 结果：PASS（新增聊天输入组件回归用例）
7. `cd frontend && flutter test test/widgets/custom_switch_test.dart test/widgets/styled_text_field_test.dart test/widgets/input_dialog_test.dart test/widgets/bottom_picker_test.dart`
   - 结果：PASS（新增基础交互组件回归用例）
8. `cd frontend && flutter test test/chat/chat_provider_test.dart`
   - 结果：PASS（新增 ChatProvider 回归用例，含 send/forward/delete 委托）
9. `cd frontend && flutter test test/chat/voice_message_widget_test.dart`
   - 结果：PASS（语音消息组件渲染回归）
10. `cd frontend && flutter test integration_test/smoke_test.dart -d macos`
   - 结果：PASS（新增聊天域回归后再次验证端内 smoke）

## 4. 当前自动化覆盖缺口（下一轮）

以下功能已有设计，但还未落地自动化脚本，建议按优先级继续补齐：

- FE-FUNC-AUTH-001~006：登录页复杂交互（短信倒计时、第三方登录回调、自动注册分支）
- FE-FUNC-CHAT-005~011、015~026：聊天详情页 V2 剩余深交互（已补 `ChatInputWidget` 基础行为）与群管理多分支流程
- FE-FUNC-CON-001~003：联系人页 UI/交互（索引跳转、请求处理）
- FE-FUNC-SET-001~008：设置业务流程（头像上传、更新下载弹窗链路）
- FE-FUNC-DIS-001：发现页 mock 跳转反馈 UI
