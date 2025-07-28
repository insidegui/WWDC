// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Realm",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v4)
    ],
    products: [
        .library(
            name: "Realm",
            targets: ["Realm"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "Realm",
            url: "https://github.com/realm/realm-swift/releases/download/v20.0.3/Realm.spm.zip",
            checksum: "6185f0f65c081da02ac90cd3e3db867dfa832cc2f8f7f4d7aba2f091994b311f"
        )
    ]
)
