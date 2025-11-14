# AGENTS.md - AI 代理全局规则

> 本文件为 RedCode IM 项目的 AI 代理工作规范，所有 AI 助手在处理项目任务时必须严格遵守以下规则。

## 一、项目概述

RedCode IM 是一个现代化的即时通讯系统，采用 Rust 后端 + 多平台前端（Vue/Tauri 桌面端、Flutter 移动端、Nuxt 官网、Vue 管理后台）的架构。项目代码量约 50,000+ 行，已完成核心功能开发，处于功能完善和优化阶段。

**核心文档入口**：
- 📚 项目文档索引：`docs/文档索引.md`
- 📋 代理指南：`docs/手册/代理指南.md`
- 📊 项目现状评估：`docs/报告/项目现状评估报告_2025-11-08.md`
- 🗃️ 数据库迁移指南：`backend/sql/README.md`（涵盖全量初始化脚本 `sql/all.sql` 及增量迁移规则）

## 二、强制规则（MUST）

### 2.1 代码管理
1. **立即提交原则**：每次完成一个功能模块或修复一个 bug 后，必须立即执行 `git commit` 并 `git push`，禁止在本地累积多次未提交的改动。

2. **Commit 规范**：必须遵循 Conventional Commits 格式
   ```
   <type>(<scope>): <subject>

   类型（type）：
   - feat: 新功能
   - fix: Bug 修复
   - docs: 文档变更
   - style: 代码格式（不影响功能）
   - refactor: 重构
   - test: 测试相关
   - chore: 构建/工具变更

   示例：
   feat(desktop-chat): 实现消息撤回功能
   fix(backend-auth): 修复 token 过期判断逻辑
   docs(api): 更新用户管理接口文档
   ```

3. **文件操作**：
   - 禁止直接修改已有的数据库迁移文件（`backend/sql` 目录）
   - 新增数据库变更必须创建时间戳格式的新文件：`YYYYMMDDHHMMSS_desc.sql`
   - 禁止创建不必要的文件，优先编辑现有文件

### 2.2 代码规范
1. **数据库字段**：业务状态字段统一使用整数类型，禁止使用 PostgreSQL 枚举
2. **代码格式**：
   - Rust: 执行 `cargo fmt --all` + `cargo clippy`
   - TypeScript/Vue: 遵循 Prettier 配置，两空格缩进
   - Dart/Flutter: 执行 `dart format .` + `dart analyze`

3. **命名规范**：
   - Rust: `snake_case` 模块名，`PascalCase` 类型名
   - TypeScript: `camelCase` 变量/函数，`PascalCase` 组件/类
   - Flutter: `snake_case.dart` 文件名，`PascalCase` 组件名

### 2.3 测试要求
1. 修改代码后必须运行相应测试：
   - 后端：`cd backend && cargo test`
   - 前端：`cd frontend && flutter test`
   - 管理后台：`cd admin && pnpm type:check`
   - 桌面端：`cd desktop && bun run type-check`

2. 重要功能变更需补充集成测试脚本

### 2.4 安全规范
1. **禁止**提交敏感信息到代码仓库（密钥、密码、.env 文件）
2. 定期轮换 JWT 密钥
3. 上传功能需验证文件类型和大小限制
4. 所有用户输入必须进行校验和转义

## 三、工作流程（SHOULD）

### 3.1 接收任务后
1. **理解需求**：仔细阅读任务描述，明确目标和验收标准
2. **查阅文档**：
   - 查看 `docs/文档索引.md` 了解项目整体情况
   - 查看 `docs/手册/代理指南.md` 了解具体操作规范
   - 查看相关 API 文档（`docs/api/`）了解接口细节
3. **规划任务**：将大任务拆解为可执行的小步骤
4. **评估影响**：判断改动会影响哪些模块，是否需要同步修改前后端

### 3.2 开发过程中
1. **代码定位**：
   - 后端代码：`backend/backend/src/`
   - 桌面端：`desktop/src/`
   - 移动端：`frontend/lib/`
   - 管理后台：`admin/src/`
   - 官网：`website/app/`

2. **日志记录**：
   - 桌面端关键操作必须写入 `app_data_dir/logs/app.log`
   - 后端使用统一的日志框架记录重要事件

3. **增量开发**：
   - 一次只改动一个功能点
   - 改动后立即测试
   - 测试通过后立即提交

### 3.3 完成任务后
1. **自检清单**：
   - [ ] 代码格式化已执行
   - [ ] 单元测试已通过
   - [ ] 功能已手动验证
   - [ ] 日志输出清晰合理
   - [ ] 无安全隐患
   - [ ] 文档已更新（如需要）

2. **提交代码**：
   ```bash
   git add .
   git commit -m "feat(module): 具体功能描述"
   git push origin main
   ```

3. **更新文档**：
   - 新增 API 需更新 `docs/api/` 相关文档
   - 重要功能变更需更新项目文档索引
   - 重大架构调整需更新评估报告

### 桌面端发布约定

1. macOS 安装包版本号取自 `desktop/src-tauri/tauri.conf.json`（需与 `desktop/package.json` 保持一致，当前版本为 `1.0.0`），否则构建产物与应用内显示会不一致；更新桌面端版本号时，同时修改以下文件保持一致：
   - `desktop/package.json`
   - `desktop/src-tauri/tauri.conf.json`
   - `desktop/src/api/config.ts` 中的 `DEFAULT_APP_VERSION`
   - `desktop/scripts/build-macos.sh`、`desktop/scripts/build-linux.sh` 中的 `VERSION` 默认值
2. 更新渠道由打包时注入的 `VITE_APP_CHANNEL` 决定。macOS 必须区分 `stable-macos-intel` / `stable-macos-arm64` 等渠道，客户端运行时仅读取该值，不再根据 `process.arch` 推断。
3. 推荐执行 `desktop/scripts/build-macos.sh arm64|intel [channel]`，脚本会自动设置 `VITE_APP_CHANNEL/VITE_APP_VERSION/VITE_APP_BUILD` 并输出 `dist/releases/macos/<channel>/<product>-<channel>-<version>.dmg`。若手动构建，必须在命令前加 `VITE_APP_CHANNEL=... bun run tauri build --target ...` 来保证渠道正确。

## 四、常见场景处理

### 4.1 修复 Bug
1. 复现问题，记录复现步骤
2. 定位问题代码（查看日志、调试）
3. 编写或运行测试用例验证问题
4. 修复代码
5. 验证修复效果
6. 提交代码：`fix(module): 修复具体问题`

### 4.2 新增功能
1. 查阅文档了解现有架构
2. 设计功能实现方案
3. 评估是否需要数据库变更
4. 后端先行（API 接口）
5. 前端对接
6. 集成测试
7. 提交代码：`feat(module): 新增具体功能`

### 4.3 数据库变更
1. **禁止直接修改已有 SQL 文件**
2. 创建新的迁移文件：`backend/sql/20251113120000_add_xxx_field.sql`
3. 编写 UP 和 DOWN 脚本
4. 在开发环境验证
5. 更新数据模型代码
6. 提交代码：`feat(database): 新增 xxx 表/字段`

### 4.4 文档更新
1. 修改对应的 Markdown 文档
2. 确保文档结构清晰、内容准确
3. 更新文档索引（如需要）
4. 提交代码：`docs(topic): 更新具体文档`

## 五、禁止事项（MUST NOT）

1. ❌ **禁止**跳过测试直接提交代码
2. ❌ **禁止**修改已有的数据库迁移文件
3. ❌ **禁止**使用 PostgreSQL 枚举类型
4. ❌ **禁止**提交 `.env` 文件
5. ❌ **禁止**在代码中硬编码敏感信息
6. ❌ **禁止**创建不规范的 commit message
7. ❌ **禁止**累积多次改动后再一起提交
8. ❌ **禁止**在未理解代码逻辑的情况下进行重构
9. ❌ **禁止**破坏现有的工作功能
10. ❌ **禁止**忽略 clippy/lint 警告

## 六、优先级原则

### 高优先级（立即处理）
- 🔴 影响核心功能的 Bug
- 🔴 安全漏洞
- 🔴 数据一致性问题
- 🔴 WebSocket 连接稳定性问题

### 中优先级（计划处理）
- 🟠 功能完善和增强
- 🟠 性能优化
- 🟠 用户体验改进
- 🟠 代码重构

### 低优先级（择期处理）
- 🟡 界面美化
- 🟡 辅助功能
- 🟡 文档完善
- 🟡 测试覆盖率提升

## 七、技术栈速查

| 模块 | 语言/框架 | 主要工具 | 测试命令 |
|------|-----------|----------|----------|
| 后端 | Rust + Axum 0.8 | Tokio, SQLx 0.8, Redis | `cargo test` |
| 桌面端 | TypeScript + Vue 3 + Tauri 2 | Vite, Vuex, Bun | `bun run type-check` |
| 移动端 | Dart + Flutter 3.9+ | - | `flutter test` |
| 管理后台 | TypeScript + Vue 3 | Arco Design, Pinia | `pnpm type:check` |
| 官网 | Nuxt 3 | TailwindCSS | - |

## 八、资源链接

- 📖 [项目文档索引](docs/文档索引.md)
- 🔧 [API 概览](docs/api/API概览.md)
- 📋 [待完成任务清单](docs/报告/任务清单.md)
- 🎯 [桌面端剩余工作](docs/桌面端/桌面端剩余工作.md)
- 🔒 [安全说明](docs/安全/安全说明.md)
- 📁 [文件上传排障](docs/文件上传/文件上传排障.md)

## 九、疑问处理

遇到不确定的情况时：
1. **查阅文档**：先在 `docs/` 目录中搜索相关文档
2. **查看示例**：参考现有代码的实现方式
3. **询问确认**：向用户确认需求或设计决策
4. **记录决策**：重要的技术决策需更新文档

## 十、持续改进

1. 发现文档不准确时，立即更新文档
2. 发现流程不合理时，提出改进建议
3. 发现新的最佳实践时，补充到本文档
4. 定期回顾项目进展，更新任务清单

---

**文档版本**：v1.0
**最后更新**：2025-11-13
**维护者**：RedCode IM Team

**注意**：本文档是活文档，会随着项目发展持续更新。所有 AI 代理必须定期查看本文档，确保遵循最新规范。
