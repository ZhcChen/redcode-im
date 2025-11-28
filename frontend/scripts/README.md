# Flutter 脚本说明

本目录包含 Flutter 项目的各种运行和构建脚本。

## 快速开始（推荐方式）

使用 `.env` 文件管理环境配置：

```bash
# 1. 复制配置模板
cp .env.example .env

# 2. 编辑配置
vim .env

# 3. 运行应用
./scripts/run.sh

# 4. 构建应用
./scripts/build.sh apk
```

## 目录结构

```
scripts/
├── README.md                    # 本说明文档
├── common.sh                    # 通用函数库（被其他脚本引用）
├── run.sh                       # 统一运行脚本（读取 .env）
├── build.sh                     # 统一构建脚本（读取 .env）
├── run_dev.sh                   # 开发环境运行脚本（传统方式）
├── run_prod.sh                  # 生产环境运行脚本（传统方式）
├── run_custom.sh                # 自定义 API 地址运行脚本
├── run_flutter.sh               # 基础运行脚本
├── build_android.sh             # Android 打包脚本（传统方式）
├── build_ipa.sh                 # iOS IPA 打包脚本（传统方式）
├── build_android_hot_patch.sh   # Android 热更新补丁脚本
├── build_ios_hot_patch.sh       # iOS 热更新补丁脚本
├── update_app_name.sh           # 更新应用名称脚本
└── test_api.sh                  # API 测试脚本
```

## .env 配置文件

项目根目录的 `.env` 文件用于配置环境变量：

```bash
# 环境类型: development / staging / production
ENV=development

# API 地址
API_BASE_URL=http://10.137.203.83:8010
WS_URL=ws://10.137.203.83:8010/ws

# 调试配置
ENABLE_DEBUG_LOG=true
ENABLE_PERFORMANCE_MONITOR=false

# Mock 数据
USE_MOCK_DATA=false
```

### 多环境配置

可以创建多个 `.env` 文件用于不同环境：

```bash
.env           # 默认配置（开发环境）
.env.local     # 本地开发配置（不提交到 git）
.env.prod      # 生产环境配置
.env.staging   # 测试环境配置
```

使用 `--env` 参数指定配置文件：

```bash
./scripts/run.sh --env .env.prod
./scripts/build.sh --env .env.staging apk
```

## 环境配置

项目支持三种环境配置：

| 环境 | 参数值 | API 地址 | 调试日志 |
|------|--------|----------|----------|
| 开发环境 | `development` / `dev` | http://10.137.203.83:8010 | 开启 |
| 测试环境 | `staging` / `stage` | https://staging-api.chatlyme.com | 开启 |
| 生产环境 | `production` / `prod` | https://api.chatlyme.com | 关闭 |

## 新版脚本（推荐）

### run.sh - 统一运行脚本

```bash
# 使用 .env 配置运行
./scripts/run.sh

# 使用指定配置文件
./scripts/run.sh --env .env.prod

# 指定设备运行
./scripts/run.sh iPhone

# 组合使用
./scripts/run.sh --env .env.local "iPhone 16 Pro"
```

### build.sh - 统一构建脚本

```bash
# 使用 .env 配置构建（显示菜单选择）
./scripts/build.sh

# 直接指定构建类型
./scripts/build.sh apk    # 构建 APK
./scripts/build.sh aab    # 构建 AAB
./scripts/build.sh ipa    # 构建 IPA
./scripts/build.sh all    # 构建所有

# 使用指定配置文件
./scripts/build.sh --env .env.prod apk
```

---

## 传统脚本

以下是传统的分离式脚本，仍然可用：

### 开发环境运行

```bash
# 从 frontend 目录执行
./scripts/run_dev.sh

# 指定设备运行
./scripts/run_dev.sh "iPhone 16 Pro"
```

### 生产环境运行

```bash
./scripts/run_prod.sh

# 指定设备运行
./scripts/run_prod.sh "iPhone 16 Pro"
```

### 自定义 API 地址运行

```bash
# 使用默认开发地址
./scripts/run_custom.sh

# 指定自定义 API 地址
./scripts/run_custom.sh http://192.168.1.100:8010

# 指定 API 地址和设备
./scripts/run_custom.sh http://192.168.1.100:8010 "iPhone 16 Pro"
```

## 打包脚本

### Android 打包

```bash
# 生产环境打包（默认）
./scripts/build_android.sh

# 开发环境打包
./scripts/build_android.sh dev

# 测试环境打包
./scripts/build_android.sh staging

# 生产环境打包
./scripts/build_android.sh prod
```

运行后会显示菜单选择：
1. 构建 APK（用于直接安装）
2. 构建 AAB（用于 Google Play 发布）
3. 构建 APK 和 AAB

### iOS IPA 打包

```bash
# 生产环境打包（默认）
./scripts/build_ipa.sh

# 开发环境打包
./scripts/build_ipa.sh dev

# 测试环境打包
./scripts/build_ipa.sh staging
```

输出的 IPA 文件位于 `build/ios/ipa/runner.ipa`，可上传至超级签名平台。

## 直接使用 Flutter 命令

如果不使用脚本，可以直接使用 Flutter 命令并传入环境参数：

```bash
# 开发环境
flutter run --dart-define=ENV=development --dart-define=ENABLE_DEBUG_LOG=true

# 生产环境
flutter run --dart-define=ENV=production

# 自定义 API 地址
flutter run \
    --dart-define=ENV=development \
    --dart-define=API_BASE_URL=http://192.168.1.100:8010 \
    --dart-define=WS_URL=ws://192.168.1.100:8010/ws

# 打包时指定环境
flutter build apk --release --dart-define=ENV=production
flutter build ios --release --no-codesign --dart-define=ENV=production
```

## 可用的 dart-define 参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `ENV` | 环境类型 | `development` |
| `API_BASE_URL` | API 基础地址（覆盖默认值） | 根据环境自动设置 |
| `WS_URL` | WebSocket 地址（覆盖默认值） | 根据环境自动设置 |
| `ENABLE_DEBUG_LOG` | 是否启用调试日志 | 开发/测试环境 `true` |
| `ENABLE_PERFORMANCE_MONITOR` | 是否启用性能监控 | 开发环境 `true` |
| `USE_MOCK_DATA` | 是否使用 Mock 数据 | `false` |

## 其他脚本

### 更新应用名称

从后端 API 获取应用名称并更新配置文件：

```bash
./scripts/update_app_name.sh
```

### 热更新补丁

构建热更新补丁包：

```bash
# Android 热更新补丁
./scripts/build_android_hot_patch.sh

# iOS 热更新补丁
./scripts/build_ios_hot_patch.sh
```

### API 测试

测试 API 连通性：

```bash
./scripts/test_api.sh
```

## 注意事项

1. 所有脚本都会自动切换到 `frontend` 根目录执行，可以从任意位置调用
2. 首次运行前确保已安装 Flutter SDK
3. iOS 打包需要在 macOS 系统上执行
4. 打包脚本会自动执行 `flutter clean` 和 `flutter pub get`
5. 生产环境打包时会自动禁用调试日志
