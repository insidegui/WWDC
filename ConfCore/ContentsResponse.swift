//
//  ContentsResponse.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

public struct ContentsResponse: Decodable {

    public let events: [Event]
    public let rooms: [Room]
    public let tracks: [Track]
    public let resources: [RelatedResource]
    public let instances: [SessionInstance]
    public let sessions: [Session]

    init (events: [Event],
          rooms: [Room],
          tracks: [Track],
          resources: [RelatedResource],
          instances: [SessionInstance],
          sessions: [Session]) {
        self.events = events
        self.rooms = rooms
        self.resources = resources
        self.tracks = tracks
        self.instances = instances
        self.sessions = sessions
    }

    // MARK: - Decodable

    private enum CodingKeys: String, CodingKey {
        case response, rooms, tracks, sessions, events, contents, resources
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        var sessions = try container.decodeIfPresent([Session].self, forKey: .contents) ?? []
        let instances = try container.decodeIfPresent(ConditionallyDecodableCollection<SessionInstance>.self, forKey: .contents).map { Array($0) } ?? []

        // remove duplicated sessions
        instances.forEach { instance in
            guard let index = sessions.index(where: { $0.identifier == instance.session?.identifier }) else { return }

            sessions.remove(at: index)
        }

        self.events = try container.decodeIfPresent(forKey: .events) ?? []
        self.rooms = try container.decodeIfPresent(forKey: .rooms) ?? []
        self.resources = try container.decodeIfPresent(forKey: .resources) ?? []
        self.tracks = try container.decodeIfPresent(forKey: .tracks) ?? []
        self.instances = instances
        self.sessions = sessions
    }
}
