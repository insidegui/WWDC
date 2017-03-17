//
//  SessionInstancesJSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 16/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum SessionInstanceKeys: String, JSONSubscriptType {
    case id, track, room, keywords, startGMT, endGMT, type
    case favId = "fav_id"
    
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
        
        guard let id = input[SessionInstanceKeys.id].string else {
            return .error(.missingKey(SessionInstanceKeys.id))
        }
        
        guard let trackName = input[SessionInstanceKeys.track].string else {
            return .error(.missingKey(SessionInstanceKeys.track))
        }
        
        guard let roomName = input[SessionInstanceKeys.room].string else {
            return .error(.missingKey(SessionInstanceKeys.room))
        }
        
        guard let startGMT = input[SessionInstanceKeys.startGMT].string else {
            return .error(.missingKey(SessionInstanceKeys.startGMT))
        }
        
        guard let endGMT = input[SessionInstanceKeys.endGMT].string else {
            return .error(.missingKey(SessionInstanceKeys.endGMT))
        }
        
        guard let rawType = input[SessionInstanceKeys.type].string else {
            return .error(.missingKey(SessionInstanceKeys.type))
        }
        
        guard let keywordsJson = input[SessionInstanceKeys.keywords].array else {
            return .error(.missingKey(SessionInstanceKeys.keywords))
        }
        
        guard case .success(let keywords) = KeywordsJSONAdapter().adapt(keywordsJson) else {
            return .error(.invalidData)
        }
        
        guard case .success(let startDate) = DateTimeAdapter().adapt(startGMT) else {
            return .error(.invalidData)
        }
        
        guard case .success(let endDate) = DateTimeAdapter().adapt(endGMT) else {
            return .error(.invalidData)
        }
        
        let instance = SessionInstance()
        
        instance.identifier = session.identifier
        instance.number = id
        instance.session = session
        instance.trackName = trackName
        instance.roomName = roomName
        instance.sessionType = SessionInstanceType(rawSessionType: rawType)?.rawValue ?? 0
        instance.startTime = startDate
        instance.endTime = endDate
        instance.keywords.append(objectsIn: keywords)
        
        return .success(instance)
    }
    
}
