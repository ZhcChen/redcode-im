# Flutter 前端整包 & 热更新实施方案

> 版本：v1.0  
> 更新时间：2025-11-14  
> 适用范围：`frontend/` Flutter 客户端（Android / iOS）

## 1. 背景与目标

- 后端与 Admin 已具备整包版本与热更新补丁的上传、管理、分发能力，但 Flutter 端仅实现“检测 + 下载”，尚未真正落地补丁应用。
- 桌面端采用整包更新，热更新仅面向移动端；需要确保整包、热更新、官网下载按钮与 Admin 的联动一致。
- 本方案指导 Flutter 客户端如何串联整包更新与热更新，覆盖从检测、下载、应用到监控回滚的全流程。

## 2. 当前能力回顾

| 能力 | 现状 | 模块 |
| --- | --- | --- |
| 整包检测 | ✅ 已实现 `VersionService.checkLatest`，设置页可手动触发 | `core/services/version_service.dart` |
| 整包下载 | ✅ 已实现 COS 临时 URL 下载与本地保存 | 同上 |
| 热更新检测 | ✅ 新增 `HotUpdateService.checkLatest`、启动页自动触发 | `core/update/` |
| 热更新下载 | ✅ 支持 COS 临时 URL 下载、MD5/SHA1/SHA256 校验、缓存 | 同上 |
| 补丁应用 | 🔴 未实现，需要本方案明确落地方式 | - |
| 回滚/上报 | 🔴 未实现，需要补丁运行时提供 API | - |

## 3. 热更新技术路线决策

1. **补丁形态**  
   - 建议以 **Flutter/Dart 级别 Bundle** 或 **Shorebird 补丁** 为主，禁止改动原生层（权限、插件等仍需整包更新）。  
   - 补丁文件命名：`patch_<platform>_<channel>_<patchVersion>.bin`（已在客户端下载阶段实现）。

2. **运行时选型**  
   - **首选：Shorebird**（官方 Flutter 热更新方案）：提供 `shorebird apply` API，可直接加载补丁，支持回滚。  
   - **备选：自研 Asset 差分**：需要在 App 启动时自行解压+替换 `libapp.so` 或 Dart AOT，风险较高。
   - 本方案以 Shorebird 为例描述落地步骤，自研实现可按同样流程替换“应用补丁”步骤。

3. **灰度策略**  
   - 后端 `hot_updates` 已提供 `rollout_percentage`，客户端需携带 `client_id`（已由 `HotUpdateStorage` 生成持久化 UUID）以保证命中结果稳定。

## 4. 客户端架构设计

```
SplashPage ──▶ UpdateCenter.ensureHotUpdateManager()
                      │
                      ▼
              HotUpdateManager (ChangeNotifier)
              ├─ HotUpdateService  → HTTP: /versions/hot-update, /hot-update/download
              ├─ HotUpdateStorage → SharedPreferences（记录 installed / downloaded / client_id）
              └─ ShorebirdRuntimeAdapter（待实现）
```

### 4.1 数据流
1. **检测**：`HotUpdateManager.checkForUpdates()` 在启动及设置页触发，获取补丁信息。
2. **下载**：`downloadPatch()` 使用 COS 临时 URL 拉取补丁，校验摘要后落地到 `ApplicationSupportDirectory/hot_updates/`。
3. **应用**（待实现）：调用 `ShorebirdFlutterUpdater.applyPatch(record.filePath)`，成功后写入 `InstalledHotPatchInfo`，失败则回滚并记录错误。
4. **整包优先级**：若 `/versions/latest` 返回强制整包，必须先提示整包更新；热更新只在当前整包版本匹配时启用。

### 4.2 关键状态
- `HotUpdateState.stage`：idle/checking/available/downloading/downloaded/applying/applied/failed，驱动 UI。
- `InstalledHotPatchInfo`：记录当前已生效的补丁（version + base version + appliedAt）。
- `HotUpdateDownloadRecord`：保存下载文件路径、checksum，用于重复利用与调试。

## 5. 实施步骤

| 步骤 | 说明 | 影响模块 |
| --- | --- | --- |
| 1. 引入运行时依赖 | 以 Shorebird 为例，需要集成官方 SDK，配置 Android/iOS 工程 | `android/`, `ios/`, `pubspec.yaml` |
| 2. 封装 `HotUpdateRuntimeAdapter` | 负责 `applyPatch`, `rollback`, `getCurrentPatchVersion` 等操作 | `core/update/` |
| 3. 扩展 `HotUpdateManager` | - 下载成功后自动调用 `runtime.applyPatch`<br>- `markPatchApplied` 在运行时回调成功时触发<br>- 提供 `rollbackPatch(reason)` API | 同上 |
| 4. 启动阶段应用补丁 | `SplashPage` 启动后若检测到 `installedPatch` 与 `runtime` 状态不一致，需要重新 apply 或清理 | `features/startup/` |
| 5. UI & 提示 | 设置页在补丁可用/失败时给出明确提示；补丁强制时应弹窗阻止进入主界面 | `features/settings/` |
| 6. 监控与上报 | 追加简单的 API：`POST /versions/hot-update/report`，记录补丁下载/应用/失败原因 | backend/frontend |
| 7. 自动化测试 | - 单元测试：校验状态机、存储序列化<br>- 集成测试：Mock HTTP + Fake Runtime，验证流程 | `test/` |

## 6. 运行时集成要点（以 Shorebird 为例）

1. **依赖**：在 `pubspec.yaml` 加入 `shorebird_code_push`，并按官方文档配置 Platform Channel。
2. **API**：
   ```dart
   final updater = ShorebirdCodePush();
   final status = await updater.installUpdateIfAvailable();
   ```
   自定义 `HotUpdateRuntimeAdapter`：
   ```dart
   abstract class HotUpdateRuntimeAdapter {
     Future<bool> applyPatch(String filePath, String patchVersion);
     Future<void> rollback(String reason);
     Future<String?> currentPatchVersion();
   }
   ```
3. **强制策略**：若补丁 `mandatory=true`，应用失败时必须提示用户“请重新启动/等待修复”，并可降级到整包更新。
4. **安全**：下载后校验 checksum + 可选签名，防止补丁被篡改；运行时应校验 patchVersion 与 baseVersion 匹配。

## 7. 验收标准

- ✅ 启动时自动检查整包 + 热更新，日志中可看到 patch 命中结果。
- ✅ 设置页显示当前补丁状态，可手动检查、重新下载、打开文件定位。
- ✅ 补丁下载后可调用运行时成功加载，并能在热更新停用时正确回滚。
- ✅ 强制补丁或整包时，界面必须阻断进入主界面，给出明确指引。
- ✅ 提供最少 3 条集成测试：  
  1. 命中补丁 → 下载 → 成功应用；  
  2. 下载失败 → 重试；  
  3. 补丁停用 → 客户端回滚。

## 8. 任务拆解（Frontend backlog）

1. **runtime 集成**（Android/iOS 双端）  
   - 选择 Shorebird 或自研方案，完成工程级配置。
2. **`HotUpdateRuntimeAdapter` 实现**  
   - 统一封装运行时 API，方便未来切换实现。
3. **`HotUpdateManager` 扩展**  
   - 接管 apply/rollback、错误状态、强制提醒。
4. **UI 增强**  
   - 设置页展示已安装补丁信息；强制补丁的弹窗。
5. **监控上报**  
   - 定义 `/versions/hot-update/report`，上报下载/应用/失败日志。
6. **自动化测试**  
   - Flutter 单测 + 集成测试覆盖所有状态。

完成以上工作后，即可关闭“Flutter 热更新实施”主任务，并将桌面端整包更新作为独立事项推进。
