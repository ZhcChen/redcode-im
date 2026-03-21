# Frontend/Desktop/Website 跨模块测试扩展设计

**日期**: 2026-03-05
**范围**: `frontend`、`desktop`、`website`

## 1. 目标

1. 在已完成基础重构的前提下，继续补齐三模块高风险测试空白。
2. 保持“单元 -> 集成 -> 真机/端到端”分层，优先覆盖错误分支与回退逻辑。
3. 将新增链路同步到测试矩阵与回归验收文档，确保可追溯。

## 2. 模块策略

### 2.1 Frontend（Flutter）
- 重点补“设置与配置服务”测试：`SettingsService` 的成功/失败与数据格式异常分支。
- 与已补的 `TokenStorage/AppConfigService/VersionService` 形成“启动-鉴权-配置-更新”核心闭环。

### 2.2 Desktop（Vue + Tauri）
- 补齐 `accounts` actions 的业务逻辑分支（未读同步、页面状态/路由状态保存策略、重排校验）。
- 补齐 `cache` 的容错（localStorage 损坏恢复、Tauri invoke 失败回退）。
- 补齐 `message-search` 错误分支与时间戳兜底。
- 补齐 `message` API 的映射与发送异常分支。

### 2.3 Website（Nuxt）
- 继续深挖 `download` 工具函数边界：商店链接缺失、安装包可用判定、payload fallback、平台识别边界。
- 保持不引入额外测试框架，优先增强现有 `download-utils` 单测覆盖。

## 3. 验收口径

1. 三模块新增测试全部通过。
2. 原有测试全量回归通过（`flutter test`、`bun run test`）。
3. 测试矩阵新增条目与测试文件一一对应。
4. 回归报告记录新增链路、命令与结果。
