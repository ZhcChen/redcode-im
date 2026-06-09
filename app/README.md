# app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this's your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Build Commands

### Development
```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Run tests
flutter test
```

### iOS Build
```bash
# Build for iOS simulator (debug only)
flutter build ios --debug --simulator

# Build for iOS device without code signing (for third-party signing)
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
flutter build ios --release --no-codesign

# Create IPA file for third-party signing
cd build/ios/iphoneos
zip -r ../../ipa/runner.ipa Runner.app
```

### Android Build
```bash
# 使用构建脚本（推荐）
./build_android.sh

# 手动构建 APK
flutter build apk --release

# 手动构建 App Bundle (for Google Play)
flutter build appbundle --release
```

### Build Scripts
```bash
# iOS IPA 构建（用于超级签名）
./build_ipa.sh

# Android APK/AAB 构建（交互式菜单）
./build_android.sh
```

### Other Platforms
```bash
# Web
flutter build web --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release
```

## Environment Setup

### iOS Development
1. Set UTF-8 locale (required for CocoaPods):
   ```bash
   export LANG=en_US.UTF-8
   export LC_ALL=en_US.UTF-8
   ```

2. Install iOS dependencies:
   ```bash
   cd ios && pod install && cd ..
   ```

3. For device deployment, configure signing in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

### Troubleshooting
- If encountering permission errors, run `flutter clean` and rebuild
- For iOS signing issues, use `--no-codesign` flag for third-party signing services
- Ensure Xcode command line tools are installed: `xcode-select --install`
