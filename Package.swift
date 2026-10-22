// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HotMicCore",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "HotMicCore",
            targets: ["HotMicCore"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "HotMicCore",
            url: "https://github.com/hotmic-wp/hotmic-core-ios/releases/download/1.1.0/HotMicCore.xcframework.zip",
            checksum: "8069a511c086bb819db455e617ecc0f6d4f65fabad610c5dcac94ff5f7c39153"
        )
    ]
)
