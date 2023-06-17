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
        .package(url: "https://github.com/bustoutsolutions/siesta", from: "1.5.2"),
        .package(url: "https://github.com/realm/realm-swift", from: "10.0.0"),
        .package(url: "https://github.com/insidegui/CloudKitCodable", branch: "spm"),
        .package(path: "../Transcripts")
	],
    targets: [
        .target(
            name: "ConfCore",
            dependencies: [
				"CloudKitCodable",
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "Siesta", package: "siesta"),
                "Transcripts"
			],
			path: "ConfCore/")
    ]
)
