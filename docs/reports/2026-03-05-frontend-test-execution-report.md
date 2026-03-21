# Frontend 测试执行报告（补充）

日期：2026-03-05  
分支：`feat/full-test-rebuild`

## 1. 新增自动化测试

- `frontend/test/features/auth_models_test.dart`
- `frontend/test/features/emoji_pack_models_test.dart`
- `frontend/test/core/chat_cache_test.dart`
- `frontend/test/core/environment_config_test.dart`
- `frontend/test/chat/message_model_test.dart`
- `frontend/test/chat/chat_message_model_test.dart`
- `frontend/test/chat/chat_conversation_test.dart`
- `frontend/test/chat/message_reader_test.dart`
- `frontend/test/chat/chat_input_widget_test.dart`
- `frontend/test/chat/chat_provider_test.dart`
- `frontend/test/chat/voice_message_widget_test.dart`
- `frontend/test/chat/reaction_picker_test.dart`
- `frontend/test/core/feedback_service_test.dart`
- `frontend/test/core/file_hash_test.dart`
- `frontend/test/core/upload_policy_service_test.dart`
- `frontend/test/widgets/app_badge_test.dart`
- `frontend/test/widgets/custom_switch_test.dart`
- `frontend/test/widgets/styled_text_field_test.dart`
- `frontend/test/widgets/input_dialog_test.dart`
- `frontend/test/widgets/bottom_picker_test.dart`

## 2. 执行命令与结果

1. `cd frontend && flutter test`
   - 结果：PASS（全量 unit/widget，`113 passed`）
2. `cd frontend && flutter test integration_test/smoke_test.dart -d macos`
   - 结果：PASS（2 passed）
3. `cd frontend && flutter test integration_test/network_connectivity_test.dart -d macos`
   - 结果：PASS（默认 skip 网络用例）
4. `cd frontend && flutter test integration_test/smoke_test.dart -d 3A091FDJG001DN --dart-define=API_BASE_URL=http://192.168.31.107:8010 --dart-define=WS_URL=ws://192.168.31.107:8010/ws`
   - 结果：PASS（2 passed）
5. `cd frontend && flutter test integration_test/network_connectivity_test.dart -d 3A091FDJG001DN --dart-define=API_BASE_URL=http://192.168.31.107:8010 --dart-define=WS_URL=ws://192.168.31.107:8010/ws --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true`
   - 结果：PASS（2 passed，真机实网 HTTP/WS）
6. `cd frontend && flutter test test/chat/reaction_picker_test.dart test/widgets/app_badge_test.dart test/core/file_hash_test.dart test/features/emoji_pack_models_test.dart`
   - 结果：PASS（新增回归用例全部通过）
7. `cd frontend && flutter test test/core/chat_cache_test.dart test/chat/chat_message_model_test.dart`
   - 结果：PASS（缓存与聊天模型回归通过）
8. `cd frontend && flutter test test/chat/chat_conversation_test.dart test/chat/message_reader_test.dart test/core/environment_config_test.dart`
   - 结果：PASS（聊天会话/已读成员/环境配置回归通过）
9. `cd frontend && flutter test test/chat/chat_input_widget_test.dart`
   - 结果：PASS（聊天输入框发送/更多/禁言态/loading 回归通过）
10. `cd frontend && flutter test integration_test/smoke_test.dart -d macos`
   - 结果：PASS（2 passed，新增回归后再次验证集成烟测稳定）
11. `cd frontend && flutter test test/widgets/custom_switch_test.dart test/widgets/styled_text_field_test.dart test/widgets/input_dialog_test.dart test/widgets/bottom_picker_test.dart`
   - 结果：PASS（4 个基础交互组件测试文件全部通过）
12. `cd frontend && flutter test test/chat/chat_provider_test.dart`
   - 结果：PASS（ChatProvider 搜索过滤、列表同步、send/forward/delete 委托链路通过）
13. `cd frontend && flutter test test/chat/voice_message_widget_test.dart`
   - 结果：PASS（语音气泡时长显示与宽度裁剪断言通过）
14. `cd frontend && flutter test`
   - 结果：PASS（新增聊天域用例并入后，全量 `113 passed`）
15. `cd frontend && flutter test integration_test/smoke_test.dart -d macos`
   - 结果：PASS（2 passed，新增回归后再次验证端内 smoke）

## 3. 执行中问题与处理

- 现象：`flutter test integration_test/smoke_test.dart integration_test/network_connectivity_test.dart -d macos` 在同一命令串行两个文件时，第二个用例偶发 debug 连接异常。
- 处理：拆分为单文件执行；`smoke_test.dart` 与 `network_connectivity_test.dart` 分别执行后稳定通过。
- 结论：当前 CI/本地执行建议使用“单文件 integration 命令”而非一次传入多个 integration 测试文件。
- 现象：`InputDialog` 在 `showDialog<String>` 场景下，确认/取消分支可能向路由回传 `bool` 导致类型异常。
- 处理：`frontend/lib/core/widgets/input_dialog.dart` 调整为始终走 `_handleConfirm` 分支，未通过校验返回 `false` 且不关闭弹窗，避免 `bool/String` 路由返回类型冲突。
- 现象：`VoiceMessageWidget` 在小时长气泡（最小宽度）下存在 `RenderFlex overflow`，新增宽度断言用例时触发。
- 处理：`frontend/lib/features/chat/widgets/voice_message_widget.dart` 增加紧凑布局参数（icon/gap/font 自适应）并在极窄空间下隐藏波形条，确保最小宽度气泡仍可稳定渲染。

## 4. 当前状态

- Frontend 新增聊天与设置关键交互测试已并入主测试套件。
- Frontend 聊天输入组件 `ChatInputWidget` 行为（发送/更多/禁言态/loading）已补齐 widget 自动化覆盖。
- Frontend `ChatProvider` 关键逻辑（搜索过滤、消息服务同步、loadChats 委托）已补齐 unit 自动化覆盖。
- Frontend `ChatProvider` 发送委托链路（`sendRichMessage/forwardMessage/deleteMessage`）已补齐 unit 自动化覆盖。
- Frontend 语音消息气泡（`VoiceMessageWidget`）时长文案与宽度边界已补齐 widget 自动化覆盖。
- Frontend 基础交互组件（`CustomSwitch`、`StyledTextField`、`InputDialog`、`BottomPicker`）已补齐 widget 自动化覆盖。
- Frontend 真机（Pixel 8 Pro）局域网联调链路可用（API/WS 均通过）。
- 功能清单与测试设计已分别记录在：
  - `docs/reports/2026-03-05-frontend-function-inventory.md`
  - `docs/plans/2026-03-05-frontend-full-test-design.md`
