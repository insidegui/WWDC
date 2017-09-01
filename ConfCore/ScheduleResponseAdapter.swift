//
//  ScheduleResponseAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum ContentKeys: String, JSONSubscriptType {
    case response, rooms, tracks, sessions, events, contents

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class ContentsResponseAdapter: Adapter {

    typealias InputType = JSON
    typealias OutputType = ContentsResponse

    func adapt(_ input: JSON) -> Result<ContentsResponse, AdapterError> {
        guard let eventsJson = input[ContentKeys.events].array else {
            return .error(.missingKey(ContentKeys.events))
        }

        guard case .success(let events) = EventsJSONAdapter().adapt(eventsJson) else {
            return .error(.invalidData)
        }

        guard let roomsJson = input[ContentKeys.rooms].array else {
            return .error(.missingKey(ContentKeys.rooms))
        }

        guard case .success(let rooms) = RoomsJSONAdapter().adapt(roomsJson) else {
            return .error(.invalidData)
        }

        guard let tracksJson = input[ContentKeys.tracks].array else {
            return .error(.missingKey(ContentKeys.rooms))
        }

        guard case .success(let tracks) = TracksJSONAdapter().adapt(tracksJson) else {
            return .error(.missingKey(ContentKeys.tracks))
        }

        guard let sessionsJson = input[ContentKeys.contents].array else {
            return .error(.missingKey(ContentKeys.contents))
        }

        guard case .success(var sessions) = SessionsJSONAdapter().adapt(sessionsJson) else {
            return .error(.invalidData)
        }

        guard case .success(let instances) = SessionInstancesJSONAdapter().adapt(sessionsJson) else {
            return .error(.invalidData)
        }

        // remove duplicated sessions
        instances.forEach { instance in
            guard let index = sessions.index(where: { $0.identifier == instance.session?.identifier }) else { return }

            sessions.remove(at: index)
        }

        let response = ContentsResponse(events: events, rooms: rooms, tracks: tracks, instances: instances, sessions: sessions)

        return .success(response)
    }

}
