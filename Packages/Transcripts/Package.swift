// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "Transcripts",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Transcripts",
            targets: ["Transcripts"])
    ],
    dependencies: [ ],
    targets: [
        .target(
            name: "Transcripts",
            dependencies: [ ],
            path: "Transcripts/",
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
    swiftLanguageModes: [.v6]
)
