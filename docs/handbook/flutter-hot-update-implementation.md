# Flutter 前端整包 & 热更新实施方案

> 版本：v1.2  
> 更新时间：2025-11-14  
> 适用范围：`frontend/` Flutter 客户端（Android / iOS）

## 1. 背景与目标

- 后端 / Admin 已具备整包版本与热更新补丁的上传、管理与分发能力；Flutter 客户端仅实现“检测 + 下载”，尚未真正应用补丁。
- 桌面端维持整包更新，热更新只面向移动端；需要保证整包、热更新、官网下载入口的一致性。
- 本方案明确 Flutter 端的自研热更新路线（MVP），覆盖补丁格式、运行时、客户端架构、开发步骤与验收标准。

## 2. 当前能力回顾

| 能力 | 现状 | 模块 |
| --- | --- | --- |
| 整包检测 | ✅ `VersionService.checkLatest`，启动/设置页可触发 | `core/services/version_service.dart` |
| 整包下载 | ✅ 支持 COS 临时 URL 下载并保存在本地 | `VersionService.downloadAndSave` |
| 热更新检测 | ✅ `HotUpdateService.checkLatest`，启动页自动执行 | `core/update/hot_update_service.dart` |
| 热更新下载 | ✅ COS 临时 URL、MD5/SHA 校验、缓存 | 同上 |
| 补丁应用 | 🔄 本迭代实现：自研运行时 + 自定义 AssetBundle | `core/update/` |
| 回滚/上报 | 🔄 MVP 内置本地回滚，后续补齐上报接口 | - |

## 3. 技术路线决策

### 3.1 自研 MVP（本迭代执行）

- **补丁形态**：ZIP 文件，包含 `manifest.json`（描述 `base_version`、`patch_version`、payload）与 `assets/` 覆盖目录（可放置配置/图片/模板等）。后续可在 `payload/` 中扩展 so/AOT。
- **运行时**：客户端解压补丁至 `ApplicationSupport/hot_runtime/patches/<patchVersion>/`，`runtime_state.json` 记录当前激活补丁；自定义 `HotPatchAssetBundle` 在加载资源时优先读取补丁目录，实现热修资源/配置。
- **静默策略**：补丁下载与应用全过程无弹窗；失败仅在设置页显示状态，并触发事件上报以便后台监控。
- **回滚策略**：应用失败或后台停用补丁时，删除 `runtime_state.json` 与补丁目录，恢复默认资源；同时更新本地存储状态。
- **灰度控制**：沿用后端 `rollout_percentage + client_id`，客户端无需新增逻辑。

### 3.2 后续演进

- 逐步扩展到代码级补丁（AOT / `libapp.so` 替换）：目前仅记录需求和风险点（构建工具链、跨 ABI 文件校验、加载时机、回滚策略、平台政策），暂不实现，待 MVP 稳定后评估投入再自研。
- 引入 `/versions/hot-update/report` 记录下载/应用/失败事件，支撑运维监控。

## 4. 客户端架构

```
SplashPage ──▶ UpdateCenter.ensureHotUpdateManager()
                      │
                      ▼
              HotUpdateManager (ChangeNotifier)
              ├─ HotUpdateService  (HTTP: /versions/hot-update, /hot-update/download)
              ├─ HotUpdateStorage (SharedPreferences: installed/downloaded/client_id)
              └─ LocalHotUpdateRuntime (解压/校验/落地/回滚)
                       │
                       ▼
          HotPatchAssetBundle (DefaultAssetBundle wrapper)
```

### 4.1 数据流
1. **检测**：启动和设置页触发 `checkForUpdates()`，请求最新补丁。
2. **下载**：命中补丁后调用 `downloadPatch()`，存储在 `hot_updates/` 并校验 checksum。
3. **应用**：`LocalHotUpdateRuntime.applyPatch()` 解压 ZIP、校验 `manifest`、更新 `runtime_state.json`，返回补丁资源目录。
4. **资源覆盖**：`HotPatchAssetBundle.load(key)` 先查补丁目录 `assets/key`，存在则读取，否则回退到 `rootBundle`。
5. **回滚**：失败或补丁停用时，`rollbackActivePatch()` 删除补丁目录 + state，并通知 UI 恢复，同时记录错误供上报和设置页查看。
6. **整包优先级**：若 `/versions/latest` 返回强制整包，必须弹窗提示且不可关闭；普通整包更新弹窗允许“稍后再说”；热更新失败则静默处理。

### 4.2 状态管理
- `HotUpdateState.stage`：驱动 UI（idle/checking/available/downloading/applying/applied/failed）。
- `HotUpdateDownloadRecord`：记录下载文件路径、大小、base version、checksum。
- `InstalledHotPatchInfo`：记录已应用补丁（patch version + base version + appliedAt）。
- `runtime_state.json`：描述当前激活补丁与 assets 覆盖目录，供 AssetBundle 即时读取。

## 5. 实施步骤

| 步骤 | 内容 | 影响模块 |
| --- | --- | --- |
| 1 | 定义补丁 ZIP 规范（`manifest.json` + `assets/` + 预留 `payload/`） | 构建脚本 / 文档 |
| 2 | 引入 `archive` 包，封装 `HotUpdateRuntime` 接口与 `LocalHotUpdateRuntime` 实现 | `core/update/` |
| 3 | 扩展 `HotUpdateManager`：自动 apply、回滚、管理 `runtime_state`、暴露 `resolvePatchedAsset()` | `core/update/hot_update_manager.dart` |
| 4 | 新增 `HotPatchAssetBundle` 并在 `RedcodeApp` 外层包裹 `DefaultAssetBundle` | `core/update/hot_patch_asset_bundle.dart`, `app.dart` |
| 5 | 启动阶段预热：`main.dart` 在 `runApp` 前初始化 `UpdateCenter`，`SplashPage` 保持检测流程 | `main.dart`, `features/startup/` |
| 6 | UI 提示：设置页展示补丁状态、应用日志、清理按钮，强制补丁时阻断入口 | `features/settings/` |
| 7 | 回滚与日志：下载/应用失败即回滚，打印 DebugLogger，方便排查 | runtime / manager |
| 8 | 后续（下一迭代）补充：事件上报、AOT 扩展 | backend/frontend |

## 6. 补丁结构与运行时要点

### 6.1 manifest 示例
```json
{
  "schema": 1,
  "base_version": "1.0.0",
  "patch_version": "1.0.0-p1",
  "channel": "stable",
  "description": "修复设置页文案 + 更新 Banner 图",
  "payloads": {
    "assets": {
      "root": "assets",
      "files": ["settings/strings.json", "images/banner.jpg"]
    }
  }
}
```

### 6.2 运行时流程
1. **解压**：使用 `archive` 遍历 ZIP，写入 `hot_runtime/patches/<patchVersion>/...`。
2. **校验**：比对 `manifest.base_version == 当前整包版本`、`manifest.patch_version == HotUpdateInfo.patch_version`，并复用下载阶段的 checksum。
3. **落地**：生成/更新 `runtime_state.json`（记录 `patch_version`、`assets_dir`、`applied_at`）。
4. **资产覆盖**：`HotPatchAssetBundle.load(key)` 查找 `assets_dir/key`，命中则返回该文件字节，未命中则调用 `rootBundle.load(key)`。
5. **失败回滚**：任一步失败即删除补丁目录和 `runtime_state.json`，并触发 `HotUpdateManager` 状态转为 `failed`，同时准备上报数据。
6. **扩展准备**：`patches/<patchVersion>/payload/` 预留给未来的 AOT/so 文件替换，只需在 runtime 内追加处理逻辑。

## 7. 验收标准

- ✅ 启动后自动检测整包/热更新，日志中能看到命中 / 未命中结果。
- ✅ 下载后的补丁能够成功解压并被 `HotPatchAssetBundle` 命中，资源覆盖即时生效。
- ✅ 出现异常（下载损坏、manifest 不匹配、应用失败）会自动回滚、静默记录并在设置页提示，可重新下载。
- ✅ 设置页展示当前补丁状态、版本号、下载位置、错误信息及“清除下载包 / 移除补丁”操作。
- ✅ 预留 `payload/`、`runtime_state.json`，后续可直接扩展到代码级补丁且无需推翻现有实现。

## 8. 任务拆解（Frontend backlog）

1. **实现自研运行时 + AssetBundle**（本任务）
2. **补丁/整包打包脚本**：提供 Android/iOS 整包与热补丁打包脚本，产物由开发者手动上传至 Admin。
3. **回滚/清理 UI**：设置页增加“清除下载包”“移除已应用补丁”交互。
4. **整包弹窗**：普通整包弹窗可关闭，强制整包弹窗不可关闭；热补丁失败仅静默上报。
5. **监控上报**（下一步）：新增 `/versions/hot-update/report`，记录下载/应用/失败。
6. **自动化测试**：本阶段可先人工验证，后续再补。

## 9. 打包脚本规范

`frontend/` 中提供 4 个脚本，覆盖 Android / iOS 的整包与热补丁：

| 脚本 | 作用 | 示例 |
| --- | --- | --- |
| `build_android.sh` | 生成 Android 整包（APK/AAB） | `./build_android.sh prod` |
| `build_android_hot_patch.sh` | 生成 Android 热补丁 ZIP（输入基线版本、补丁版本） | `./build_android_hot_patch.sh 1.0.0 1.0.0-p1` |
| `build_ipa.sh` | 生成 iOS 整包（IPA） | `./build_ipa.sh prod` |
| `build_ios_hot_patch.sh` | 生成 iOS 热补丁 ZIP | `./build_ios_hot_patch.sh 1.0.0 1.0.0-p1` |

约定：
- 热补丁脚本自动对比 `assets/`、配置差异，生成 `manifest.json + ZIP` 与 checksum。
- 所有脚本默认使用 `uv run python` 执行辅助工具（如差异分析、签名）。
- 打包完成后由开发者手动上传到 Admin：整包进入“版本管理-整包”，补丁进入“热更新管理”。

## 10. 整包弹窗策略

- **普通整包**：检测到更新时弹窗提示，可选择“立即更新/稍后再说”；若用户跳过，下次启动继续提醒。
- **强制整包**（`mandatory=true`）：弹窗仅提供“立即更新”，无法关闭；若用户拒绝，则提示不可继续使用。
- **热补丁**：始终静默，不弹窗，仅在设置页展示状态并通过上报接口告警。

## 11. 补丁事件上报（规划）

- API：`POST /versions/hot-update/report`，由客户端直接调用，无需登录态。
- 事件类型：`download_success`、`download_failed`、`apply_success`、`apply_failed`、`rollback`。
- 上报字段：`platform`、`channel`、`base_version`、`patch_version`、`client_id`、`message`。
- 触发节点：HotUpdateManager 在下载或应用的 try/catch 中调用 Reporter；失败不弹窗，仅静默上报并在设置页提示。

完成上述步骤后，即可认为 Flutter 端自研热更新 MVP 落地，后续可按需扩展到代码级补丁或引入外部方案。
