//
//  TranscriptManifest.swift
//  Transcripts
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

public struct TranscriptManifest: Hashable, Codable {
    public struct Feed: Hashable, Codable {
        public let url: URL
        public let etag: String
    }

    /// Session ID -> feed.
    public let individual: [String: Feed]
}
