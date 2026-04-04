# Flutter 脚本说明

本目录包含 Flutter 项目的运行和构建脚本。

## 快速开始

```bash
# 开发环境运行（默认测试真机：Mi MIX 2S / 2b252911）
./scripts/run.sh

# 生产环境构建 APK
./scripts/build.sh --env .env.production apk
```

---

## 环境配置

项目使用 `.env` 文件管理环境变量，位于 `frontend/` 根目录：

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
API_BASE_URL=http://10.137.203.83:8010
WS_URL=ws://10.137.203.83:8010/ws

# 功能开关
ENABLE_DEBUG_LOG=true        # 调试日志
ENABLE_PERFORMANCE_MONITOR=false  # 性能监控
USE_MOCK_DATA=false          # Mock 数据
```

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
# 基本用法（默认使用 .env.development + 默认测试真机 Mi MIX 2S）
./scripts/run.sh

# 指定环境配置
./scripts/run.sh --env .env.production

# 指定运行设备（覆盖默认真机）
./scripts/run.sh 2b252911
./scripts/run.sh emulator-5554

# 组合使用
./scripts/run.sh --env .env.production emulator-5554
```

不传设备参数时，脚本默认使用测试真机 `Mi MIX 2S (2b252911)`；如需切换设备，可通过参数覆盖。

**参数说明：**

| 参数 | 说明 |
|------|------|
| `--env, -e <file>` | 指定配置文件，默认 `.env.development` |
| `<device>` | 设备名称或 ID，可通过 `flutter devices` 查看；默认测试真机为 `Mi MIX 2S (2b252911)` |
| `--help, -h` | 显示帮助信息 |

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
├── run_dev.sh               # 开发环境运行（传统）
├── run_prod.sh              # 生产环境运行（传统）
├── run_custom.sh            # 自定义 API 运行（传统）
├── run_flutter.sh           # 基础运行脚本（默认 Mi MIX 2S 真机）
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
flutter run -d 2b252911 \
    --dart-define=ENV=development \
    --dart-define=API_BASE_URL=http://10.137.203.83:8010 \
    --dart-define=WS_URL=ws://10.137.203.83:8010/ws \
    --dart-define=ENABLE_DEBUG_LOG=true

# 构建
flutter build apk --release \
    --dart-define=ENV=production \
    --dart-define=API_BASE_URL=https://api.chatlyme.com \
    --dart-define=WS_URL=wss://api.chatlyme.com/ws
```

---

## 注意事项

1. 所有脚本可从任意目录执行，会自动切换到 `frontend/` 目录
2. 构建脚本会自动执行 `flutter clean` 和 `flutter pub get`
3. iOS 相关脚本需要在 macOS 系统上执行
4. 首次运行前确保已安装 Flutter SDK
