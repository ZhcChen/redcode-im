# RedCode IM - 待完成任务清单

## 🔴 高优先级 (影响核心功能)

### 1. 后端 - 管理员密码加密 (backend)
**位置**: `backend/src/handlers/admin.rs:928, 1090`
```rust
// TODO: 临时禁用，需要更新 argon2 API 到 0.6
```
**影响**: 管理员创建用户功能不可用
**状态**: ❌ 未完成
**优先级**: 🔴 高
**解决方案**:
- 升级 argon2 到 0.6 正式版并更新 API 调用
- 或统一使用 bcrypt 替代

---

### 2. 后端 - 文件上传 multipart 处理
**位置**: `backend/src/handlers/user.rs:381`
```rust
// TODO: 接收 multipart/form-data 文件上传
```
**影响**: 头像直传功能不完整
**状态**: ❌ 未完成
**优先级**: 🔴 高
**解决方案**: 实现完整的 multipart/form-data 处理逻辑

---

### 3. 前端 - WebSocket 事件业务逻辑 (desktop)
**位置**: `desktop/src/utils/websocket.ts`

#### 3.1 群聊创建逻辑 (第905行)
```typescript
// TODO: 实现群聊创建逻辑
return { success: true }; // Mock 实现
```

#### 3.2 群聊删除逻辑 (第913行)
```typescript
// TODO: 实现群聊删除逻辑
return { success: true }; // Mock 实现
```

#### 3.3 删除好友逻辑 (第921行)
```typescript
// TODO: 实现删除好友逻辑
return { success: true }; // Mock 实现
```

#### 3.4 好友状态变更逻辑 (第929行)
```typescript
// TODO: 实现好友状态变更逻辑
return { success: true }; // Mock 实现
```

**影响**: WebSocket 事件返回假数据，群聊和好友操作不生效
**状态**: ❌ 未完成
**优先级**: 🔴 高

---

## 🟠 中优先级 (功能完善)

### 4. 前端 - 群聊管理对话框 (desktop)
**位置**: `desktop/src/views/Chat.vue`

#### 4.1 添加成员对话框 (第4007行)
```typescript
// TODO: 实现添加成员对话框
```

#### 4.2 删除成员对话框 (第4013行)
```typescript
// TODO: 实现删除成员对话框
```

#### 4.3 举报功能 (第4051行)
```typescript
// TODO: 实现举报功能
```

**影响**: 群聊管理UI功能缺失
**状态**: ❌ 未完成
**优先级**: 🟠 中

---

### 5. 前端 (Flutter) - 聊天功能 (frontend)
**位置**: `frontend/lib/features/chat/`

#### 5.1 删除消息 (chat_provider.dart:327)
```dart
// TODO: 调用API删除
```

#### 5.2 更新未读数 (chat_provider.dart:347)
```dart
// TODO: 调用API更新
```

#### 5.3 更新置顶状态 (chat_provider.dart:358)
```dart
// TODO: 调用API更新
```

#### 5.4 清空聊天记录 (chat_provider.dart:369)
```dart
// TODO: 调用API清空
```

#### 5.5 语音功能 (chat_detail_page_v2.dart:826)
```dart
// TODO: 实现语音功能
```

**影响**: Flutter 移动端聊天功能不完整
**状态**: ❌ 未完成
**优先级**: 🟠 中

---

## 🟡 低优先级 (体验优化)

### 6. 前端 - 音频波形可视化 (desktop)
**位置**: `desktop/src/utils/voiceRecorder.ts:332`
```typescript
// TODO: 实现音频波形可视化
```
**影响**: 录音时缺少波形动画
**状态**: ❌ 未完成
**优先级**: 🟡 低

---

### 7. 后端 - 测试用例待完善
**位置**: `backend/tests/file_upload_test.rs:110, 115`
```rust
todo!("实现测试应用创建逻辑")
todo!("实现测试token生成逻辑")
```
**影响**: 文件上传测试覆盖不完整
**状态**: ❌ 未完成
**优先级**: 🟡 低

---

### 8. 前端 (Flutter) - Android 构建配置
**位置**: `frontend/android/app/build.gradle.kts`

#### 8.1 应用 ID 配置 (第23行)
```kotlin
// TODO: Specify your own unique Application ID
```

#### 8.2 签名配置 (第35行)
```kotlin
// TODO: Add your own signing config for the release build.
```

**影响**: Android 发布配置未完成
**状态**: ❌ 未完成
**优先级**: 🟡 低

---

### 9. 管理后台 - ECharts 主题 (admin)
**位置**: `admin/src/hooks/chart-option.ts:20`
```typescript
// TODO echarts themes
```
**影响**: 图表主题待优化
**状态**: ❌ 未完成
**优先级**: 🟡 低

---

## 📊 统计概览

| 优先级 | 数量 | 模块分布 |
|--------|------|----------|
| 🔴 高优先级 | 3 | 后端(2) + 前端桌面端(1) |
| 🟠 中优先级 | 2 | 前端桌面端(1) + 前端移动端(1) |
| 🟡 低优先级 | 4 | 后端测试(1) + 前端(2) + 管理后台(1) |
| **总计** | **9** | - |

---

## 🎯 推荐处理顺序

### 第一阶段 (本周)
1. ✅ 修复 argon2 密码加密问题
2. ✅ 实现 WebSocket 事件真实业务逻辑 (4个TODO)
3. ✅ 完成文件上传 multipart 处理

### 第二阶段 (下周)
4. ✅ 实现群聊管理对话框 (添加/删除成员、举报)
5. ✅ 完善 Flutter 端聊天 API 调用

### 第三阶段 (有空时)
6. ✅ 音频波形可视化
7. ✅ 测试用例补充
8. ✅ Android 发布配置
9. ✅ 图表主题优化

---

**最后更新**: 2025-11-08
**总完成度**: 0/9 (0%)
