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
            checksum: "e6535f21a26c49585267a2b0cd34cd2cd6f3dce422fd3c4883ec3bb67fc2a3f8"
        )
    ]
)
