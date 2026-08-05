// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RedCodeIOSApp",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(name: "RedCodeE2EECBridge", targets: ["RedCodeE2EECBridge"]),
        .library(name: "RedCodeCore", targets: ["RedCodeCore"]),
        .library(name: "RedCodeNetworking", targets: ["RedCodeNetworking"]),
        .library(name: "RedCodeStorage", targets: ["RedCodeStorage"]),
        .library(name: "RedCodeFeatures", targets: ["RedCodeFeatures"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "RedCodeE2EECBridge",
            linkerSettings: [
                // 链接 e2ee-core 本地静态库（先执行 e2ee-core/build-mobile.sh host）。
                // 相对路径以 `swift test`/`swift build` 的 ios-app 工作目录为基准。
                .unsafeFlags([
                    "-L../e2ee-core/target/aarch64-apple-darwin/release",
                    "-lredcode_e2ee_core",
                ])
            ]
        ),
        .target(
            name: "RedCodeCore",
            dependencies: ["RedCodeE2EECBridge"]
        ),
        .target(
            name: "RedCodeNetworking",
            dependencies: ["RedCodeCore"]
        ),
        .target(
            name: "RedCodeStorage",
            dependencies: [
                "RedCodeCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .target(
            name: "RedCodeFeatures",
            dependencies: [
                "RedCodeCore",
                "RedCodeNetworking",
                "RedCodeStorage",
            ]
        ),
        .testTarget(
            name: "RedCodeCoreTests",
            dependencies: ["RedCodeCore"]
        ),
        .testTarget(
            name: "RedCodeNetworkingTests",
            dependencies: [
                "RedCodeCore",
                "RedCodeNetworking",
            ]
        ),
        .testTarget(
            name: "RedCodeStorageTests",
            dependencies: [
                "RedCodeStorage",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "RedCodeFeaturesTests",
            dependencies: ["RedCodeFeatures"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
