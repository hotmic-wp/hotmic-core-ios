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
            url: "https://github.com/hotmic-wp/hotmic-core-ios/releases/download/1.0.0/HotMicCore.xcframework.zip",
            checksum: "467022a0f92a6d16e3605a972ded1d814bd283d2b377f2bcbeff5c2436f67897"
        )
    ]
)
