# scripts 目录说明

> 所有脚本均在 `desktop/scripts/` 下执行，默认在项目根目录运行即可。

## build-macos.sh
- **作用**：按指定架构构建 macOS 桌面端，并自动注入渠道/版本信息。
- **用法**：
  ```bash
  ./scripts/build-macos.sh [arm64|intel] [channel]
  ```
  - 第一个参数为架构（默认 `arm64`）。
  - 第二个参数可覆盖渠道（默认根据架构自动设置，例如 `stable-macos-arm64`）。
  - 脚本会生成 `.dmg` 并放在 `dist/releases/macos/<channel>/`。

## build-linux.sh
- **作用**：构建 Linux AppImage，注入版本/渠道信息。
- **用法**：
  ```bash
  ./scripts/build-linux.sh [channel]
  ```
  - 可选渠道参数，默认为 `stable-linux`。
  - 输出目录：`dist/releases/linux/<channel>/`。

## update-version.sh
- **作用**：一次性同步桌面端涉及版本号的所有文件（`package.json`、`src-tauri/tauri.conf.json`、`src/api/config.ts`、构建脚本和 `AGENTS.md`）。
- **用法**：
  ```bash
  ./scripts/update-version.sh <version>
  ```
  - 传入目标版本号（如 `1.0.1`），脚本会自动修改所有相关文件。
  - 执行完毕后记得检查差异并提交。

## 其他说明
- 所有脚本默认读取当前 shell 的环境变量（例如 `VITE_APP_CHANNEL`、`VITE_APP_BUILD`）。
- 如果在 CI 中执行，建议在命令前显式导出所需变量，确保构建产物一致。
