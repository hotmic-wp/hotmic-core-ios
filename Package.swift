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
            url: "https://github.com/hotmic-wp/hotmic-core-ios/releases/download/1.0.1/HotMicCore.xcframework.zip",
            checksum: "5f59f096d1323e1e0075fd67e9d1ab9c84b8f11406d77e46de9010734600222e"
        )
    ]
)
