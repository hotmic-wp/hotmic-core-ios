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
            checksum: "f60125ac5c053a84c7cb5c00d4d6cdb6c31e185402c9224a1dc2a5029c6daa6e"
        )
    ]
)
