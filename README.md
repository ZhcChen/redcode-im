# RedCode IM - 即时通讯系统

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rust](https://img.shields.io/badge/Rust-1.75+-orange.svg)](https://www.rust-lang.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-blue.svg)](https://www.typescriptlang.org/)

RedCode IM 是一个现代化的即时通讯系统，采用微服务架构设计，支持私聊、群聊、文件传输、消息搜索等完整功能。

## ✨ 特性

- 🚀 **高性能**: 基于 Rust + Axum 构建，异步处理，高并发支持
- 💬 **实时通讯**: WebSocket 实时消息推送
- 👥 **群组管理**: 完整的群组管理功能，包括权限控制、成员管理
- 🔍 **消息搜索**: 强大的消息搜索功能，支持全文检索
- 📁 **文件传输**: 支持图片、文档、音频、视频等多种文件类型
- 🔐 **安全认证**: JWT Token 认证，密码加密存储
- 📊 **监控统计**: 完整的系统监控和数据统计
- 🌍 **多平台**: 支持桌面端（Vue 3 + Tauri）、Web端

## 🏗️ 技术架构

### 后端 (backend)
- **语言**: Rust
- **框架**: Axum 0.7
- **数据库**: PostgreSQL 15
- **缓存**: Redis 7
- **WebSocket**: 支持实时消息推送
- **文件存储**: 多存储提供商支持（本地、S3等）

### 前端 (desktop)
- **语言**: TypeScript
- **框架**: Vue 3
- **桌面应用**: Tauri 2.0
- **构建工具**: Vite
- **状态管理**: Vuex

## 📦 项目结构

```
redcode-im/
├── backend/               # 后端服务
│   ├── src/
│   │   ├── auth/          # 认证模块
│   │   ├── database/      # 数据库模型
│   │   ├── handlers/      # API 处理器
│   │   ├── routes/        # 路由定义
│   │   ├── websocket/     # WebSocket 处理
│   │   └── ...
│   ├── tests/             # 测试文件
│   │   ├── integration/   # 集成测试
│   │   ├── unit/          # 单元测试
│   │   └── fixtures/      # 测试数据
│   └── Cargo.toml
├── desktop/              # 桌面端
│   ├── src/
│   │   ├── api/          # API 客户端
│   │   ├── components/   # 组件
│   │   ├── views/        # 页面
│   │   ├── store/        # 状态管理
│   │   └── utils/        # 工具函数
│   ├── src-tauri/        # Tauri 后端
│   └── package.json
├── docs/                 # 文档
│   ├── API.md           # API 文档
│   └── ...
└── README.md
```

## 🚀 快速开始

### 环境要求

- Rust 1.75+
- Node.js 18+
- PostgreSQL 15+
- Redis 7+

### 后端设置

1. **克隆仓库**

```bash
git clone https://github.com/redcode-im/redcode-im.git
cd redcode-im/backend
```

2. **配置环境变量**

创建 `.env` 文件：

```bash
# 数据库配置
DATABASE_URL=postgresql://user:password@localhost:5432/redcode_im

# Redis 配置
REDIS_URL=redis://localhost:6379

# JWT 配置
JWT_SECRET=your-secret-key-here

# 文件存储配置
STORAGE_PROVIDER=local
STORAGE_LOCAL_PATH=./storage

# 服务配置
PORT=8010
```

3. **安装依赖并运行**

```bash
# 安装 Rust 依赖
cargo install

# 运行数据库迁移
cargo run --bin redcode-im -- migrate

# 启动开发服务器
cargo run
```

后端服务将在 `http://localhost:8010` 启动。

### 桌面端设置

```bash
cd desktop

# 安装依赖
npm install
# 或
bun install

# 启动开发服务器
npm run tauri dev
# 或
bun run tauri dev
```

桌面应用将自动启动。

## 📚 文档

- [API 文档](docs/API.md) - 完整的 API 参考
- [开发文档](docs/) - 开发者指南
- [架构设计](docs/ARCHITECTURE.md) - 系统架构说明

## 🧪 测试

### 后端测试

```bash
# 运行所有测试
cargo test

# 运行单元测试
cargo test --lib

# 运行集成测试
cargo test --test integration

# 查看测试覆盖率
cargo install cargo-tarpaulin
cargo tarpaulin --out html
```

### 前端测试

```bash
cd desktop

# 运行单元测试
npm run test

# 运行测试并生成覆盖率报告
npm run test:coverage
```

## 📖 使用指南

### 创建用户

```bash
curl -X POST http://localhost:8010/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "password123",
    "email": "test@example.com"
  }'
```

### 用户登录

```bash
curl -X POST http://localhost:8010/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "password123"
  }'
```

### 发送消息

```bash
curl -X POST http://localhost:8010/api/v1/rooms/{room_id}/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "content": "你好，世界！"
  }'
```

## 🔧 开发

### 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

### 代码规范

- 后端: 遵循 [Rust 代码规范](https://rust-lang.github.io/api-guidelines/)
- 前端: 遵循 [Vue 风格指南](https://cn.vuejs.org/style-guide/)
- 提交信息: 使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式

## 📊 性能

- **并发连接数**: 10,000+ WebSocket 连接
- **消息吞吐量**: 50,000+ 消息/秒
- **响应时间**: < 100ms 平均响应时间
- **内存占用**: < 100MB 后端服务内存占用

## 🐛 已知问题

- 管理员功能中的密码加密模块需要更新到 argon2 0.6 API（开发中）
- 文件上传进度显示待优化

## 🗺️ 路线图

- [ ] 语音通话功能
- [ ] 视频通话功能
- [ ] 端到端加密
- [ ] 消息撤回/编辑
- [ ] 表情包系统
- [ ] 机器人集成
- [ ] 消息加密
- [ ] 分布式部署支持

## 🤝 社区

- [GitHub Issues](https://github.com/redcode-im/redcode-im/issues) - 报告 Bug
- [GitHub Discussions](https://github.com/redcode-im/redcode-im/discussions) - 讨论功能
- [Discord](https://discord.gg/redcode-im) - 实时交流

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

感谢以下开源项目：

- [Axum](https://github.com/tokio-rs/axum) - Web 框架
- [Tokio](https://github.com/tokio-rs/tokio) - 异步运行时
- [SQLx](https://github.com/launchbadge/sqlx) - 异步 SQL 工具包
- [Vue 3](https://github.com/vuejs/core) - 前端框架
- [Tauri](https://github.com/tauri-apps/tauri) - 桌面应用框架

## 📞 联系我们

- 邮箱: contact@redcode-im.com
- 官网: https://redcode-im.com
- GitHub: https://github.com/redcode-im/redcode-im

---

⭐ 如果这个项目对您有帮助，请给我们一个星标！
