// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "RealmSwift",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v4)
    ],
    products: [
        .library(
            name: "RealmSwift",
            targets: ["RealmSwift"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "RealmSwift",
            url: "https://github.com/realm/realm-swift/releases/download/v20.0.3/RealmSwift@16.4.spm.zip",
            checksum: "840a5fb0ad5d55d29de2ced5a3c9cb9114360ad906c30b0502ed2a33f1dbba8c",
        )
    ]
)
