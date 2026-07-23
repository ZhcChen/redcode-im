# GitHub Actions 构建发布流程

本项目使用 `.github/workflows/release-artifacts.yml` 统一构建首版发布所需的三个模块：

- `app/`：Flutter Android APK/AAB 与 iOS 无签名 IPA
- `desktop/`：Tauri macOS / Windows / Linux 桌面端安装包
- `api/`：Linux `x86_64` 与 `arm64` Docker 镜像包和可执行二进制

## 触发方式

### 标签触发并发布 Release

推送符合 `v*.*.*` 的 tag 会自动构建全部产物并创建或更新 GitHub Release：

```bash
git tag v1.0.0
git push origin v1.0.0
```

### 手动触发

在 GitHub Actions 页面运行 `Build Release Artifacts`：

- `publish_release=false`：只构建并上传 workflow artifacts
- `publish_release=true`：构建完成后发布到 GitHub Release
- `release_tag`：手动发布时必须填写，例如 `v1.0.0`；workflow 会在构建前校验该值

## 构建矩阵

| 模块 | 产物 |
|------|------|
| Flutter app | `redcode-im-app-android-release.apk`、`redcode-im-app-android-release.aab`、`redcode-im-app-ios-nosign.ipa` |
| API | `redcode-im-api-linux-x86_64.binary.tar.gz`、`redcode-im-api-linux-x86_64.docker.tar.gz`、`redcode-im-api-linux-x86_64.sha256`、`redcode-im-api-linux-arm64.binary.tar.gz`、`redcode-im-api-linux-arm64.docker.tar.gz`、`redcode-im-api-linux-arm64.sha256` |
| Desktop | `macOS arm64/x86_64`、`Windows x86_64/arm64`、`Linux x86_64/arm64` 对应 Tauri bundle |

## 注意事项

- Android release 在未配置正式签名时会回退 debug 签名，只用于验收或分发前二次签名。
- iOS 产物是 `--no-codesign` 无签名 IPA，需要后续使用正式证书或签名平台处理。
- API Docker 产物是 `docker save` 导出的单架构镜像包，可通过 `docker load -i <file>` 导入；API 单文件二进制来自 release 镜像，裸机运行需自行准备兼容的 Linux 运行库环境（如 `ca-certificates`、`openssl`、`libpq`、`tzdata`），正式部署优先使用 Docker 镜像包。
- Desktop 的 Linux / Windows arm64 当前会补齐 Tauri sidecar 占位文件；视频缩略图功能在这些平台仍按客户端代码返回“不支持”。
- 重新发布同一个 tag 会先删除该 GitHub Release 的既有 assets，再上传本轮全量产物。
