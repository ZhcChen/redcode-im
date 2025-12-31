# Desktop 客户端开发参考

> **说明**：本文档保留桌面端开发过程中的关键技术决策与实现方案，供后续维护参考。
> 任务追踪已迁移至 `docs/reports/task-list.md`。

---

## 版本更新策略

- 桌面端仅支持整包更新，不参与热补丁。
- **启动检查**：应用启动后自动调用 `/versions/latest?platform=<windows|macos|linux>`；若发现新版本，弹窗提示。
- **普通更新**：弹窗提供"立即更新 / 稍后提醒"，用户可暂时跳过，系统会在下次启动继续提示。
- **强制更新**：当 `mandatory=true` 时，弹窗不可关闭且仅提供"立即更新"，用户需下载并安装新版本方可继续使用。
- **设置页入口**：在"设置 / 关于"中提供"检查更新"按钮，复用同一弹窗逻辑，供用户手动触发。
- **GUI 更新器**：点击"立即更新"后，主应用启动独立的GUI更新器程序，提供友好的安装界面，避免用户看到终端窗口。
- **静默安装**：更新器在后台静默执行安装程序，自动请求管理员权限（Windows），完成后自动退出。
- **跨平台支持**：
  - **Windows**: PowerShell静默启动安装程序，支持UAC权限提示
  - **macOS**: 直接启动dmg安装程序
  - **Linux**: 支持AppImage安装（预留扩展）
- **渠道命名**：macOS 需根据芯片架构区分渠道。打包阶段通过 `VITE_APP_CHANNEL` 注入 `stable-macos-intel` 或 `stable-macos-arm64`，客户端直接读取该值，不再根据 `process.arch` 推断，确保即便在 arm64 机器安装 Intel 包也会继续使用正确渠道。
- **增量构建优化**：构建脚本智能检测是否需要重新编译updater二进制，只在源码变更时重新编译。
- **本地构建脚本**：支持在相应平台上本地构建。示例：
  - macOS: `cd desktop && ./scripts/build-macos.sh arm64 stable-macos-arm64`
  - Linux: `cd desktop && ./scripts/build-linux.sh stable-linux`
  - Windows: 在Windows机器上运行 `./scripts/build-windows.sh stable-windows`（不支持从macOS交叉编译）

---

## 视频缩略图生成方案

> 记录桌面端视频消息首帧缩略图的技术实现。

### 实现概述

- **ffmpeg-sidecar**：Rust 侧通过 `generate_video_thumbnail` 命令调用 ffmpeg 截取首帧
- **参数规范**：`-vf scale=320:-1 -vcodec mjpeg -q:v 2`（宽度固定 320px，高度按比例缩放）
- **上传链路**：继续沿用 COS 直传签名，为视频和缩略图分别请求签名后上传

### 已完成功能

- 在桌面端上传视频流程中，增加"File -> 本地视频路径"的落盘步骤（Tauri FS + `appDataDir()/videos`）
- 基于本地视频路径调用 `generate_video_thumbnail` 生成首帧 JPEG
- 上传首帧 JPEG 并拿到缩略图对象 Key
- 在发送消息的 `parts` 中为视频分片补齐 `thumbnailKey`

---

**文档版本**: v2.0
**更新时间**: 2025-12-31
**说明**: 精简自历史任务文档，保留关键技术决策
