//
//  TranscriptDownloaderTests.swift
//  TranscriptsTests
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import XCTest
@testable import Transcripts

final class TranscriptDownloaderTests: XCTestCase {

    private let fakeManifestURL = URL(string: "https://example.com/transcript-manifest-eng.json")!
    private var downloader: TranscriptDownloader!

    private func makeHarness() -> (loader: FixtureLoader, storage: FakeStorage, downloader: TranscriptDownloader) {
        let loader = FixtureLoader()
        let storage = FakeStorage()

        return (loader, storage, TranscriptDownloader(
            loader: loader,
            manifestURL: fakeManifestURL,
            storage: storage,
            queue: .main,
            storageCoalescingInterval: 0.1
        ))
    }

    func testDownloadingAndStoringTranscriptsWithAllNewTranscripts() {
        let (_, storage, downloader) = makeHarness()

        var progresses: [Float] = []
        var storedIds: [String] = []

        let storageExpectation = expectation(description: "Storage must be called for all transcripts")

        storage.storeCalledHandler = { transcripts in
            storedIds.append(contentsOf: transcripts.map(\.identifier))
            if storedIds.count == 3 { storageExpectation.fulfill() }
        }

        let completionExpectation = expectation(description: "Completed must be called")

        downloader.fetch(progress: { p in
            progresses.append(p)
        }) {
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)

        XCTAssertEqual(progresses, [0.33333334, 0.6666667, 1.0])
        XCTAssertTrue(storedIds.contains("wwdc2019-103"))
        XCTAssertTrue(storedIds.contains("wwdc2019-104"))
        XCTAssertTrue(storedIds.contains("wwdc2019-202"))
    }

    func testDownloadingAndStoringTranscriptsWithPrimedStorage() {
        let (_, storage, downloader) = makeHarness()

        storage.fakeEtags["wwdc2019-103"] = "\"ea551e731dca2e07093c5c4e0dabc0b2\""

        var progresses: [Float] = []
        var storedIds: [String] = ["wwdc2019-103"]

        let storageExpectation = expectation(description: "Storage must be called for all transcripts")

        storage.storeCalledHandler = { transcripts in
            let ids = transcripts.map(\.identifier)

            // Ensure previously stored transcripts are not stored again.
            ids.forEach({ XCTAssertFalse(storedIds.contains($0)) })

            storedIds.append(contentsOf: ids)
            if storedIds.count == 3 { storageExpectation.fulfill() }
        }

        let completionExpectation = expectation(description: "Completed must be called")

        downloader.fetch(progress: { p in
            progresses.append(p)
        }) {
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)

        XCTAssertEqual(progresses, [0.33333334, 0.6666667, 1.0])
        XCTAssertTrue(storedIds.contains("wwdc2019-104"))
        XCTAssertTrue(storedIds.contains("wwdc2019-202"))
    }

    func testDownloadingAndStoringTranscriptsWithMismatchedEtag() {
        let (_, storage, downloader) = makeHarness()

        storage.fakeEtags["wwdc2019-103"] = "\"ffffffffffffffffffffffffffffffff\""

        var progresses: [Float] = []
        var storedIds: [String] = []

        let storageExpectation = expectation(description: "Storage must be called for all transcripts")

        storage.storeCalledHandler = { transcripts in
            storedIds.append(contentsOf: transcripts.map(\.identifier))
            if storedIds.count == 3 { storageExpectation.fulfill() }
        }

        let completionExpectation = expectation(description: "Completed must be called")

        downloader.fetch(progress: { p in
            progresses.append(p)
        }) {
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)

        XCTAssertEqual(progresses, [0.33333334, 0.6666667, 1.0])
        XCTAssertTrue(storedIds.contains("wwdc2019-103"))
        XCTAssertTrue(storedIds.contains("wwdc2019-104"))
        XCTAssertTrue(storedIds.contains("wwdc2019-202"))
    }

    func testDownloadingAndStoringTranscriptsWithKnownSessionIdentifiers() {
        let (_, storage, downloader) = makeHarness()

        var progresses: [Float] = []
        var storedIds: [String] = []

        let storageExpectation = expectation(description: "Storage must be called for all valid transcripts")

        storage.storeCalledHandler = { transcripts in
            storedIds.append(contentsOf: transcripts.map(\.identifier))
            if storedIds.count == 2 { storageExpectation.fulfill() }
        }

        let completionExpectation = expectation(description: "Completed must be called")

        downloader.fetch(validSessionIdentifiers: ["wwdc2019-103", "wwdc2019-104"], progress: { p in
            progresses.append(p)
        }) {
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)

        XCTAssertEqual(progresses, [0.5, 1.0])

        XCTAssertTrue(storedIds.contains("wwdc2019-103"))
        XCTAssertTrue(storedIds.contains("wwdc2019-104"))

        XCTAssertFalse(storedIds.contains("wwdc2019-202"))
    }
}
