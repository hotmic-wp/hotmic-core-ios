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
            url: "https://github.com/hotmic-wp/hotmic-core-ios/releases/download/1.1.1/HotMicCore.xcframework.zip",
            checksum: "cf5933a68afd64e2c7493f67b17661e9a41c834c44ff49c1eca4f0bf5fd5cb86"
        )
    ]
)
