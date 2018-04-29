//
//  SessionInstancesJSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 16/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

enum SessionInstanceKeys: String, JSONSubscriptType {
    case id, keywords, startTime, endTime, type, eventId
    case favId = "fav_id"
    case room = "roomId"
    case track = "trackId"

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class SessionInstancesJSONAdapter: Adapter {

    typealias InputType = JSON
    typealias OutputType = SessionInstance

    func adapt(_ input: JSON) -> Result<SessionInstance, AdapterError> {
        guard case .success(let session) = SessionsJSONAdapter().adapt(input) else {
            return .error(.invalidData)
        }

        var year = Calendar.current.component(.year, from: Date())
        if Calendar.current.component(.month, from: Date()) < 6 {
            year -= 1
        }
        guard session.year == year else {
            return .error(.invalidData)
        }

        guard let startGMT = input[SessionInstanceKeys.startTime].string else {
            return .error(.missingKey(SessionInstanceKeys.startTime))
        }

        guard let endGMT = input[SessionInstanceKeys.endTime].string else {
            return .error(.missingKey(SessionInstanceKeys.startTime))
        }

        guard let rawType = input[SessionInstanceKeys.type].string else {
            return .error(.missingKey(SessionInstanceKeys.type))
        }

        guard let id = input[SessionInstanceKeys.id].string else {
            return .error(.missingKey(SessionInstanceKeys.id))
        }

        guard let eventId = input[SessionInstanceKeys.eventId].string else {
            return .error(.missingKey(SessionInstanceKeys.eventId))
        }

        guard let roomIdentifier = input[SessionInstanceKeys.room].int else {
            return .error(.missingKey(SessionInstanceKeys.room))
        }

        guard let trackIdentifier = input[SessionInstanceKeys.track].int else {
            return .error(.missingKey(SessionInstanceKeys.track))
        }

        guard case .success(let startDate) = DateTimeAdapter().adapt(startGMT) else {
            return .error(.invalidData)
        }

        guard case .success(let endDate) = DateTimeAdapter().adapt(endGMT) else {
            return .error(.invalidData)
        }

        let instance = SessionInstance()

        if let keywordsJson = input[SessionInstanceKeys.keywords].array {
            if case .success(let keywords) = KeywordsJSONAdapter().adapt(keywordsJson) {
                instance.keywords.append(objectsIn: keywords)
            }
        }

        instance.identifier = session.identifier
        instance.eventIdentifier = eventId
        instance.number = id
        instance.session = session
        instance.trackIdentifier = "\(trackIdentifier)"
        instance.roomIdentifier = "\(roomIdentifier)"
        instance.rawSessionType = rawType
        instance.sessionType = SessionInstanceType(rawSessionType: rawType)?.rawValue ?? 0
        instance.startTime = startDate
        instance.endTime = endDate

        return .success(instance)
    }

}
