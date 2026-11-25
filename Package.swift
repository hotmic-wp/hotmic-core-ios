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
            url: "https://github.com/hotmic-wp/hotmic-core-ios/releases/download/1.1.3/HotMicCore.xcframework.zip",
            checksum: "e664866f06e70049e42595e2c03f8656aafa85e3280ac1d0310b46b088b62955"
        )
    ]
)
