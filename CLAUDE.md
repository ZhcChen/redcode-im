# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

redcode-im 是一个多模块聊天应用，包含三个主要模块：
- `backend` - Rust + Axum 后端服务
- `frontend` - Flutter 移动应用
- `admin` - Arco Design Pro Vue 管理后台

## 常用开发命令

### 后端开发 (backend/)
```bash
# 运行开发服务器（默认端口 8080）
cargo run

# 使用自定义端口
PORT=3000 cargo run

# 构建项目
cargo build

# 运行测试
cargo test
```

### 前端开发 (frontend/)
```bash
# 使用 Flutter 工具链进行开发与构建
flutter pub get
flutter run

# 构建正式包（示例）
flutter build apk
```

### 管理后台开发 (admin/)
```bash
# 安装依赖
pnpm install

# 开发服务器
pnpm dev

# 构建生产版本
pnpm build

# 类型检查
pnpm type:check

# 预览构建结果
pnpm preview

# 代码格式化和检查
pnpm lint-staged
```

## 项目架构

### 后端架构
- **框架**: Axum (Rust 异步 Web 框架)
- **主要功能**: 提供 HTTP API 和 WebSocket 服务
- **端口**: 默认 8080，可通过 PORT 环境变量覆盖
- **核心端点**:
  - `GET /` - 基础信息
  - `GET /healthz` - 健康检查
  - `GET /ws` - WebSocket 连接（回声模式）

### 前端架构
- **框架**: Flutter
- **目标平台**: 跨平台移动应用（Android / iOS / Web）
- **构建工具**: Flutter SDK
- **结构**: 标准 Flutter 工程目录

### 管理后台架构
- **框架**: Vue 3 + TypeScript
- **UI 库**: Arco Design Vue
- **构建工具**: Vite
- **状态管理**: Pinia
- **路由**: Vue Router 4
- **特性**:
  - ESLint + Prettier 代码规范
  - Husky + lint-staged 提交检查
  - 支持国际化 (i18n)
  - Mock 数据支持

## 开发注意事项

### 环境要求
- Rust 1.70+ (后端)
- Node.js 14+ (管理后台)
- pnpm (管理后台包管理器)
- Flutter SDK 3.24+（前端）

### 项目结构说明
- 后端采用单一文件结构 (`src/main.rs`)，便于快速开发
- 前端使用 Flutter 工程结构，支持多端发布
- 管理后台采用企业级 Vue 3 架构，功能完整

### 扩展建议
- 后端可考虑模块化重构，分离路由、服务和数据层
- 前端需通过 Flutter 集成 HTTP 与 WebSocket，与后端通信
- 管理后台已具备完整的企业级功能，可直接扩展业务逻辑