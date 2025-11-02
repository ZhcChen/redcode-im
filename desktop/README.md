# Bear Chat Tauri

一个基于 Tauri 框架的多窗口即时通讯客户端应用，使用 Vue 3 + TypeScript + Rust 构建。

## 技术栈

- **前端**: Vue 3 + TypeScript + Vite
- **后端**: Rust + Tauri 2.0
- **包管理器**: Bun
- **构建工具**: Tauri CLI

## 功能特性

- 🪟 多窗口管理系统
- 🎨 现代化 UI 设计
- 🚀 跨平台支持 (macOS, Windows, Linux)
- ⚡ 高性能 Rust 后端
- 🔧 实时窗口状态管理

## 开发环境要求

- [Bun](https://bun.sh/) - JavaScript 运行时和包管理器
- [Rust](https://rustup.rs/) - Rust 编程语言
- [Node.js](https://nodejs.org/) (可选，如果不使用 Bun)

## 推荐 IDE 配置

- [VS Code](https://code.visualstudio.com/) + [Vue - Official](https://marketplace.visualstudio.com/items?itemName=Vue.volar) + [Tauri](https://marketplace.visualstudio.com/items?itemName=tauri-apps.tauri-vscode) + [rust-analyzer](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust-analyzer)

## 快速开始

### 1. 安装依赖

```bash
# 使用 Bun 安装前端依赖
bun install

# 确保 Rust 和 Tauri CLI 已安装
rustup update
```

### 2. 开发模式

```bash
# 启动开发服务器
bun run dev

# 启动 Tauri 开发模式（推荐）
bun run tauri dev
```

### 3. 构建应用

```bash
# 构建生产版本
bun run build

# 构建 Tauri 应用
bun run tauri build

# 构建特定平台版本
bun run tauri build --target x86_64-apple-darwin  # macOS Intel
bun run tauri build --target aarch64-apple-darwin # macOS Apple Silicon

# Windows 交叉编译（在 macOS 上）
export PATH="/opt/homebrew/opt/llvm/bin:$PATH" && bun run tauri build --runner cargo-xwin --target x86_64-pc-windows-msvc   # Windows x86_64
export PATH="/opt/homebrew/opt/llvm/bin:$PATH" && bun run tauri build --runner cargo-xwin --target aarch64-pc-windows-msvc  # Windows ARM64
```

## 可用脚本

### 开发和构建命令

| 命令 | 描述 |
|------|------|
| `bun install` | 安装项目依赖 |
| `bun run dev` | 启动 Vite 开发服务器 |
| `bun run build` | 构建前端生产版本 |
| `bun run preview` | 预览构建结果 |
| `bun run tauri dev` | 启动 Tauri 开发模式 |
| `bun run tauri build` | 构建 Tauri 应用 |

### 跨平台构建命令

| 平台 | 简化命令 | 完整命令 |
|------|----------|----------|
| macOS Intel | `bun run build:macos-intel` | `bun run tauri build --target x86_64-apple-darwin` |
| macOS Apple Silicon | `bun run build:macos-arm` | `bun run tauri build --target aarch64-apple-darwin` |
| Windows x86_64 | `bun run build:windows-x64` | `export PATH="/opt/homebrew/opt/llvm/bin:$PATH" && bun run tauri build --runner cargo-xwin --target x86_64-pc-windows-msvc` |
| Windows ARM64 | `bun run build:windows-arm` | `export PATH="/opt/homebrew/opt/llvm/bin:$PATH" && bun run tauri build --runner cargo-xwin --target aarch64-pc-windows-msvc` |
| 所有平台 | `bun run build:all-platforms` | 依次构建所有平台版本 |

### 图标生成命令

| 命令 | 描述 |
|------|------|
| `bun run tauri icon <path>` | 使用项目 CLI 生成图标 |
| `bunx @tauri-apps/cli icon <path>` | 直接使用 bunx 生成图标 |
| `bun run tauri icon --output <dir> <path>` | 指定输出目录生成图标 |

## 图标管理

项目使用 Tauri CLI 自动生成多平台图标：

```bash
# 方法一：使用项目中的 Tauri CLI（推荐）
bun run tauri icon public/logo.png

# 方法二：直接使用 bunx 运行 Tauri CLI
bunx @tauri-apps/cli icon public/logo.png

# 方法三：指定输出目录
bun run tauri icon --output src-tauri/icons public/logo.png
bunx @tauri-apps/cli icon --output src-tauri/icons public/logo.png

# 方法四：如果全局安装了 Tauri CLI
tauri icon public/logo.png
```

### 图标要求

- **分辨率**: 建议 1024x1024 像素或更高
- **格式**: PNG 格式，支持透明背景
- **设计**: 简洁明了，在小尺寸下仍然清晰

### 生成的图标格式

自动生成以下平台的图标：
- **Windows**: .ico (多尺寸图标文件)
- **macOS**: .icns (多尺寸图标文件)
- **Linux**: 各种尺寸的 PNG 文件
- **移动端**: iOS/Android 各种密度的图标

## 项目结构

```
bear-chat-tauri/
├── src/                    # Vue.js 前端源码
│   ├── App.vue            # 主应用组件
│   ├── main.ts            # 应用入口点
│   └── assets/            # 静态资源
├── src-tauri/             # Tauri 后端源码
│   ├── src/
│   │   ├── lib.rs         # 主要业务逻辑
│   │   └── main.rs        # 应用入口
│   ├── Cargo.toml         # Rust 依赖配置
│   ├── tauri.conf.json    # Tauri 应用配置
│   ├── capabilities/      # 权限配置
│   └── icons/             # 应用图标
├── public/                # 公共静态文件
├── package.json           # Node.js 依赖配置
├── bun.lockb             # Bun 锁定文件
└── vite.config.ts         # Vite 构建配置
```

## 跨平台构建

在 macOS 上可以构建的目标平台：

- ✅ macOS Apple Silicon (原生)
- ✅ macOS Intel (交叉编译)
- ✅ Windows x86_64 (交叉编译，实验性)
- ✅ Windows ARM64 (交叉编译，实验性)
- ⚠️ Linux (需要额外工具)

### Windows 交叉编译设置

在 macOS 上交叉编译 Windows 版本需要安装额外工具：

```bash
# 安装必要工具
brew install nsis llvm

# 安装 Rust 目标平台
rustup target add x86_64-pc-windows-msvc
rustup target add aarch64-pc-windows-msvc

# 安装 cargo-xwin
cargo install --locked cargo-xwin

# 添加 LLVM 到 PATH（添加到 ~/.zshrc）
echo 'export PATH="/opt/homebrew/opt/llvm/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**注意事项**：
- Windows 交叉编译只能生成 NSIS 安装器，不支持 MSI
- 代码签名需要额外配置
- 这是实验性功能，建议生产环境使用 CI/CD

### 构建输出

构建完成后，安装器文件将位于以下目录：

- **macOS**: `src-tauri/target/{target}/release/bundle/dmg/`
- **Windows**: `src-tauri/target/{target}/release/bundle/nsis/`
  - x86_64: `Chatly_0.1.0_x64-setup.exe`
  - ARM64: `Chatly_0.1.0_arm64-setup.exe`

其中 `{target}` 是目标平台标识符（如 `x86_64-pc-windows-msvc`）。

## 开发说明

- 项目使用 Vue 3 的 `<script setup>` 语法
- 后端 API 通过 Tauri 的 `invoke` 函数调用
- 支持热重载和实时预览
- 自动类型检查和 ESLint

## 许可证

本项目基于 MIT 许可证开源。
