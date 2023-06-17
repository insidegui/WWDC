// swift-tools-version:5.8

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
			path: "Transcripts/")
    ]
)
