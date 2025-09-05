// swift-tools-version:6.1

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
        .package(url: "https://github.com/insidegui/realm-swift.git", exact: "20.0.3"),
        .package(url: "https://github.com/insidegui/CloudKitCodable", branch: "spm"),
        .package(path: "../Transcripts")
	],
    targets: [
        .target(
            name: "ConfCore",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
				"CloudKitCodable",
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "Siesta", package: "siesta"),
                "Transcripts"
			],
			path: "ConfCore/",
            swiftSettings: [
                // 6.2 features, non-default
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                // swift 6 defaults
                .enableUpcomingFeature("RegionBasedIsolation"),
                .enableUpcomingFeature("GlobalConcurrency"),
                .enableUpcomingFeature("IsolatedDefaultValues"),
                .enableUpcomingFeature("DisableOutwardActorInference"),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
                .enableUpcomingFeature("DynamicActorIsolation", .when(configuration: .debug))
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
