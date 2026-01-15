# Flutter E2E 测试方案

## 概述

本项目使用 [Patrol](https://patrol.leancode.co/) 作为 E2E 测试框架。Patrol 是专为 Flutter 设计的测试框架，能够与原生系统组件交互（如权限弹窗、通知、文件选择器等）。

## 技术选型

| 方案 | 优势 | 劣势 | 选择理由 |
|------|------|------|---------|
| **Patrol** | 原生交互、Flutter 专属、生产级 | 需要额外配置 | IM 应用需要处理权限、通知等原生功能 |
| integration_test | 官方支持、简单 | 无法与原生交互 | 不适合 IM 应用 |
| Maestro | 无代码、快速 | YAML 定义、非 Flutter 专用 | 灵活性不足 |

## 目录结构

```
frontend/
├── integration_test/           # E2E 测试目录
│   ├── test_bundle.dart        # 测试入口（导出所有测试）
│   ├── common/                 # 公共配置
│   │   ├── test_config.dart    # 测试配置（账号、服务器等）
│   │   └── test_app.dart       # 测试应用封装
│   ├── auth/                   # 认证模块测试
│   │   └── login_test.dart     # 登录测试
│   ├── chat/                   # 聊天模块测试
│   │   └── chat_list_test.dart # 聊天列表测试
│   ├── contacts/               # 联系人模块测试
│   └── settings/               # 设置模块测试
├── pubspec.yaml                # 已添加 patrol 依赖
└── android/app/build.gradle.kts # 已配置 Patrol Runner
```

## 环境准备

### 1. 安装 Patrol CLI

```bash
dart pub global activate patrol_cli
```

确保 `~/.pub-cache/bin` 在 PATH 中：

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

### 2. 安装依赖

```bash
cd frontend
flutter pub get
```

### 3. 验证安装

```bash
patrol doctor
```

## 运行测试

### 运行前准备（后端与测试数据）

E2E 测试依赖后端服务可用（默认 `http://localhost:8010`），并建议先准备固定测试账号/好友/房间数据：

```bash
docker-compose -f tests/docker-compose.yml up -d --build
```

另开终端：

```bash
cd backend
./test_flow.sh
```

如需在本地覆盖 Flutter 的 API/WS 地址，可通过 `--dart-define` 传入：

```bash
# iOS Simulator / 桌面：localhost
patrol test --dart-define=API_BASE_URL=http://localhost:8010 --dart-define=WS_URL=ws://localhost:8010/ws
```

> Android 模拟器访问宿主机后端：把 `localhost` 替换为 `10.0.2.2`；真机请使用宿主机 IP。
> 若你的 patrol 版本不识别 `--dart-define`，可尝试通过 `--` 透传给 flutter：`patrol test -- --dart-define=...`。

### 运行所有测试

```bash
cd frontend
patrol test
```

### 运行指定测试文件

```bash
patrol test --target integration_test/auth/login_test.dart
```

### 运行指定设备

```bash
# Android
patrol test --target integration_test/auth/login_test.dart --device emulator-5554

# iOS
patrol test --target integration_test/auth/login_test.dart --device iPhone
```

### 调试模式（热重载）

```bash
patrol develop
```

## 测试用例规范

### 命名规范

- 测试文件：`<模块>_test.dart`，如 `login_test.dart`
- 测试描述：`<页面/功能> - <测试场景>`

### 代码规范

```dart
import 'package:patrol/patrol.dart';
import '../common/test_app.dart';
import '../common/test_config.dart';

void main() {
  patrolTest('登录页面 - 输入正确账号密码可登录成功', ($) async {
    // 1. 启动应用
    await $.pumpWidgetAndSettle(const TestApp());

    // 2. 等待页面加载
    await $.pump(const Duration(seconds: 3));

    // 3. 执行操作
    await $(TextField).at(0).enterText(TestConfig.testUser.mobile);
    await $(TextField).at(1).enterText(TestConfig.testUser.password);
    await $('登录账号').tap();

    // 4. 验证结果
    await $.pump(const Duration(seconds: 3));
    expect($(BottomNavigationBar), findsOneWidget);
  });
}
```

### 原生交互示例

```dart
// 处理权限弹窗
await $.native.grantPermissionWhenInUse();

// 处理通知
await $.native.openNotifications();
await $.native.tapOnNotificationByIndex(0);

// 切换网络
await $.native.disableWifi();
await $.native.enableWifi();

// 处理系统弹窗
await $.native.tap(Selector(text: '允许'));
```

## 测试模块清单

---

## 一、认证模块 (auth)

### 测试用例总览

| ID | 测试用例 | 优先级 | 状态 |
|----|---------|--------|------|
| AUTH-001 | 登录页面 UI 元素显示 | P0 | ✅ |
| AUTH-002 | 空表单提交错误提示 | P0 | ✅ |
| AUTH-003 | 用户协议勾选控制登录按钮 | P0 | ✅ |
| AUTH-004 | 密码登录 - 正确账号密码 | P0 | 待测 |
| AUTH-005 | 密码登录 - 错误密码 | P0 | 待测 |
| AUTH-006 | 密码登录 - 账号不存在 | P0 | 待测 |
| AUTH-007 | 验证码登录 - 发送验证码 | P0 | 待测 |
| AUTH-008 | 验证码登录 - 正确验证码 | P0 | 待测 |
| AUTH-009 | 验证码登录 - 错误验证码 | P0 | 待测 |
| AUTH-010 | 注册 - 新用户注册流程 | P1 | 待测 |
| AUTH-011 | 注册 - 手机号已存在 | P1 | 待测 |
| AUTH-012 | 忘记密码 - 重置流程 | P2 | 待测 |
| AUTH-013 | 登录状态持久化 | P1 | 待测 |
| AUTH-014 | Token 过期自动跳转登录 | P1 | 待测 |

### 详细测试用例

#### AUTH-001: 登录页面 UI 元素显示

**前置条件**: 应用首次启动或未登录状态

**测试步骤**:
1. 启动应用
2. 等待登录页面加载完成

**预期结果**:
- [ ] 显示手机号输入框
- [ ] 显示密码输入框
- [ ] 显示"登录账号"按钮
- [ ] 显示"验证码登录"入口
- [ ] 显示"注册账号"入口
- [ ] 显示用户协议复选框

**选择器策略**（零侵入）:
```dart
$(TextField)                    // 输入框（按索引或 hint 区分）
$('登录账号')                    // 登录按钮（文本）
$('验证码登录')                  // 验证码登录入口
$('注册账号')                    // 注册入口
$(Checkbox)                     // 协议复选框
$('用户协议')                    // 协议文本
```

---

#### AUTH-004: 密码登录 - 正确账号密码

**前置条件**:
- 测试账号已注册: 13800138000 / Test123456

**测试步骤**:
1. 输入手机号 `13800138000`
2. 输入密码 `Test123456`
3. 勾选用户协议
4. 点击"登录账号"按钮
5. 等待登录完成

**预期结果**:
- [ ] 显示登录中 loading
- [ ] 登录成功跳转到主页
- [ ] 底部导航栏显示

**测试代码**（零侵入）:
```dart
patrolTest('AUTH-004: 密码登录 - 正确账号密码', ($) async {
  await $.pumpWidgetAndSettle(const MyApp());

  // 使用文本/hint 定位输入框
  await $(TextField).first.enterText('13800138000');
  await $(TextField).last.enterText('Test123456');

  // 勾选协议
  await $(Checkbox).tap();

  // 点击登录（使用按钮文本）
  await $('登录账号').tap();

  await $.pump(const Duration(seconds: 3));
  expect($(BottomNavigationBar), findsOneWidget);
});
```

---

#### AUTH-007: 验证码登录 - 发送验证码

**前置条件**: 无

**测试步骤**:
1. 点击"验证码登录"切换登录方式
2. 输入手机号 `13800138000`
3. 点击"获取验证码"按钮
4. 等待倒计时开始

**预期结果**:
- [ ] 显示验证码输入框
- [ ] "获取验证码"按钮变为倒计时(60s)
- [ ] 显示"验证码已发送"提示

**选择器策略**（零侵入）:
```dart
$('验证码登录')                  // 切换按钮
$('获取验证码')                  // 发送验证码按钮
$('验证码已发送')                // 成功提示
$(TextField).at(1)              // 验证码输入框（第二个输入框）
```

---

## 二、聊天模块 (chat)

### 测试用例总览

| ID | 测试用例 | 优先级 | 状态 |
|----|---------|--------|------|
| CHAT-001 | 聊天列表显示 | P0 | 待测 |
| CHAT-002 | 聊天列表 - 下拉刷新 | P1 | 待测 |
| CHAT-003 | 聊天列表 - 搜索会话 | P1 | 待测 |
| CHAT-004 | 进入私聊详情页 | P0 | 待测 |
| CHAT-005 | 发送文本消息 | P0 | 待测 |
| CHAT-006 | 发送图片消息（相册权限）| P0 | 待测 |
| CHAT-007 | 发送语音消息（麦克风权限）| P0 | 待测 |
| CHAT-008 | 发送视频消息 | P1 | 待测 |
| CHAT-009 | 发送文件消息 | P1 | 待测 |
| CHAT-010 | 消息已读状态显示 | P1 | 待测 |
| CHAT-011 | 消息撤回（2分钟内）| P1 | 待测 |
| CHAT-012 | 消息复制 | P2 | 待测 |
| CHAT-013 | 消息转发 | P2 | 待测 |
| CHAT-014 | 消息搜索 | P2 | 待测 |
| CHAT-015 | 会话置顶 | P2 | 待测 |
| CHAT-016 | 会话免打扰 | P2 | 待测 |
| CHAT-017 | 删除会话 | P2 | 待测 |

### 详细测试用例

#### CHAT-001: 聊天列表显示

**前置条件**: 用户已登录，有历史会话

**测试步骤**:
1. 从主页进入消息 Tab
2. 等待聊天列表加载

**预期结果**:
- [ ] 显示会话列表
- [ ] 每个会话显示：头像、昵称、最后一条消息、时间
- [ ] 未读消息显示红点/数字角标
- [ ] 置顶会话显示在顶部

**选择器策略**（零侵入）:
```dart
$('消息')                       // 消息 Tab
$(ListView)                     // 会话列表
$(ListTile)                     // 会话项
$(Badge)                        // 未读角标（如使用 Badge 组件）
```

---

#### CHAT-005: 发送文本消息

**前置条件**: 已进入聊天详情页

**测试步骤**:
1. 点击输入框
2. 输入文本 "Hello, this is a test message"
3. 点击发送按钮
4. 等待消息发送

**预期结果**:
- [ ] 消息显示在聊天记录中
- [ ] 显示发送中状态（时钟图标）
- [ ] 发送成功后显示已发送状态
- [ ] 滚动到最新消息

**测试代码**（零侵入）:
```dart
patrolTest('CHAT-005: 发送文本消息', ($) async {
  // 使用 hint 文本定位输入框
  await $(TextField).containing('输入消息').enterText('Hello, test message');

  // 使用图标或文本定位发送按钮
  await $(IconButton).containing(Icons.send).tap();
  // 或: await $('发送').tap();

  await $.pump(const Duration(seconds: 2));
  expect($('Hello, test message'), findsOneWidget);
});
```

---

#### CHAT-006: 发送图片消息（相册权限）

**前置条件**: 已进入聊天详情页

**测试步骤**:
1. 点击"+"按钮打开更多功能
2. 点击"相册"选项
3. **处理相册权限弹窗**
4. 选择一张图片
5. 确认发送

**预期结果**:
- [ ] 权限弹窗正确处理
- [ ] 图片选择器正常打开
- [ ] 图片消息显示在聊天中
- [ ] 显示上传进度

**测试代码**（零侵入 + 原生交互）:
```dart
patrolTest('CHAT-006: 发送图片消息', ($) async {
  // 打开更多功能
  await $(Icons.add).tap();

  // 选择相册
  await $('相册').tap();

  // 处理 Android 权限弹窗（原生交互）
  await $.native.grantPermissionWhenInUse();

  // 等待图片选择器
  await $.pump(const Duration(seconds: 1));
});
```

---

## 三、联系人模块 (contacts)

### 测试用例总览

| ID | 测试用例 | 优先级 | 状态 |
|----|---------|--------|------|
| CONT-001 | 联系人列表显示 | P0 | 待测 |
| CONT-002 | 联系人列表 - 按字母索引 | P1 | 待测 |
| CONT-003 | 联系人列表 - 搜索好友 | P1 | 待测 |
| CONT-004 | 查看好友详情页 | P0 | 待测 |
| CONT-005 | 从详情页发起聊天 | P0 | 待测 |
| CONT-006 | 添加好友 - 搜索用户 | P0 | 待测 |
| CONT-007 | 添加好友 - 发送申请 | P0 | 待测 |
| CONT-008 | 好友申请 - 同意申请 | P0 | 待测 |
| CONT-009 | 好友申请 - 拒绝申请 | P1 | 待测 |
| CONT-010 | 删除好友 | P2 | 待测 |
| CONT-011 | 设置好友备注 | P2 | 待测 |
| CONT-012 | 好友黑名单 | P2 | 待测 |

### 详细测试用例

#### CONT-001: 联系人列表显示

**前置条件**: 用户已登录，有好友

**测试步骤**:
1. 从主页进入联系人 Tab
2. 等待联系人列表加载

**预期结果**:
- [ ] 显示好友列表
- [ ] 显示字母索引栏
- [ ] 每个好友显示：头像、昵称、备注（如有）
- [ ] 顶部显示"新朋友"入口

**选择器策略**（零侵入）:
```dart
$('联系人')                     // 联系人 Tab
$('新朋友')                     // 新朋友入口
$(ListView)                     // 联系人列表
$(ListTile)                     // 联系人项
```

---

#### CONT-006: 添加好友 - 搜索用户

**前置条件**: 用户已登录

**测试步骤**:
1. 点击"添加好友"按钮
2. 在搜索框输入手机号或用户 ID
3. 点击搜索
4. 等待搜索结果

**预期结果**:
- [ ] 显示搜索结果用户信息
- [ ] 显示"添加好友"按钮
- [ ] 若已是好友，显示"发消息"按钮

**测试代码**（零侵入）:
```dart
patrolTest('CONT-006: 添加好友 - 搜索用户', ($) async {
  // 点击添加好友
  await $(Icons.person_add).tap();
  // 或: await $('添加好友').tap();

  // 输入搜索内容
  await $(TextField).enterText('13800138001');

  // 点击搜索
  await $('搜索').tap();

  await $.pump(const Duration(seconds: 2));
  expect($('添加'), findsOneWidget);
});
```

---

## 四、群聊模块 (group)

### 测试用例总览

| ID | 测试用例 | 优先级 | 状态 |
|----|---------|--------|------|
| GRP-001 | 创建群聊 | P0 | 待测 |
| GRP-002 | 群聊详情页显示 | P0 | 待测 |
| GRP-003 | 群设置 - 修改群名称 | P1 | 待测 |
| GRP-004 | 群设置 - 修改群头像 | P2 | 待测 |
| GRP-005 | 群设置 - 修改群公告 | P1 | 待测 |
| GRP-006 | 群成员管理 - 查看成员 | P0 | 待测 |
| GRP-007 | 群成员管理 - 邀请成员 | P0 | 待测 |
| GRP-008 | 群成员管理 - 移除成员 | P1 | 待测 |
| GRP-009 | 群成员管理 - 设置管理员 | P1 | 待测 |
| GRP-010 | 群消息免打扰 | P2 | 待测 |
| GRP-011 | 群消息置顶 | P2 | 待测 |
| GRP-012 | 退出群聊 | P1 | 待测 |
| GRP-013 | 解散群聊（群主）| P1 | 待测 |
| GRP-014 | 群禁言 - 全体禁言 | P2 | 待测 |
| GRP-015 | 群禁言 - 单人禁言 | P2 | 待测 |
| GRP-016 | 加入群聊申请 | P1 | 待测 |
| GRP-017 | 审批入群申请 | P1 | 待测 |

### 详细测试用例

#### GRP-001: 创建群聊

**前置条件**: 用户已登录，有好友

**测试步骤**:
1. 从联系人页点击"创建群聊"
2. 选择至少 2 个好友
3. 点击"确定"
4. 输入群名称（可选）
5. 点击"创建"

**预期结果**:
- [ ] 好友选择页正常显示
- [ ] 可多选好友
- [ ] 群聊创建成功
- [ ] 自动跳转到群聊会话

**测试代码**（零侵入）:
```dart
patrolTest('GRP-001: 创建群聊', ($) async {
  // 点击创建群聊
  await $('发起群聊').tap();

  // 选择好友（点击复选框或头像）
  await $(Checkbox).at(0).tap();
  await $(Checkbox).at(1).tap();

  // 确定选择
  await $('确定').tap();

  // 输入群名称（可选）
  await $(TextField).enterText('测试群聊');

  // 创建群聊
  await $('创建').tap();

  await $.pump(const Duration(seconds: 2));
  expect($('测试群聊'), findsOneWidget);
});
```

---

#### GRP-007: 群成员管理 - 邀请成员

**前置条件**: 用户是群主或管理员

**测试步骤**:
1. 进入群设置页
2. 点击"群成员"
3. 点击"+"邀请成员
4. 选择要邀请的好友
5. 点击确认

**预期结果**:
- [ ] 邀请好友列表显示
- [ ] 已在群内的好友不可选
- [ ] 邀请成功提示
- [ ] 群成员列表更新

**选择器策略**（零侵入）:
```dart
$('群成员')                     // 群成员入口
$(Icons.add)                    // 邀请成员按钮
$(Checkbox)                     // 成员选择
$('确定')                       // 确认按钮
$('邀请成功')                   // 成功提示
```

---

## 五、设置模块 (settings)

### 测试用例总览

| ID | 测试用例 | 优先级 | 状态 |
|----|---------|--------|------|
| SET-001 | 个人资料页显示 | P0 | 待测 |
| SET-002 | 修改昵称 | P1 | 待测 |
| SET-003 | 修改头像（相册权限）| P1 | 待测 |
| SET-004 | 修改头像（相机权限）| P1 | 待测 |
| SET-005 | 修改个性签名 | P2 | 待测 |
| SET-006 | 账号与安全 - 修改密码 | P1 | 待测 |
| SET-007 | 账号与安全 - 绑定手机 | P2 | 待测 |
| SET-008 | 隐私设置 - 谁可以添加我 | P2 | 待测 |
| SET-009 | 通知设置 - 消息通知开关 | P1 | 待测 |
| SET-010 | 通用设置 - 清除缓存 | P2 | 待测 |
| SET-011 | 关于 - 版本信息 | P2 | 待测 |
| SET-012 | 退出登录 | P0 | 待测 |
| SET-013 | 注销账号 | P2 | 待测 |

### 详细测试用例

#### SET-001: 个人资料页显示

**前置条件**: 用户已登录

**测试步骤**:
1. 从主页进入"我的" Tab
2. 点击个人信息区域
3. 等待个人资料页加载

**预期结果**:
- [ ] 显示头像
- [ ] 显示昵称
- [ ] 显示用户 ID
- [ ] 显示个性签名
- [ ] 显示二维码入口

**选择器策略**（零侵入）:
```dart
$('我的')                       // 我的 Tab
$(CircleAvatar)                 // 头像
$('二维码')                     // 二维码入口
// 昵称、签名等通过具体文本验证
```

---

#### SET-012: 退出登录

**前置条件**: 用户已登录

**测试步骤**:
1. 进入设置页
2. 滚动到底部
3. 点击"退出登录"
4. 确认退出

**预期结果**:
- [ ] 显示确认弹窗
- [ ] 点击确认后退出登录
- [ ] 跳转到登录页
- [ ] 清除本地登录状态

**测试代码**（零侵入）:
```dart
patrolTest('SET-012: 退出登录', ($) async {
  // 进入我的页面
  await $('我的').tap();

  // 进入设置
  await $('设置').tap();

  // 滚动到底部并点击退出（使用文本）
  await $('退出登录').scrollTo();
  await $('退出登录').tap();

  // 确认退出（弹窗按钮文本）
  await $('确定').tap();

  // 验证跳转到登录页
  await $.pump(const Duration(seconds: 2));
  expect($('登录账号'), findsOneWidget);
});
```

---

## 测试优先级说明

| 优先级 | 说明 | 执行频率 |
|--------|------|----------|
| **P0** | 核心功能，必须通过 | 每次提交 |
| **P1** | 重要功能，应该通过 | 每日构建 |
| **P2** | 次要功能，尽量通过 | 每周/发版前 |

## 测试覆盖目标

| 模块 | P0 用例数 | P1 用例数 | P2 用例数 | 目标覆盖率 |
|------|-----------|-----------|-----------|-----------|
| 认证 | 9 | 4 | 1 | 100% P0 |
| 聊天 | 4 | 6 | 7 | 100% P0 |
| 联系人 | 5 | 3 | 4 | 100% P0 |
| 群聊 | 2 | 9 | 6 | 100% P0 |
| 设置 | 2 | 4 | 7 | 100% P0 |
| **合计** | **22** | **26** | **25** | - |

## 测试配置

### 测试账号

在 `integration_test/common/test_config.dart` 中配置：

```dart
class TestConfig {
  /// 测试服务器地址
  static const String baseUrl = 'http://localhost:3000';

  /// 测试账号
  static const TestAccount testUser = TestAccount(
    mobile: '13800138000',
    password: 'Test123456',
    nickname: '测试用户',
  );
}
```

### 测试数据准备

建议在测试前：

1. 确保测试服务器运行
2. 创建测试账号
3. 准备测试好友关系
4. 准备测试群聊

可以使用后端提供的种子数据脚本初始化测试环境。

## CI/CD 集成

### GitHub Actions 示例

```yaml
name: E2E Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  e2e-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.29.0'

      - name: Install Patrol CLI
        run: dart pub global activate patrol_cli

      - name: Run E2E tests
        run: |
          cd frontend
          flutter pub get
          patrol test --target integration_test/auth/login_test.dart
```

### 云测试平台

Patrol 支持以下云测试平台：

- Firebase Test Lab
- BrowserStack
- AWS Device Farm
- LambdaTest

## 最佳实践

### 1. 测试隔离

- 每个测试用例应独立运行
- 使用 `clearPackageData` 清理应用状态
- 避免测试之间的依赖

### 2. 选择器策略（最小侵入原则）

**优先级从高到低**：

```dart
// 1. 优先使用文本选择器（零侵入）
await $('登录账号').tap();
await $('请输入手机号').enterText('13800138000');

// 2. 使用类型 + 文本组合（零侵入）
await $(ElevatedButton).containing('登录').tap();
await $(TextField).withHint('请输入手机号').enterText('...');

// 3. 使用 Semantics（有无障碍价值，推荐）
// 业务代码中：
Semantics(label: 'login_button', child: ElevatedButton(...))
// 测试代码中：
await $(Semantics).containing('login_button').tap();

// 4. 最后才用 Key（仅在上述方案都不适用时）
await $(#mobile_field).enterText('...');
```

**何时必须用 Key**：
- 同类型多个无文本元素（如多个图标按钮）
- 列表项需要精确定位
- 元素无可识别文本且不适合加 Semantics

### 3. 等待策略

```dart
// 使用 pumpAndSettle 等待动画完成
await $.pumpWidgetAndSettle(const TestApp());

// 使用 pump 等待固定时间
await $.pump(const Duration(seconds: 2));

// 使用 waitUntilVisible 等待元素出现
await $.waitUntilVisible($('首页'));
```

### 4. 错误处理

```dart
patrolTest('测试用例', ($) async {
  // 检查元素是否存在再操作
  final button = $('按钮文本');
  if (button.exists) {
    await button.tap();
  }
});
```

## 常见问题

### Q: 测试运行失败，提示找不到 Patrol

确保已安装 Patrol CLI 并添加到 PATH：

```bash
dart pub global activate patrol_cli
export PATH="$PATH:$HOME/.pub-cache/bin"
```

### Q: Android 测试失败

检查 `android/app/build.gradle.kts` 是否正确配置了 `testInstrumentationRunner`。

### Q: iOS 测试无法处理权限弹窗

确保在 Xcode 中正确配置了 UI Test Target。

### Q: 测试超时

增加超时时间：

```dart
final patrolTesterConfig = PatrolTesterConfig(
  settleTimeout: const Duration(seconds: 30),
);
```

## 参考资料

- [Patrol 官方文档](https://patrol.leancode.co/)
- [Patrol GitHub](https://github.com/leancodepl/patrol)
- [Flutter 集成测试文档](https://docs.flutter.dev/testing/integration-tests)
