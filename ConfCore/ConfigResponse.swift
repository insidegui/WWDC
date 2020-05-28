//
//  ConfigResponse.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

public struct ConfigResponse: Hashable, Codable {

    public static let fallbackFeedLanguage = "en"

    public struct FeedManifest: Hashable, Codable {
        public struct Feed: Hashable, Codable {
            public let url: URL
            public let etag: String?
        }

        public let contents: Feed
        public let articles: Feed
        public let layout: Feed
        public let maps: Feed
        public let liveVideos: Feed
        public let discover: Feed
        public let event: Feed
        public let transcripts: Feed
    }

    /// Maps from language ID (such as "en", "zho", etc) to feed manifests.
    public let feeds: [String: FeedManifest]

    /// Depiction of the current event for when the schedule is not available.
    public let eventHero: EventHero?

}
