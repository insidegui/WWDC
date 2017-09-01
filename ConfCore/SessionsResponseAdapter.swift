//
//  SessionsResponseAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum SessionResponseKeys: String, JSONSubscriptType {
    case events, sessions
    
    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class SessionsResponseAdapter: Adapter {

    typealias InputType = JSON
    typealias OutputType = SessionsResponse

    func adapt(_ input: JSON) -> Result<SessionsResponse, AdapterError> {
        return .error(.invalidData)
//        guard let eventsJson = input[SessionResponseKeys.events].array else {
//            return .error(.missingKey(SessionResponseKeys.events))
//        }
//        
//        guard let sessionsJson = input[SessionResponseKeys.sessions].array else {
//            return .error(.missingKey(SessionResponseKeys.sessions))
//        }
//        
//        guard case .success(let events) = EventsJSONAdapter().adapt(eventsJson) else {
//            return .error(.invalidData)
//        }
//        
//        guard case .success(let sessions) = SessionsJSONAdapter().adapt(sessionsJson) else {
//            return .error(.invalidData)
//        }
//        
//        guard case .success(let assets) = SessionAssetsJSONAdapter().adapt(sessionsJson) else {
//            return .error(.invalidData)
//        }
//        
//        var trackNames = Set<String>()
//        
//        sessions.forEach { session in
//            guard !trackNames.contains(session.trackName) else { return }
//            trackNames.insert(session.trackName)
//        }
//        
//        let tracks: [Track] = trackNames.map { name in
//            let track = Track()
//            
//            track.name = name
//            
//            return track
//        }
//        
//        let response = SessionsResponse(events: events, sessions: sessions, assets: assets.flatMap({$0}), tracks: tracks)
//        
//        return .success(response)
    }
    
}
