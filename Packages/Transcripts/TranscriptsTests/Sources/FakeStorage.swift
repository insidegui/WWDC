//
//  FakeStorage.swift
//  TranscriptsTests
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
@testable import Transcripts

final class FakeStorage: TranscriptStorage {

    /// Mapping from identifier to etag for faking presence of cached transcript during tests.
    var fakeEtags: [String: String] = [:]

    func previousEtag(for identifier: String) -> String? { fakeEtags[identifier] }

    func store(_ transcripts: [TranscriptContent], manifest: TranscriptManifest) {
        storeCalledHandler(transcripts)
    }

    var storeCalledHandler: ([TranscriptContent]) -> Void = { _ in }

}
