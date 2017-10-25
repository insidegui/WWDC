//
//  EventsJSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum EventKeys: String, JSONSubscriptType {
    case name, current
    case start = "startTime"
    case end = "endTime"
    case identifier = "id"
    case imagesPath

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class EventsJSONAdapter: Adapter {
    typealias InputType = JSON
    typealias OutputType = Event

    func adapt(_ input: JSON) -> Result<Event, AdapterError> {
        guard let identifier = input[EventKeys.identifier].string else {
            return .error(.missingKey(EventKeys.identifier))
        }

        guard let name = input[EventKeys.name].string else {
            return .error(.missingKey(EventKeys.name))
        }

        guard let current = input[EventKeys.current].bool else {
            return .error(.missingKey(EventKeys.current))
        }

        guard let imagesPath = input[EventKeys.imagesPath].string else {
            return .error(.missingKey(EventKeys.imagesPath))
        }

        guard let rawStart = input[EventKeys.start].string else {
            return .error(.missingKey(EventKeys.start))
        }

        guard let rawEnd = input[EventKeys.end].string else {
            return .error(.missingKey(EventKeys.end))
        }

        guard case .success(let startDate) = DateTimeAdapter().adapt(rawStart) else {
            return .error(.invalidData)
        }

        guard case .success(let endDate) = DateTimeAdapter().adapt(rawEnd) else {
            return .error(.invalidData)
        }

        let event = Event.make(identifier: identifier,
                               name: name,
                               startDate: startDate,
                               endDate: endDate,
                               isCurrent: current,
                               imagesPath: imagesPath)

        return .success(event)
    }
}
