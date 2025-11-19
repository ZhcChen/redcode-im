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
- **支持平台**：Windows原生构建 + macOS交叉编译（使用cargo-xwin）
- **用法**：

  **自动检测环境：**
  ```bash
  ./scripts/build-windows.sh [channel]
  ```

  **在macOS上交叉编译（会自动使用cargo-xwin）：**
  ```bash
  export PATH="/opt/homebrew/opt/llvm/bin:$PATH" && export VITE_APP_CHANNEL=stable && export VITE_APP_VERSION=1.0.0 && export VITE_APP_BUILD=100 && ./scripts/build-windows.sh stable
  ```

  - 可选渠道参数，默认为 `stable`。
  - 输出目录：`dist/releases/windows/<channel>/`。
  - **增量构建**：自动检测updater源码变更，只在需要时重新编译。

## build-updater.sh
- **作用**：独立构建 updater 二进制文件，用于应用更新功能。
- **支持平台**：Windows、macOS (arm64/intel)、Linux
- **用法**：
  ```bash
  ./scripts/build-updater.sh [platform]
  ```
  - `platform` 参数可选值：
    - `windows` - 仅构建 Windows updater
    - `macos` - 仅构建 macOS updater（包含 arm64 和 intel）
    - `linux` - 仅构建 Linux updater
    - `all` - 根据当前系统构建所有可能的平台（默认）
  
  **示例**：
  ```bash
  # 构建所有平台（自动检测）
  ./scripts/build-updater.sh
  
  # 仅构建 Windows updater（支持 macOS 交叉编译）
  ./scripts/build-updater.sh windows
  
  # 仅构建 macOS updater
  ./scripts/build-updater.sh macos
  ```
  
  - 输出目录：`src-tauri/resources/updater-<target>`
  - **交叉编译**：在 macOS 上可以交叉编译 Windows updater
  - **使用场景**：
    - 修改了 `updater_bin.rs` 后需要重新构建
    - 主构建脚本中的 updater 出现问题时独立调试
    - 为特定平台单独构建 updater

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
- **无终端窗口**：更新器启动后立即退出，不显示终端窗口，避免用户看到闪烁的命令行界面

## 平台构建支持

| 平台 | 本地构建 | CI/CD构建 | 交叉编译 |
|------|----------|-----------|----------|
| macOS (Intel/ARM64) | ✅ | ✅ | ❌ |
| Linux (x64) | ✅ | ✅ | ❌ |
| Windows (x64) | ✅ | ✅ | ✅ (macOS→Windows) |

## 构建说明

项目支持多平台本地构建：

- **macOS**: 支持Intel和ARM64架构
- **Linux**: 支持x64架构
- **Windows**: 支持x64架构（需在Windows环境运行）

## 故障排除

### Windows交叉编译设置
脚本会自动检测macOS环境并使用cargo-xwin进行交叉编译。如遇到问题：
1. 确保已安装cargo-xwin：`cargo install --locked cargo-xwin`
2. 确保PATH包含llvm：`export PATH="/opt/homebrew/opt/llvm/bin:$PATH"`
3. 确保已添加Windows目标：`rustup target add x86_64-pc-windows-msvc`

### updater二进制缺失或版本不匹配
如果遇到 updater 相关问题：
1. **重新构建 updater**：`./scripts/build-updater.sh`
2. **检查二进制是否存在**：`ls -la src-tauri/resources/updater-*`
3. **验证构建目标**：确保为正确的平台构建了 updater
4. **修改源码后**：必须重新运行 `build-updater.sh` 以更新二进制

### 构建产物缺少updater
检查构建脚本是否正确复制了updater二进制到应用包中。

## 其他说明
- 所有脚本默认读取当前 shell 的环境变量（例如 `VITE_APP_CHANNEL`、`VITE_APP_BUILD`）。
- 如果在 CI 中执行，建议在命令前显式导出所需变量，确保构建产物一致。
- GUI更新器使用Rust+Tauri实现，提供专业的安装界面，避免终端窗口闪烁。
