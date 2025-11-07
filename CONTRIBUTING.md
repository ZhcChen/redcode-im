# 贡献指南

首先，非常感谢您对 RedCode IM 项目的兴趣！我们欢迎所有形式的贡献，无论是 Bug 报告、功能建议、代码贡献还是文档改进。

## 如何贡献

### 报告 Bug

如果您发现了 Bug，请创建一个 [GitHub Issue](https://github.com/redcode-im/redcode-im/issues) 并包含以下信息：

1. **Bug 描述**: 简洁清楚地描述 Bug
2. **复现步骤**: 详细的复现步骤
3. **预期行为**: 您期望发生的事情
4. **实际行为**: 实际发生的事情
5. **环境信息**: 操作系统、浏览器、版本号等
6. **错误日志**: 如果有相关的错误日志

### 提议新功能

对于新功能建议，请创建一个 [GitHub Discussion](https://github.com/redcode-im/redcode-im/discussions) 并包含：

1. **功能描述**: 清晰描述您希望的功能
2. **使用场景**: 这个功能解决什么问题
3. **可能的实现方案**: 如果您有想法，请分享

## 开发环境设置

### 前置要求

- Rust 1.75+
- Node.js 18+
- PostgreSQL 15+
- Redis 7+

### 设置开发环境

```bash
# 克隆仓库
git clone https://github.com/redcode-im/redcode-im.git
cd redcode-im

# 设置后端
cd backend
cp .env.example .env
# 编辑 .env 文件，配置数据库和 Redis
cargo install
cargo run

# 在新终端中设置前端
cd desktop
npm install
npm run tauri dev
```

## 代码规范

### Rust (后端)

1. **格式化**: 使用 `cargo fmt` 格式化代码
2. **代码检查**: 使用 `cargo clippy` 检查代码
3. **测试**: 确保所有测试通过 `cargo test`
4. **文档**: 为公共 API 添加文档注释

```bash
# 格式化代码
cargo fmt

# 检查代码
cargo clippy

# 运行测试
cargo test

# 文档生成
cargo doc --no-deps --open
```

### TypeScript/Vue (前端)

1. **格式化**: 使用 Prettier 格式化代码
2. **类型检查**: 确保 TypeScript 类型正确
3. **测试**: 运行所有测试

```bash
# 格式化代码
npm run format

# 类型检查
npm run type-check

# 运行测试
npm run test

# 构建
npm run build
```

## 提交规范

我们使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范来格式化提交信息：

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### 类型 (type)

- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式调整（不影响功能）
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建流程或辅助工具

### 示例

```bash
feat(auth): add user registration endpoint
fix(message): resolve message duplication issue
docs(api): update API documentation for search endpoint
test(auth): add unit tests for login function
```

## Pull Request 流程

1. **Fork 仓库** 并创建特性分支

```bash
git clone https://github.com/your-username/redcode-im.git
cd redcode-im
git checkout -b feature/amazing-feature
```

2. **进行更改** 并确保：
   - 代码格式化
   - 通过所有测试
   - 添加了必要的文档
   - 遵循代码规范

3. **提交更改**

```bash
git add .
git commit -m "feat: add amazing feature"
git push origin feature/amazing-feature
```

4. **创建 Pull Request**

在 GitHub 上打开 Pull Request，并包含：

- **清晰的标题和描述**
- **相关 Issue 链接** (如适用)
- **测试说明** (如何测试新功能)
- **截图** (如果涉及 UI 更改)

### PR 检查清单

- [ ] 代码遵循项目规范
- [ ] 添加了必要的测试
- [ ] 所有测试通过
- [ ] 文档已更新
- [ ] 提交信息遵循规范
- [ ] 没有合并冲突

## 开发流程

### 功能开发

1. 创建 Issue 讨论功能需求
2. 等待社区讨论和批准
3. 分配 Issue 给开发者
4. 创建特性分支进行开发
5. 提交 PR 进行代码审查
6. 合并到主分支

### 紧急修复

对于紧急的 Bug 修复：

1. 直接创建 PR 到 `main` 分支
2. 包含详细的修复说明
3. 至少需要一位维护者的批准
4. 合并后创建 Issue 记录问题

## 代码审查

所有 PR 都需要代码审查：

### 审查者检查

- [ ] 功能正确性
- [ ] 代码质量和可读性
- [ ] 性能影响
- [ ] 安全性
- [ ] 测试覆盖
- [ ] 文档更新

### 作者响应

- 及时响应审查意见
- 进行必要的修改
- 重新请求审查

## 社区行为准则

我们致力于提供一个友好、包容的社区环境：

- **尊重**: 尊重所有社区成员
- **包容**: 欢迎不同背景的人
- **建设性**: 提供建设性的反馈
- **专业**: 保持专业的交流

违反行为准则的行为将被禁止。

## 寻求帮助

如果您需要帮助：

- [GitHub Discussions](https://github.com/redcode-im/redcode-im/discussions) - 社区讨论
- [Discord](https://discord.gg/redcode-im) - 实时聊天
- 邮箱: dev@redcode-im.com

## 认可

贡献者将在以下地方被认可：

- README.md 中的贡献者列表
- 发布说明
- GitHub 贡献者页面

## 许可

通过贡献，您的代码将按照项目的 MIT 许可证许可。

---

再次感谢您的贡献！🎉
