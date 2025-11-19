#!/bin/bash
# 用法: ./scripts/build-updater.sh [platform]
# 平台: windows, macos, linux, all (默认: all)
set -euo pipefail

PLATFORM=${1:-all}

echo "===> 构建 Updater 二进制"
echo "平台: $PLATFORM"

cd src-tauri

# 创建 resources 目录
mkdir -p resources

build_windows() {
    echo "===> 构建 Windows updater"
    TARGET="x86_64-pc-windows-msvc"
    
    # 检查是否在 macOS 上运行（需要交叉编译）
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "===> 使用 cargo-xwin 进行交叉编译"
        export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
        
        # 先创建占位文件
        touch "resources/updater-$TARGET.exe"
        
        cargo xwin build --release --bin updater --target "$TARGET"
    else
        echo "===> 使用原生构建"
        touch "resources/updater-$TARGET.exe"
        cargo build --release --bin updater --target "$TARGET"
    fi
    
    # 复制到 resources 目录
    cp "target/$TARGET/release/updater.exe" "resources/updater-$TARGET.exe"
    echo "✅ Windows updater 构建完成: resources/updater-$TARGET.exe"
}

build_macos() {
    echo "===> 构建 macOS updater"
    
    # 构建两个架构
    for TARGET in "aarch64-apple-darwin" "x86_64-apple-darwin"; do
        echo "===> 构建 $TARGET"
        cargo build --release --bin updater --target "$TARGET"
        cp "target/$TARGET/release/updater" "resources/updater-$TARGET"
        echo "✅ $TARGET updater 构建完成"
    done
}

build_linux() {
    echo "===> 构建 Linux updater"
    TARGET="x86_64-unknown-linux-gnu"
    
    cargo build --release --bin updater --target "$TARGET"
    cp "target/$TARGET/release/updater" "resources/updater-$TARGET"
    echo "✅ Linux updater 构建完成: resources/updater-$TARGET"
}

# 根据平台参数构建
case "$PLATFORM" in
    windows)
        build_windows
        ;;
    macos)
        build_macos
        ;;
    linux)
        build_linux
        ;;
    all)
        echo "===> 构建所有平台的 updater"
        
        # 根据当前系统决定构建哪些平台
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "检测到 macOS 系统，将构建 macOS 和 Windows（交叉编译）"
            build_macos
            build_windows
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "检测到 Linux 系统，只能构建 Linux"
            build_linux
        elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
            echo "检测到 Windows 系统，只能构建 Windows"
            build_windows
        else
            echo "未知系统类型: $OSTYPE"
            exit 1
        fi
        ;;
    *)
        echo "错误: 未知平台 '$PLATFORM'"
        echo "支持的平台: windows, macos, linux, all"
        exit 1
        ;;
esac

cd ..

echo ""
echo "===> 所有 updater 二进制已构建完成"
echo "位置: src-tauri/resources/"
ls -lh src-tauri/resources/updater-*
