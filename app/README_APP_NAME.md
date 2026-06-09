# 动态应用名称配置

本文档介绍如何配置和使用移动端应用的动态应用名功能。

## 功能概述

移动端应用支持从后端API动态获取应用名称，并在手机桌面上显示该名称。这个功能在构建时生效，无法在运行时动态修改。

## 工作原理

1. **构建时获取**: 在应用构建前，脚本会调用后端API获取应用名
2. **配置文件更新**: 自动更新 Android 和 iOS 的应用显示名称配置
3. **安装后生效**: 用户安装应用后，会在桌面上看到动态获取的应用名称

## 配置步骤

### 1. 后端API配置

确保后端提供以下API端点：

```
GET /settings/app-name
```

响应格式：
```json
{
  "app_name": "Your App Name"
}
```

### 2. 构建前准备

运行应用名更新脚本：

```bash
cd app
./update_app_name.sh
```

脚本会：
- 调用后端API获取应用名
- 更新 Android 的 `AndroidManifest.xml`
- 更新 iOS 的 `Info.plist`

### 3. 构建应用

使用现有的构建脚本：

```bash
# Android APK
./build_android.sh

# Android AAB
./build_android.sh  # 选择选项2

# iOS
./build_ipa.sh
```

构建脚本会自动调用应用名更新脚本。

## 环境变量

可以通过环境变量自定义API地址：

```bash
export API_BASE_URL=http://your-api-server:port
./update_app_name.sh
```

## 文件结构

```
app/
├── update_app_name.sh          # 应用名更新脚本
├── build_android.sh            # Android构建脚本（已集成应用名更新）
├── build_ipa.sh               # iOS构建脚本
├── android/app/src/main/AndroidManifest.xml  # Android配置
├── ios/Runner/Info.plist       # iOS配置
└── pubspec.yaml               # Flutter配置
```

## 故障排除

### 脚本无法获取应用名

如果脚本无法连接到服务器，会使用默认名称 "RedCode IM"。

### 构建失败

确保脚本有执行权限：

```bash
chmod +x update_app_name.sh
```

### 手动更新

如果需要手动更新应用名：

```bash
# Android
sed -i 's/android:label="[^"]*"/android:label="新应用名"/' android/app/src/main/AndroidManifest.xml

# iOS
sed -i 's|<string>旧应用名</string>|<string>新应用名</string>|' ios/Runner/Info.plist
```

## 注意事项

1. **构建时生效**: 应用名在构建时确定，安装后无法修改
2. **平台差异**: Android和iOS的配置方式不同
3. **缓存问题**: 修改应用名后需要重新安装应用
4. **默认值**: API失败时使用 "RedCode IM" 作为默认名称

## 相关代码

- **API调用**: `lib/core/services/settings_service.dart`
- **UI显示**: `lib/features/settings/settings_page.dart`
- **构建脚本**: `build_android.sh`, `build_ipa.sh`
- **更新脚本**: `update_app_name.sh`
