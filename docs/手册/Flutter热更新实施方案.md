# Flutter 前端整包 & 热更新实施方案

> 版本：v1.1  
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
- **回滚策略**：应用失败或后台停用补丁时，删除 `runtime_state.json` 与补丁目录，恢复默认资源；同时更新本地存储状态。
- **灰度控制**：沿用后端 `rollout_percentage + client_id`，客户端无需新增逻辑。

### 3.2 后续演进

- 逐步扩展到代码级补丁（AOT / `libapp.so` 替换），或在验证完自研方案后评估 Shorebird 等官方方案。
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
5. **回滚**：失败或补丁停用时，`rollbackActivePatch()` 删除补丁目录 + state，并通知 UI 恢复。
6. **整包优先级**：若 `/versions/latest` 返回强制整包，优先提示整包更新；热更新只针对当前整包版本。

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
| 8 | 后续（下一迭代）补充：上报接口、测试脚本、AOT 扩展 | backend/frontend/test |

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
5. **失败回滚**：任一步失败即删除补丁目录和 `runtime_state.json`，并触发 `HotUpdateManager` 状态转为 `failed`。
6. **扩展准备**：`patches/<patchVersion>/payload/` 预留给未来的 AOT/so 文件替换，只需在 runtime 内追加处理逻辑。

## 7. 验收标准

- ✅ 启动后自动检测整包/热更新，日志中能看到命中 / 未命中结果。
- ✅ 下载后的补丁能够成功解压并被 `HotPatchAssetBundle` 命中，资源覆盖即时生效。
- ✅ 出现异常（下载损坏、manifest 不匹配、应用失败）会自动回滚并提示用户，可重新下载。
- ✅ 设置页展示当前补丁状态、版本号、下载位置、错误信息及“清除补丁”操作。
- ✅ 预留 `payload/`、`runtime_state.json`，后续可直接扩展到代码级补丁且无需推翻现有实现。

## 8. 任务拆解（Frontend backlog）

1. **实现自研运行时 + AssetBundle**（本任务）
2. **补丁打包脚本**：后端或 CI 根据 manifest 产出 ZIP。
3. **回滚/清理 UI**：设置页增加“清除补丁”“查看状态”交互。
4. **强制补丁提示**：当 `mandatory=true` 且应用失败时，引导用户等待或走整包更新。
5. **监控上报**（下一步）：新增 `/versions/hot-update/report`，记录下载/应用/失败。
6. **自动化测试**：编写 Mock Runtime / ZIP 流程用例，确保状态机、解压、资源读取正确。

完成上述步骤后，即可认为 Flutter 端自研热更新 MVP 落地，后续可按需扩展到代码级补丁或引入外部方案。
