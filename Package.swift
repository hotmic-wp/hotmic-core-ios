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
            url: "https://github.com/hotmic-wp/hotmic-core-ios/releases/download/1.1.2/HotMicCore.xcframework.zip",
            checksum: "179632b6e2fa7d0e984b1922729d4f74b03471742b3dfa9f2fc243f3b2b3425b"
        )
    ]
)
