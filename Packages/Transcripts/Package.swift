// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Transcripts",
    platforms: [
        .macOS(.v10_15)
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
			path: "Transcripts/")
    ]
)
