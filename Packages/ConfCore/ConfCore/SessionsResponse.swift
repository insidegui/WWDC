//
//  SessionsResponse.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

public struct SessionsResponse: Decodable {

    public let events: [Event]
    public let sessions: [Session]
    public let assets: [SessionAsset]
    public let tracks: [Track]

    init(events: [Event], sessions: [Session], assets: [SessionAsset], tracks: [Track]) {
        self.events = events
        self.sessions = sessions
        self.assets = assets
        self.tracks = tracks
    }

    // MARK: - Decodable

    private enum CodingKeys: String, CodingKey {
        case events, sessions
    }

    public init(from decoder: Decoder) throws {
        let context = DecodingError.Context(codingPath: decoder.codingPath,
                                            debugDescription: "SessionResponse decoding is not currently supported")
        throw DecodingError.dataCorrupted(context)

//        let container = try decoder.container(keyedBy: CodingKeys.self)
//
//        let events = try container.decode(FailableItemArrayWrapper<Event>.self, forKey: .events).items
//        let sessions = try container.decode(FailableItemArrayWrapper<Session>.self, forKey: .sessions).items
//        let assets = try container.decode(FailableItemArrayWrapper<SessionAsset>.self, forKey: .sessions).items
//
//        let trackNames = Set(sessions.map({ $0.trackName }))
//        let tracks = trackNames.map { name -> Track in
//            let track = Track()
//
//            track.name = name
//
//            return track
//        }
//
//        self.events = events
//        self.sessions = sessions
//        self.assets = assets
//        self.tracks = tracks
    }
}
