# SPEC-004: Phase 4 测试实现技术方案

> 版本: 1.0
> 日期: 2026-01-22
> 关联: PRD-004

## 1. 路由分析

### 1.1 表情包路由 (emoji_pack.rs)

```
GET  /emoji-packs/available           # 获取可用表情包
GET  /emoji-packs/search              # 搜索表情包
GET  /emoji-packs/my                  # 我的表情包
POST /emoji-packs/download-url        # 获取下载URL
POST /emoji-packs/{pack_id}/add       # 添加表情包
POST /emoji-packs/suites/{suite_id}/add    # 添加套装
DELETE /emoji-packs/{pack_id}/remove  # 移除表情包
GET  /emoji-packs/suites/{suite_id}/packs  # 套装内表情包
```

### 1.2 聊天会话路由 (room.rs)

```
GET    /chats           # 聊天会话列表
DELETE /chats/{room_id} # 删除聊天会话
```

### 1.3 举报路由 (report.rs)

```
POST /reports                          # 创建举报
GET  /reports/attachments/signature    # 获取附件上传签名
POST /reports/attachments/commit       # 提交附件
GET  /api/admin/reports                # 管理员查看举报列表
```

### 1.4 消息搜索路由 (message_search.rs)

```
GET /messages/search              # 搜索消息
GET /messages/search/suggestions  # 搜索建议
GET /messages/search/trending     # 热门搜索
```

### 1.5 反馈路由 (feedback.rs)

```
POST /feedbacks                   # 提交反馈
GET  /api/admin/feedbacks         # 管理员查看反馈列表
```

### 1.6 活动日志路由 (activity_logs.rs)

```
POST   /activity/heartbeat                   # 心跳
POST   /activity/login                       # 创建登录记录
DELETE /activity/login/{log_id}/logout       # 登出
GET    /users/{user_id}/activity/login-history    # 登录历史
GET    /users/{user_id}/activity/heartbeat-logs   # 心跳日志
```

## 2. 测试用例设计

### 2.1 emoji_tests.rs (10 用例)

| 测试函数 | 描述 | 前置条件 |
|----------|------|----------|
| `list_available_emoji_packs_success` | 获取可用表情包列表 | 登录用户 |
| `search_emoji_packs_success` | 搜索表情包 | 登录用户 |
| `search_emoji_packs_empty_keyword` | 空关键词搜索 | 登录用户 |
| `list_my_emoji_packs_success` | 获取我的表情包 | 登录用户 |
| `add_emoji_pack_success` | 添加表情包 | 登录用户、有效pack_id |
| `add_emoji_pack_not_found` | 添加不存在的表情包 | 登录用户 |
| `remove_emoji_pack_success` | 移除表情包 | 登录用户、已添加 |
| `emoji_packs_requires_auth` | 未登录访问 | 无token |
| `get_emoji_download_url_success` | 获取下载URL | 登录用户 |
| `list_suite_packs_success` | 获取套装内表情包 | 登录用户 |

### 2.2 chat_tests.rs (6 用例)

| 测试函数 | 描述 | 前置条件 |
|----------|------|----------|
| `list_chats_success` | 获取聊天会话列表 | 登录用户 |
| `list_chats_empty` | 无聊天会话 | 新用户 |
| `list_chats_requires_auth` | 未登录访问 | 无token |
| `delete_chat_success` | 删除聊天会话 | 登录用户、有会话 |
| `delete_chat_not_found` | 删除不存在会话 | 登录用户 |
| `delete_chat_requires_auth` | 未登录删除 | 无token |

### 2.3 report_tests.rs (8 用例)

| 测试函数 | 描述 | 前置条件 |
|----------|------|----------|
| `create_report_success` | 创建举报 | 登录用户 |
| `create_report_missing_fields` | 缺少必填字段 | 登录用户 |
| `create_report_requires_auth` | 未登录举报 | 无token |
| `get_attachment_signature_success` | 获取附件上传签名 | 登录用户 |
| `commit_attachment_success` | 提交附件 | 登录用户、有签名 |
| `admin_list_reports_success` | 管理员查看举报 | 管理员token |
| `admin_list_reports_requires_admin` | 非管理员访问 | 普通用户token |
| `admin_list_reports_requires_auth` | 未登录访问 | 无token |

### 2.4 search_tests.rs (5 用例)

| 测试函数 | 描述 | 前置条件 |
|----------|------|----------|
| `search_messages_success` | 搜索消息 | 登录用户、有消息 |
| `search_messages_empty_result` | 搜索无结果 | 登录用户 |
| `search_messages_requires_auth` | 未登录搜索 | 无token |
| `search_suggestions_success` | 获取搜索建议 | 登录用户 |
| `search_trending_success` | 获取热门搜索 | 登录用户 |

### 2.5 feedback_tests.rs (3 用例)

| 测试函数 | 描述 | 前置条件 |
|----------|------|----------|
| `submit_feedback_success` | 提交反馈 | 登录用户 |
| `submit_feedback_requires_auth` | 未登录提交 | 无token |
| `admin_list_feedbacks_success` | 管理员查看反馈 | 管理员token |

### 2.6 activity_tests.rs (4 用例)

| 测试函数 | 描述 | 前置条件 |
|----------|------|----------|
| `heartbeat_success` | 心跳请求 | 登录用户 |
| `heartbeat_requires_auth` | 未登录心跳 | 无token |
| `get_login_history_success` | 获取登录历史 | 登录用户 |
| `get_heartbeat_logs_success` | 获取心跳日志 | 登录用户 |

## 3. 工具函数扩展

### 3.1 common.rs 新增

```rust
/// 创建举报
pub async fn create_report(
    app: Router,
    token: &str,
    target_type: &str,
    target_id: &str,
    reason: &str
) -> String

/// 提交反馈
pub async fn submit_feedback(
    app: Router,
    token: &str,
    content: &str
) -> String
```

## 4. 文件结构

```
backend/tests/
├── api.rs                    # 入口 (添加新模块)
└── api/
    ├── common.rs             # 共享工具 (扩展)
    ├── emoji_tests.rs        # [NEW] 表情包测试
    ├── chat_tests.rs         # [NEW] 聊天会话测试
    ├── report_tests.rs       # [NEW] 举报测试
    ├── search_tests.rs       # [NEW] 消息搜索测试
    ├── feedback_tests.rs     # [NEW] 反馈测试
    └── activity_tests.rs     # [NEW] 活动日志测试
```

## 5. 执行计划

1. 创建 6 个测试模块文件
2. 更新 api.rs 入口
3. 运行测试验证
4. 修复 API 适配问题
5. 输出测试报告
