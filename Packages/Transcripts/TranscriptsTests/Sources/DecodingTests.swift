//
//  DecodingTests.swift
//  TranscriptsTests
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import XCTest
@testable import Transcripts

final class DecodingTests: XCTestCase {

    func testManifestDecoding() throws {
        let manifest: TranscriptManifest = try Bundle(for: Self.self).loadJSON(from: "transcript-manifest-eng")

        XCTAssertEqual(manifest.individual.count, 3)

        XCTAssertEqual(manifest.individual["wwdc2019-103"]!.etag, "\"ea551e731dca2e07093c5c4e0dabc0b2\"")
        XCTAssertEqual(manifest.individual["wwdc2019-103"]!.url.absoluteString, "http://localhost:9042/wwdc2019-103-transcript-eng.json")
    }

    func testTranscriptDecoding() throws {
        let content: TranscriptContent = try Bundle(for: Self.self).loadJSON(from: "wwdc2019-103-transcript-eng")

        XCTAssertEqual(content.identifier, "wwdc2019-103")

        XCTAssertEqual(content.lines.count, 3588)

        XCTAssertEqual(content.lines[0].time, 7)
        XCTAssertEqual(content.lines[0].text, "Good afternoon, ladies and gentlemen. ")

        XCTAssertEqual(content.lines[3587].time, 7026)
        XCTAssertEqual(content.lines[3587].text, "It's going to be a great week. ")
    }

}
