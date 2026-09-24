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
            url: "https://github.com/hotmic-wp/hotmic-core-ios/releases/download/1.0.2/HotMicCore.xcframework.zip",
            checksum: "d26c2301b5bf878911dbc195f18a959a674eecf2510ed5fa972e51a018a41c98"
        )
    ]
)
