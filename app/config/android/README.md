# Android 构建配置说明

本目录用于集中管理 Flutter Android 端的构建配置（Application ID、签名等），避免在多处硬编码，便于后续统一调整。

## 目录结构

- `app_config.properties`  
  Android 构建的统一配置文件，示例内容包括：
  - `APPLICATION_ID`：基础包名（如 `com.chatlyme.app`）
  - `APPLICATION_ID_SUFFIX_*`：可选的环境后缀（当前 Gradle 未启用，仅预留）
  - `KEYSTORE_FILE`：签名 keystore 文件相对路径（相对于 `app/android` 或项目根目录）
  - `KEYSTORE_PASSWORD`：keystore 密码（示例值，实际请使用本地/CI Secret）
  - `KEY_ALIAS`：密钥别名
  - `KEY_PASSWORD`：密钥密码

> 注意：仓库内的 `app_config.properties` 仅为**示例配置**，不应包含真实密码或生产 keystore 路径。

## 使用方式概览

### 1. Gradle 侧（`app/android/app/build.gradle.kts`）

Gradle 会尝试从 `app/config/android/app_config.properties` 读取配置：

- 若文件存在：
  - 使用其中的 `APPLICATION_ID` 作为 `defaultConfig.applicationId`；
  - 若 keystore 字段填写完整，则创建 `release` 签名配置并在 `buildTypes.release` 中使用；
  - 若字段不完整，则自动回退到 `debug` 签名（仅用于开发/测试）。
- 若文件不存在：
  - 回退为内置默认值 `com.chatlyme.app`，且使用 `debug` 签名。

这样可以保证：

- 没有配置时，本地仍可通过 `flutter run` 或脚本进行调试；
- 需要正式打包时，只需在本地/CI 上提供一份正确的 `app_config.properties` 即可。

### 2. 构建脚本侧（`app/scripts/build_android.sh`）

构建脚本会从同一份 `config/android/app_config.properties` 中读取 `APPLICATION_ID`，用于：

- 在构建结果输出中展示当前包名；
- 避免脚本内部硬编码包名，后续改动只需更新配置文件。

> 如果未来需要根据环境（development/staging/production）切换不同包名，可以在此文件中扩展 `APPLICATION_ID_SUFFIX_*` 并在 Gradle / 脚本中读取对应字段。

## 推荐实践

1. **本地开发环境**
   - 可以直接使用仓库自带的 `app_config.properties` 示例文件；
   - 如需自定义包名或本地 keystore，可复制一份为 `app_config.local.properties`（不提交到仓库），并在 Gradle 中优先读取。

2. **CI / 发版环境**
   - 不建议直接修改仓库内的示例文件；
   - 推荐做法：
     - 在 CI 中通过 Secret 注入一份 `app_config.properties` 到 `app/config/android/`；
     - 或使用环境变量覆盖 keystore 相关字段。

3. **安全注意事项**
   - **禁止**将真实 keystore 文件（`.jks` / `.keystore` 等）提交到仓库；
   - **禁止**在 `app_config.properties` 中填写真实生产密码；
   - 建议使用 `.gitignore` 忽略真实 keystore 存放目录，并在本文件中明确说明。

## 后续可扩展方向

- 为不同环境（dev/staging/prod）提供多套 `app_config.*.properties`，在脚本中根据参数选择；
- 将渠道号、版本号策略等也统一收敛到本目录下的配置中，减少重复配置。

