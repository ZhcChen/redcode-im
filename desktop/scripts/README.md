# scripts 目录说明

> 所有脚本均在 `desktop/scripts/` 下执行，默认在项目根目录运行即可。

## build-macos.sh
- **作用**：按指定架构构建 macOS 桌面端，包含GUI更新器，并自动注入渠道/版本信息。
- **用法**：
  ```bash
  ./scripts/build-macos.sh [arm64|intel] [channel]
  ```
  - 第一个参数为架构（默认 `arm64`）。
  - 第二个参数可覆盖渠道（默认根据架构自动设置，例如 `stable-macos-arm64`）。
  - 脚本会生成 `.dmg` 并放在 `dist/releases/macos/<channel>/`。
  - **增量构建**：自动检测updater源码变更，只在需要时重新编译。

## build-linux.sh
- **作用**：构建 Linux AppImage，包含GUI更新器，注入版本/渠道信息。
- **用法**：
  ```bash
  ./scripts/build-linux.sh [channel]
  ```
  - 可选渠道参数，默认为 `stable-linux`。
  - 输出目录：`dist/releases/linux/<channel>/`。
  - **增量构建**：自动检测updater源码变更，只在需要时重新编译。

## build-windows.sh
- **作用**：构建 Windows 安装程序，包含GUI更新器，注入版本/渠道信息。
- **限制**：**不支持从macOS交叉编译，必须在Windows机器上运行**
- **用法**：
  ```bash
  # 仅在Windows机器上运行
  ./scripts/build-windows.sh [channel]
  ```
  - 可选渠道参数，默认为 `stable-windows`。
  - 输出目录：`dist/releases/windows/<channel>/`。
  - **增量构建**：自动检测updater源码变更，只在需要时重新编译。

## update-version.sh
- **作用**：一次性同步桌面端涉及版本号的所有文件（`package.json`、`src-tauri/tauri.conf.json`、`src/api/config.ts`、构建脚本和 `AGENTS.md`）。
- **用法**：
  ```bash
  ./scripts/update-version.sh <version>
  ```
  - 传入目标版本号（如 `1.0.1`），脚本会自动修改所有相关文件。
  - 执行完毕后记得检查差异并提交。

## GUI 更新器

所有构建脚本都会自动处理GUI更新器的构建和打包：

- **增量编译**：只在 `src-tauri/src/updater_bin.rs` 源码变更时重新编译
- **自动打包**：编译后的updater二进制自动复制到应用包中
- **跨平台**：为每个目标平台生成正确的updater二进制

## 平台构建支持

| 平台 | 本地构建 | CI/CD构建 | 交叉编译 |
|------|----------|-----------|----------|
| macOS (Intel/ARM64) | ✅ | ✅ | ❌ |
| Linux (x64) | ✅ | ✅ | ❌ |
| Windows (x64) | ✅ (仅Windows) | ✅ | ❌ |

## CI/CD

项目使用GitHub Actions进行多平台自动构建：

- **触发条件**：push/PR 到 main/develop 分支
- **支持平台**：macOS (Intel/ARM64)、Linux x64、Windows x64
- **产物上传**：自动上传构建产物作为artifacts
- **工作流文件**：`.github/workflows/build.yml`

## 故障排除

### Windows构建在macOS上失败
```
[错误] macOS不支持直接交叉编译Windows目标
```
**解决方案**：
1. 在Windows机器上运行构建脚本
2. 使用GitHub Actions自动构建
3. 设置Windows开发环境进行交叉编译

### updater二进制缺失
脚本会自动编译updater。如失败请检查：
1. Rust工具链已安装
2. 目标平台受支持
3. 系统依赖完整

### 构建产物缺少updater
检查构建脚本是否正确复制了updater二进制到应用包中。

## 其他说明
- 所有脚本默认读取当前 shell 的环境变量（例如 `VITE_APP_CHANNEL`、`VITE_APP_BUILD`）。
- 如果在 CI 中执行，建议在命令前显式导出所需变量，确保构建产物一致。
- GUI更新器使用Rust+Tauri实现，提供专业的安装界面，避免终端窗口闪烁。
