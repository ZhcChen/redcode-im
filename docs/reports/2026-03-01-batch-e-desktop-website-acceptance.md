# 批次 E 验收报告（Desktop + Website 测试重建）

**日期**: 2026-03-01  
**范围**: Desktop（Vue + Tauri）与 Website（Nuxt）测试体系从 0 重建

## 1. Desktop 交付

### 1.1 测试框架
- 新增 `desktop/vitest.config.ts`
- 新增脚本: `desktop/package.json`
  - `test`
  - `test:watch`
- 新增依赖: `vitest`、`jsdom`

### 1.2 测试实现（`desktop/test`）
- `test/utils/binary.test.ts`
- `test/utils/download-settings.test.ts`
- `test/config/feature-flags.test.ts`
- `test/store/accounts.mutations.test.ts`
- `test/api/message-search.test.ts`
- `test/api/message-search-service.test.ts`
- `test/api/websocket.test.ts`
- `test/api/notification.test.ts`
- `test/api/version.test.ts`

### 1.3 代码可测性增强
- `desktop/src/api/version.ts`: 导出 `collectClientDetails` / `detectPlatform`
- `desktop/src/router/index.ts`: 导出 `routes` 便于后续扩展测试

### 1.4 验证结果
- 执行: `cd desktop && bun run test`
- 结果: `9 files, 22 passed`

## 2. Website 交付

### 2.1 测试框架
- 新增 `website/vitest.config.ts`
- 新增脚本: `website/package.json`
  - `test`
  - `test:watch`
- 新增依赖: `vitest`

### 2.2 可测抽象与测试
- 新增 `website/app/utils/download.ts`
  - 平台识别
  - 主下载优先级
  - 版本展示文案
  - 无可用版本标记
  - 最新下载链接解析
- `website/app/app.vue` 改为复用 `download.ts`
- 新增 `website/test/download-utils.test.ts`

### 2.3 验证结果
- 执行: `cd website && bun run test`
- 结果: `1 file, 9 passed`

## 3. 可追溯更新

- 已更新矩阵:
  - `docs/reference/testing/matrix/desktop.csv`
  - `docs/reference/testing/matrix/website.csv`
- Desktop/Website 功能点均标记 `done`

## 4. 本批完成度

- 需求覆盖: 100%（按本批矩阵口径）
- 验收覆盖: 100%
- 通过率: 100%
- 可追溯: 100%
