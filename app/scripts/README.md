# Flutter 脚本说明

本目录包含 Flutter 项目的运行和构建脚本。

## 快速开始

```bash
# 开发环境运行（默认本机 iOS Simulator）
./scripts/run.sh

# 生产环境构建 APK
./scripts/build.sh --env .env.production apk
```

---

## 环境配置

项目使用 `.env` 文件管理环境变量，位于 `app/` 根目录：

| 文件 | 用途 | 是否提交到 Git |
|------|------|----------------|
| `.env.development` | 开发环境配置 | ✅ 是 |
| `.env.production` | 生产环境配置 | ✅ 是 |
| `.env.*.local` | 本地覆盖配置 | ❌ 否 |

### 配置项说明

```bash
# 环境标识
ENV=development              # development / staging / production

# 服务器地址
API_BASE_URL=http://127.0.0.1:8010
WS_URL=ws://127.0.0.1:8010/ws

# 功能开关
ENABLE_DEBUG_LOG=true        # 调试日志
ENABLE_PERFORMANCE_MONITOR=false  # 性能监控
USE_MOCK_DATA=false          # Mock 数据
```

> `run.sh`、`run_dev.sh` 与 `test_integration.sh device` 默认动态选择本机可用的 iOS Simulator，并使用 `127.0.0.1` 访问 API/WS。显式指定真机时会重新检测当前本机局域网 IP，并覆盖开发环境里的 `API_BASE_URL` / `WS_URL`。
> 设备枚举有超时保护：`flutter devices` 默认 20 秒，`xcrun simctl list devices available` 默认 20 秒；可通过 `FLUTTER_DEVICES_TIMEOUT_SECONDS` / `SIMCTL_TIMEOUT_SECONDS` 覆盖。若本机 Xcode/CoreSimulator runtime 不匹配导致 Simulator 不可用，可先用默认 `macos` target 完成本机 API/WS/auth integration。

### 本地覆盖

如需在本地修改配置（不影响团队其他成员），创建对应的 `.local` 文件：

```bash
# 创建本地开发配置（不会提交到 Git）
cp .env.development .env.development.local
vim .env.development.local
```

---

## 运行脚本

### run.sh（推荐）

统一运行脚本，自动读取 `.env` 配置文件。

```bash
# 基本用法（默认使用 .env.development + 默认验收设备）
./scripts/run.sh

# 指定环境配置
./scripts/run.sh --env .env.production

# 指定运行设备（覆盖默认验收设备）
./scripts/run.sh emulator-5554

# 组合使用
./scripts/run.sh --env .env.production emulator-5554
```

不传设备参数时，脚本动态选择本机可用的 iOS Simulator。如需切换设备，可通过参数覆盖。

**参数说明：**

| 参数 | 说明 |
|------|------|
| `--env, -e <file>` | 指定配置文件，默认 `.env.development` |
| `<device>` | 设备名称或 ID，可通过 `flutter devices` 查看；默认本机 iOS Simulator |
| `--help, -h` | 显示帮助信息 |

---

## 集成测试脚本

### test_integration.sh

统一 app integration 入口，Makefile 已封装常用命令：

```bash
# 不访问真实 api，快速验证 integration harness
make app.test.integration.smoke

# 访问本机 api，默认验收设备；真机自动使用当前 LAN IP，Simulator 使用 127.0.0.1
make app.test.integration.network

# 真实普通账号注册/登录，默认验收设备；真机自动使用当前 LAN IP，Simulator 使用 127.0.0.1
make app.test.integration.auth

# Flutter 首版核心 API 合同，覆盖认证/好友/群/消息/设置/Push device mock
make app.test.integration.contract

# Flutter REST path 与 api/src/routes.rs 机械化对照
make app.test.api-paths

# 设备联调：默认本机 iOS Simulator
make app.test.integration.device
make app.test.integration.device.auth
make app.test.integration.device.contract
```

也可直接调用脚本：

```bash
./scripts/test_integration.sh smoke
./scripts/test_integration.sh network --api-base-url http://127.0.0.1:8010 --ws-url ws://127.0.0.1:8010/ws
./scripts/test_integration.sh auth --api-base-url http://127.0.0.1:8010 --ws-url ws://127.0.0.1:8010/ws
./scripts/test_integration.sh contract --api-base-url http://127.0.0.1:8010 --ws-url ws://127.0.0.1:8010/ws
./scripts/test_integration.sh device --device emulator-5554
```

`smoke`、`network`、`auth`、`contract` 与 `device` 模式默认使用本机 iOS Simulator。显式指定真机执行时会在每次执行前重新检测当前本机局域网 IP，并注入：

```bash
API_BASE_URL=http://<LAN_IP>:8010
WS_URL=ws://<LAN_IP>:8010/ws
```

iOS Simulator 执行时使用：

```bash
API_BASE_URL=http://127.0.0.1:8010
WS_URL=ws://127.0.0.1:8010/ws
```

Makefile 中 `APP_TEST_DEVICE` / `FRONTEND_TEST_DEVICE` / `FLUTTER_DEVICE` 都可用于强制指定设备；都为空时脚本会选择本机 iOS Simulator，例如：

```bash
make app.test.integration.network APP_TEST_DEVICE=emulator-5554
make app.test.integration.device FLUTTER_DEVICE=emulator-5554
```

---

## 构建脚本

### build.sh（推荐）

统一构建脚本，支持 APK、AAB、IPA 打包。

```bash
# 交互式选择（显示菜单）
./scripts/build.sh

# 直接指定构建类型
./scripts/build.sh apk      # Android APK（直接安装）
./scripts/build.sh aab      # Android AAB（Google Play）
./scripts/build.sh ipa      # iOS IPA
./scripts/build.sh all      # 全部构建

# 生产环境构建
./scripts/build.sh --env .env.production apk
./scripts/build.sh --env .env.production ipa
```

**参数说明：**

| 参数 | 说明 |
|------|------|
| `--env, -e <file>` | 指定配置文件，默认 `.env.development` |
| `apk` | 构建 Android APK |
| `aab` | 构建 Android App Bundle |
| `ipa` | 构建 iOS IPA（需 macOS） |
| `all` | 构建所有类型 |
| `--help, -h` | 显示帮助信息 |

**构建产物位置：**

| 类型 | 路径 |
|------|------|
| APK | `build/app/outputs/flutter-apk/app-release.apk` |
| AAB | `build/app/outputs/bundle/release/app-release.aab` |
| IPA | `build/ios/ipa/runner.ipa` |

---

## 脚本目录

```
scripts/
├── run.sh                   # 统一运行脚本（推荐）
├── build.sh                 # 统一构建脚本（推荐）
├── common.sh                # 通用函数库
│
├── run_dev.sh               # 开发环境运行（传统，默认验收设备）
├── run_prod.sh              # 生产环境运行（传统）
├── run_custom.sh            # 自定义 API 运行（传统）
├── run_flutter.sh           # 基础运行脚本（默认本机 iOS Simulator）
├── test_integration.sh      # integration smoke / api 联通 / 设备联调测试
│
├── build_android.sh         # Android 打包（传统）
├── build_ipa.sh             # iOS 打包（传统）
├── build_android_hot_patch.sh  # Android 热更新
├── build_ios_hot_patch.sh   # iOS 热更新
│
├── update_app_name.sh       # 更新应用名称
└── test_api.sh              # API 连通性测试
```

---

## 直接使用 Flutter 命令

如果不使用脚本，可以直接传入 `--dart-define` 参数：

```bash
# 运行
LAN_IFACE=$(route -n get default | awk '/interface:/{print $2}')
LAN_IP=$(ipconfig getifaddr "$LAN_IFACE")

flutter run -d <device-id> \
    --dart-define=ENV=development \
    --dart-define=API_BASE_URL=http://${LAN_IP}:8010 \
    --dart-define=WS_URL=ws://${LAN_IP}:8010/ws \
    --dart-define=ENABLE_DEBUG_LOG=true

# 构建
flutter build apk --release \
    --dart-define=ENV=production \
    --dart-define=API_BASE_URL=https://im-test-1.codelib.cc \
    --dart-define=WS_URL=wss://im-test-1.codelib.cc/ws
```

---

## 注意事项

1. 所有脚本可从任意目录执行，会自动切换到 `app/` 目录
2. 构建脚本会自动执行 `flutter clean` 和 `flutter pub get`
3. iOS 相关脚本需要在 macOS 系统上执行
4. 首次运行前确保已安装 Flutter SDK
