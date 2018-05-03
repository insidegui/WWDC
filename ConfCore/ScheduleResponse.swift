//
//  ScheduleResponse.swift
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

        let events = try container.decode(FailableItemArrayWrapper<Event>.self, forKey: .events).items
        let rooms = try container.decode(FailableItemArrayWrapper<Room>.self, forKey: .rooms).items
        let resources = try container.decode(FailableItemArrayWrapper<RelatedResource>.self, forKey: .resources).items
        let tracks = try container.decode(FailableItemArrayWrapper<Track>.self, forKey: .tracks).items
        var sessions = try container.decode(FailableItemArrayWrapper<Session>.self, forKey: .contents).items
        let instances = try container.decode(FailableItemArrayWrapper<SessionInstance>.self, forKey: .contents).items

        // remove duplicated sessions
        instances.forEach { instance in
            guard let index = sessions.index(where: { $0.identifier == instance.session?.identifier }) else { return }

            sessions.remove(at: index)
        }

        self.events = events
        self.rooms = rooms
        self.resources = resources
        self.tracks = tracks
        self.instances = instances
        self.sessions = sessions
    }
}
