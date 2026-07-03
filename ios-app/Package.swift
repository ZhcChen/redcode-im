// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RedCodeIOSApp",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RedCodeCore", targets: ["RedCodeCore"]),
        .library(name: "RedCodeNetworking", targets: ["RedCodeNetworking"]),
        .library(name: "RedCodeStorage", targets: ["RedCodeStorage"]),
        .library(name: "RedCodeFeatures", targets: ["RedCodeFeatures"]),
    ],
    targets: [
        .target(name: "RedCodeCore"),
        .target(
            name: "RedCodeNetworking",
            dependencies: ["RedCodeCore"]
        ),
        .target(
            name: "RedCodeStorage",
            dependencies: ["RedCodeCore"]
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
            dependencies: ["RedCodeStorage"]
        ),
        .testTarget(
            name: "RedCodeFeaturesTests",
            dependencies: ["RedCodeFeatures"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
