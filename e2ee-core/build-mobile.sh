#!/usr/bin/env bash
#
# 构建 E2EE 共享核心的原生端链接产物：
#   - host（aarch64-apple-darwin）cdylib：Android JVM 单测经 JNA 加载
#   - Android arm64-v8a / x86_64 .so：拷贝到 android-app jniLibs
#   - iOS aarch64-apple-ios / simulator staticlib：供 App Xcode 工程链接
#
# 用法：
#   ANDROID_NDK_HOME=... ./e2ee-core/build-mobile.sh   # 默认全量
#   ./e2ee-core/build-mobile.sh host                    # 只构建 host
#   ./e2ee-core/build-mobile.sh android                 # 只构建 Android
#   ./e2ee-core/build-mobile.sh ios                     # 只构建 iOS
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT/e2ee-core"
RELEASE_DIR="$CORE/target/aarch64-apple-darwin/release"
NDK_HOME="${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/28.2.13676358}"

target="${1:-all}"

build_host() {
  cargo build --manifest-path "$CORE/Cargo.toml" --release --target aarch64-apple-darwin
  echo "host 产物: $RELEASE_DIR/libredcode_e2ee_core.{a,dylib}"
}

build_android() {
  local toolchain="$NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin"
  if [[ ! -x "$toolchain/aarch64-linux-android24-clang" ]]; then
    echo "NDK 工具链缺失: $toolchain（可用 ANDROID_NDK_HOME 指定）" >&2
    exit 1
  fi
  export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$toolchain/aarch64-linux-android24-clang"
  export CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="$toolchain/x86_64-linux-android24-clang"
  cargo build --manifest-path "$CORE/Cargo.toml" --release --target aarch64-linux-android
  cargo build --manifest-path "$CORE/Cargo.toml" --release --target x86_64-linux-android

  local jni="$ROOT/android-app/app/src/main/jniLibs"
  mkdir -p "$jni/arm64-v8a" "$jni/x86_64"
  cp "$CORE/target/aarch64-linux-android/release/libredcode_e2ee_core.so" "$jni/arm64-v8a/"
  cp "$CORE/target/x86_64-linux-android/release/libredcode_e2ee_core.so" "$jni/x86_64/"
  echo "Android 产物已拷贝到 $jni"
}

build_ios() {
  cargo build --manifest-path "$CORE/Cargo.toml" --release --target aarch64-apple-ios
  cargo build --manifest-path "$CORE/Cargo.toml" --release --target aarch64-apple-ios-sim
  cargo build --manifest-path "$CORE/Cargo.toml" --release --target x86_64-apple-ios
  local simulator="$CORE/target/ios-simulator-universal/release"
  mkdir -p "$simulator"
  lipo -create \
    "$CORE/target/aarch64-apple-ios-sim/release/libredcode_e2ee_core.a" \
    "$CORE/target/x86_64-apple-ios/release/libredcode_e2ee_core.a" \
    -output "$simulator/libredcode_e2ee_core.a"
  echo "iOS 产物:"
  ls -lh "$CORE"/target/{aarch64-apple-ios,aarch64-apple-ios-sim,x86_64-apple-ios}/release/libredcode_e2ee_core.a
  lipo -info "$simulator/libredcode_e2ee_core.a"
}

case "$target" in
  host) build_host ;;
  android) build_android ;;
  ios) build_ios ;;
  all)
    build_host
    build_android
    build_ios
    ;;
  *)
    echo "未知目标: $target（host|android|ios|all）" >&2
    exit 1
    ;;
esac
