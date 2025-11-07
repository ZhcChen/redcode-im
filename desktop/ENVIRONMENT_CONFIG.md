# 🌍 环境配置指南

本文档说明如何在不同环境（开发、测试、生产）下配置和运行应用。

## 📋 环境类型

应用支持三种环境：

| 环境 | 用途 | API 地址 | 特点 |
|------|------|---------|------|
| **development** | 本地开发 | http://localhost:8010 | 启用调试、热更新、源码映射 |
| **staging** | 测试/预发布 | https://staging-api.chatlyme.com | 启用部分调试、错误报告 |
| **production** | 生产环境 | https://api.chatlyme.com | 关闭调试、启用错误报告、性能优化 |

## 🚀 快速开始

### 1. 开发环境

```bash
# 使用默认开发配置
bun run dev

# 或明确指定开发环境
bun run tauri:dev

# 开发环境会自动：
# - 连接到 localhost:8010
# - 启用所有调试功能
# - 禁用 SSL 验证（适合本地开发）
```

### 2. 测试环境

```bash
# 使用测试环境配置运行
bun run dev:staging

# 或使用 Tauri 测试配置
bun run tauri:dev:staging

# 构建测试版本
bun run build:staging
```

### 3. 生产环境

```bash
# 模拟生产环境运行（调试用）
bun run dev:production

# 构建生产版本
bun run build:production

# 使用 Tauri 构建生产版本
bun run tauri:build:production
```

## 🔧 配置文件

### 环境配置文件

- `.env.development` - 开发环境配置
- `.env.staging` - 测试环境配置
- `.env.production` - 生产环境配置
- `.env.example` - 配置示例模板

### 创建本地配置

1. 复制对应的环境配置文件：
```bash
# 开发环境
cp .env.development .env

# 或测试环境
cp .env.staging .env

# 或生产环境
cp .env.production .env
```

2. 根据需要修改 `.env` 文件中的配置

## 📝 主要配置项

### 基础配置

| 配置项 | 说明 | 示例值 |
|--------|------|--------|
| `VITE_API_BASE_URL` | API 基础地址 | http://localhost:8010 |
| `VITE_ENV` | 环境标识 | development |
| `VITE_USE_RUST_BACKEND` | 是否使用 Rust 后端 | true/false |

### 功能开关

| 配置项 | 说明 | 推荐值 |
|--------|------|--------|
| `VITE_RUST_USER_API` | 用户 API 使用 Rust | 生产: true |
| `VITE_RUST_FILE_UPLOAD` | 文件上传使用 Rust | 生产: true |
| `VITE_RUST_BATCH_REQUESTS` | 启用批量请求 | 生产: true |
| `VITE_RUST_CONNECTION_POOL` | 启用连接池 | 生产: true |

### 调试配置

| 配置项 | 说明 | 环境建议 |
|--------|------|----------|
| `VITE_ENABLE_DEBUG_LOG` | 启用调试日志 | 开发: true, 生产: false |
| `VITE_ENABLE_PERFORMANCE_MONITOR` | 启用性能监控 | 开发/测试: true |
| `VITE_ENABLE_SOURCE_MAPS` | 启用源码映射 | 开发: true, 生产: false |

## 🔄 环境切换

### 方法 1: 使用环境变量

```bash
# 设置环境变量
export VITE_ENV=production
export VITE_API_BASE_URL=https://api.chatlyme.com

# 运行应用
bun run dev
```

### 方法 2: 使用命令行参数

```bash
# 开发环境
bun run dev

# 测试环境
bun run dev:staging

# 生产环境
bun run dev:production
```

### 方法 3: 修改 .env 文件

直接编辑 `.env` 文件中的配置值

## 🏗️ 构建部署

### 开发构建
```bash
# 构建开发版本（包含调试信息）
bun run build
```

### 测试构建
```bash
# 构建测试版本
bun run build:staging
bun run tauri:build:staging
```

### 生产构建
```bash
# 构建生产版本（优化体积和性能）
bun run build:production
bun run tauri:build:production
```

## 🔍 环境检测

应用会按以下优先级检测环境：

1. `VITE_ENV` 环境变量
2. `import.meta.env.MODE` (Vite 模式)
3. 构建类型（debug/release）

### 在代码中获取环境信息

```typescript
import { getCurrentEnvironment, getEnvironmentInfo } from '@/config/environment'

// 获取当前环境
const env = getCurrentEnvironment() // 'development' | 'staging' | 'production'

// 获取完整环境信息
const info = getEnvironmentInfo()
console.log(info)
// {
//   environment: 'development',
//   apiBaseUrl: 'http://localhost:8010',
//   useRustBackend: false,
//   version: '0.1.0'
// }
```

## 🛡️ 安全建议

### 开发环境
- ✅ 可以禁用 SSL 验证（本地开发）
- ✅ 可以启用所有调试日志
- ⚠️ 不要在开发环境存储真实用户数据

### 测试环境
- ✅ 应该启用 SSL 验证
- ✅ 可以启用部分调试功能
- ⚠️ 使用测试数据，不要使用生产数据

### 生产环境
- ❗ 必须启用 SSL 验证
- ❗ 必须关闭调试日志
- ❗ 必须启用错误报告
- ❗ 不要暴露敏感配置信息

## 📊 性能优化

不同环境的推荐配置：

### 开发环境
```bash
VITE_USE_RUST_BACKEND=false  # 便于调试
VITE_HTTP_TIMEOUT=30000       # 较短超时
VITE_ENABLE_CACHE=false       # 禁用缓存
```

### 生产环境
```bash
VITE_USE_RUST_BACKEND=true    # 使用 Rust 获得更好性能
VITE_HTTP_TIMEOUT=60000        # 较长超时
VITE_ENABLE_CACHE=true         # 启用缓存
VITE_BATCH_SIZE=20            # 更大批量
```

## 🐛 故障排查

### 环境配置不生效
1. 检查 `.env` 文件是否存在
2. 确认环境变量名称正确（以 `VITE_` 开头）
3. 重启开发服务器

### API 连接失败
1. 检查 `VITE_API_BASE_URL` 配置
2. 确认目标服务器正在运行
3. 检查网络和防火墙设置

### Rust 功能未启用
1. 确认 `VITE_USE_RUST_BACKEND=true`
2. 检查具体功能开关（如 `VITE_RUST_USER_API`）
3. 重新编译 Rust 代码：`cargo build`

## 📚 更多信息

- [Rust HTTP 迁移指南](./RUST_HTTP_MIGRATION_GUIDE.md)
- [Vite 环境变量文档](https://vitejs.dev/guide/env-and-mode.html)
- [Tauri 配置文档](https://tauri.app/v1/api/config/)