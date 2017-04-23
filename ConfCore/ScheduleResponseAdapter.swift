//
//  ScheduleResponseAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum ScheduleKeys: String, JSONSubscriptType {
    case response, rooms, tracks, sessions
    
    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class ScheduleResponseAdapter: Adapter {
    
    typealias InputType = JSON
    typealias OutputType = ScheduleResponse
    
    func adapt(_ input: JSON) -> Result<ScheduleResponse, AdapterError> {
        guard let roomsJson = input[ScheduleKeys.response][ScheduleKeys.rooms].array else {
            return .error(.missingKey(ScheduleKeys.rooms))
        }
        
        guard let tracksJson = input[ScheduleKeys.response][ScheduleKeys.tracks].array else {
            return .error(.missingKey(ScheduleKeys.rooms))
        }
        
        guard let instancesJson = input[ScheduleKeys.response][ScheduleKeys.sessions].array else {
            return .error(.missingKey(ScheduleKeys.rooms))
        }
        
        guard case .success(let rooms) = RoomsJSONAdapter().adapt(roomsJson) else {
            return .error(.invalidData)
        }
        
        guard case .success(var tracks) = TracksJSONAdapter().adapt(tracksJson) else {
            return .error(.invalidData)
        }
        
        // add order to tracks using the order from the server
        for i in 0..<tracks.count {
            tracks[i].order = i
        }
        
        guard case .success(let instances) = SessionInstancesJSONAdapter().adapt(instancesJson) else {
            return .error(.invalidData)
        }
        
        let response = ScheduleResponse(rooms: rooms,
                                        tracks: tracks,
                                        instances: instances)
        
        return .success(response)
    }
    
}
