# 版本联动方案（整包 + 热更新）

> 适用于 RedCode IM 当前多端架构：Flutter 移动端（Android/iOS）、Tauri 桌面端（Windows/macOS/Linux）、Admin 版本管理后台以及 Website 官网。

## 1. 平台与更新方式

| 模块 | 技术栈 | 更新方式 |
| --- | --- | --- |
| frontend（Flutter） | Android / iOS | **整包更新**（App Store/TestFlight、APK/应用商店）<br>**热更新**（仅 Flutter 层；绑定基线整包版本或范围） |
| desktop（Tauri） | Windows / macOS / Linux | **整包更新**（下载安装包，客户端或官网提示） |
| admin（Vue） | 版本管理后台 | 管理整包版本、上传安装包、维护热更新补丁（Flutter 专用） |
| website（Nuxt） | 官网首页下载按钮 | 调用后端「无 Token 的临时下载链接」接口，获取整包下载地址（腾讯 COS 私有读 + 临时签名） |

## 2. 整包更新流程

1. **Admin 录入整包版本**：平台、版本号、构建号、渠道、下载 Key / URL、强制标记、发布时间。
2. **官网下载按钮**：调用后端开放接口（无需 Token）获取最新整包的临时下载地址（基于 COS 临时签名），赋给按钮（Android 直链 APK，iOS 跳 App Store/TestFlight）。
3. **Flutter / Tauri 客户端**：启动时调用 `/versions/latest?platform=xxx&channel=stable&current_version=1.0.0`，若返回 `has_update && mandatory`，则强制整包升级（iOS 只能跳 App Store，Android 可内置下载流程），否则提示或忽略。
4. **桌面端**：保持整包更新策略即可，暂不做热更新。

## 3. 热更新流程（Flutter 移动端）

1. **后台数据结构**
   - 新建 `hot_updates` 表（或扩展版本表），字段包含：`platform`、`app_version_id`（或版本范围）、`patch_version`、`download_url`、`checksum`、`rollout_percentage`、`mandatory`、`description`、`is_active`、`released_at` 等。
   - 每个 patch 必须绑定某个基线整包版本（或范围），以确保补丁内容与整包一致。

2. **Admin 功能**
   - 新增“热更新管理”页面：列表展示 patch，支持新增/编辑/启用/停用/回滚。
   - 上传 patch 包后生成下载 Key / URL（同 COS 私有读），并设置灰度比例、渠道、强制标记、描述。
   - 提供回滚操作，一旦 patch 有问题可迅速停用。

3. **客户端逻辑**
   - 启动时先检查整包更新；若无强制整包，再调用 `/versions/hot-update` 查询 patch。
   - 服务端根据灰度/渠道决定是否下发 patch；客户端若命中则下载→校验→应用（取决于热更新方案），并记录当前 `patch_version`。
   - 失败时自动回滚并可上报；如热更新已停用，客户端下次启动需恢复到基线版本。
   - 热更新只能修改 Flutter/Dart 逻辑或资源，涉及原生插件、权限、Gradle/Info.plist 等必须重新发整包。

4. **回滚/监控**
   - 热更新记录 `is_active`、`rollback_token` 等信息；后台停用后客户端自动回退。
   - 建议追加客户端上报接口记录 patch 应用成功/失败状态，便于监控。

## 4. 官网整包下载接口

- 提供无需 Token 的公开 API，根据平台/渠道返回最新整包的 COS 临时下载地址。
- 官网首页已有下载按钮，直接调用该接口即可。
- 如需展示版本日志，可复用整包的 `release_notes` 字段。

## 5. 开发任务列表

### 后端（backend）
1. 创建 `hot_updates` 表（迁移）并与 `app_versions` 建立关联。
2. 实现热更新管理 API（新增/编辑/启用/停用/回滚/删除），上传补丁生成下载 Key / URL。
3. 实现 `GET /versions/hot-update` 接口（支持灰度策略）。
4. （可选）实现客户端上报接口记录 patch 应用/失败/回滚日志。
5. 提供官网使用的整包下载接口（返回 COS 临时签名 URL，公开访问）。

### Admin 前端
1. 保持整包管理页面：平台切换、固定渠道列表、下载 Key 只读。
2. 新增“热更新管理”界面（列表 + 表单 + 上传 + 灰度/回滚）。表单需提示 patch 必须绑定整包。
3. 若官网管理需要，可展示整包下载链接或版本列表。

### Flutter 客户端
1. 引入热更新管理器：  
   - 检查整包更新 → 请求热更新 → 下载/校验/应用 patch。  
   - 保存当前 `patch_version`，失败时回滚并可提示用户整包升级。  
   - 选择合适热更新方案（如下发 Dart bundle / assets diff / 第三方 OTA SDK）。
2. UI 提示：正常情况下热更新无感；若 patch 强制、失败或需整包升级，需提示用户。

### Desktop 客户端
1. 继续沿用整包更新（提示用户下载新版本），暂不支持热更新。

### Website
1. 调用整包下载接口，为 Android/iOS 下载按钮赋 URL。
2. 可选：展示最新整包版本信息或发布日志。

### 测试与文档
1. 后端 API 单元测试；Admin 表单校验。
2. 集成测试：上传 patch → 客户端灰度命中 → 回滚流程。
3. 更新 AGENTS.md / 文档索引，明确整包与热更新策略、官网接口入口。

---

此方案确立后，优先完成后端数据库与 API，再接入 Admin UI，最后对接 Flutter 客户端即可。桌面端保持整包更新即可，官网下载按钮直接调用开放的临时下载接口。
