# Desktop 模块启动问题解决方案

## 问题描述

在 macOS 上运行 `pnpm run tauri dev` 时出现权限错误：
```
error: couldn't create a temp dir: Permission denied (os error 13) 
at path "/var/folders/zz/zyxvpxvq6csfxvn_n0000000000000/T/rustc..."
```

## 问题原因

Rust 编译器尝试在系统临时目录创建临时文件时，该目录的所有者为 `root`，当前用户无写权限。

## 解决方案

### 方案 1：使用自定义临时目录（推荐）

已修改 `package.json`，在 `tauri` 脚本中设置自定义临时目录：
```json
"tauri": "TMPDIR=$HOME/.cargo-tmp tauri"
```

### 方案 2：使用启动脚本

已创建 `run_dev.sh` 脚本，可直接使用：
```bash
./run_dev.sh
```

### 方案 3：手动设置环境变量

在启动前设置环境变量：
```bash
export TMPDIR=$HOME/.cargo-tmp
export TMP=$HOME/.cargo-tmp
export TEMP=$HOME/.cargo-tmp
pnpm run tauri dev
```

### 方案 4：修复系统临时目录权限（需要 root 权限，不推荐）

```bash
sudo chown -R $(whoami) /var/folders/zz/zyxvpxvq6csfxvn_n0000000000000/T
```

## 验证

执行以下命令验证临时目录已正确设置：
```bash
echo $TMPDIR
ls -ld ~/.cargo-tmp
```

## 清理缓存

如果问题持续，可以清理 Cargo 缓存：
```bash
cd desktop/src-tauri
cargo clean
```

