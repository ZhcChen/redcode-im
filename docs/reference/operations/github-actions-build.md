# GitHub Actions 构建发布流程

本项目使用 `.github/workflows/release-artifacts.yml` 统一构建首版发布所需的三个模块：

- `android-app/`：Android Release APK candidate（Kotlin/Compose，JDK 21 + Gradle test/lint/assembleRelease）
- `desktop/`：Tauri macOS / Windows / Linux 桌面端安装包
- `api/`：Linux `x86_64` 与 `arm64` Docker 镜像包和可执行二进制

## 触发方式

### 标签触发候选构建

推送符合 `v*.*.*` 的 tag 只构建候选产物，不执行发布：

```bash
git tag v1.0.0
git push origin v1.0.0
```

### 手动触发

在 GitHub Actions 页面运行 `Build Release Artifacts`：

- `publish_release=false`：只构建并上传 workflow artifacts
- `publish_release=true`：只能从 `main` 手工触发，构建完成后发布到 GitHub Release
- `release_tag`：正式发布时必须填写、预先存在并精确指向当前候选 commit

## 构建矩阵

| 模块 | 产物 |
|------|------|
| Android app | `android-app-release` artifact；验收 run 为 unsigned release candidate，正式发布为 release-signed APK |
| API | `redcode-im-api-linux-x86_64.binary.tar.gz`、`redcode-im-api-linux-x86_64.docker.tar.gz`、`redcode-im-api-linux-x86_64.sha256`、`redcode-im-api-linux-arm64.binary.tar.gz`、`redcode-im-api-linux-arm64.docker.tar.gz`、`redcode-im-api-linux-arm64.sha256` |
| Desktop | `macOS arm64/x86_64`、`Windows x86_64/arm64`、`Linux x86_64/arm64` 对应 Tauri bundle |

H5 archive、Android APK candidate 与每个架构的 API release 文件都通过 GitHub OIDC
生成 build provenance，attestation subject 绑定当前 workflow candidate SHA 和实际文件摘要。

## 注意事项

- Android 正式发布要求 repository secrets
  `ANDROID_SIGNING_KEYSTORE_BASE64`、`ANDROID_SIGNING_STORE_PASSWORD`、
  `ANDROID_SIGNING_KEY_ALIAS`、`ANDROID_SIGNING_KEY_PASSWORD` 四项完整；任一缺失时
  fail closed。`publish_release=false` 始终产出 unsigned release candidate，不使用发布密钥。
- iOS `ios-app-check` 已按 `if: false` 预留（macOS runner 与签名配置待原生发布专项
  补齐），恢复后产出无签名 Simulator/真机构建产物。
- API Docker 产物是 `docker save` 导出的单架构镜像包，可通过 `docker load -i <file>` 导入；API 单文件二进制来自 release 镜像，裸机运行需自行准备兼容的 Linux 运行库环境（如 `ca-certificates`、`openssl`、`libpq`、`tzdata`），正式部署优先使用 Docker 镜像包。
- API release Dockerfile 的 builder/runtime base image 均固定 manifest digest，Cargo 构建使用
  `--locked`；更新基础镜像必须显式更新 digest 并重新执行供应链与 release workflow 门禁。
- Desktop 的 Linux / Windows arm64 当前会补齐 Tauri sidecar 占位文件；视频缩略图功能在这些平台仍按客户端代码返回“不支持”。
- 重新发布同一个 tag 会先删除该 GitHub Release 的既有 assets，再上传本轮全量产物。
