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
            checksum: "b647b3bb823a77f531fbadd6bcaa579d8f3f61b883369371a746ba9181f77965"
        )
    ]
)
