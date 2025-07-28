// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "ConfCore",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ConfCore",
            type: .dynamic,
            targets: ["ConfCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.4"),
        .package(url: "https://github.com/bustoutsolutions/siesta", from: "1.5.2"),
        .package(path: "../RealmSwiftBinary"),
        .package(path: "../RealmBinary"),
        .package(url: "https://github.com/insidegui/CloudKitCodable", branch: "spm"),
        .package(path: "../Transcripts")
	],
    targets: [
        .target(
            name: "ConfCore",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
				"CloudKitCodable",
                .product(name: "RealmSwift", package: "RealmSwiftBinary"),
                .product(name: "Realm", package: "RealmBinary"),
                .product(name: "Siesta", package: "siesta"),
                "Transcripts"
			],
			path: "ConfCore/")
    ]
)
