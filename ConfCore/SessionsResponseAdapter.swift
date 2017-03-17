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
        guard let eventsJson = input[SessionResponseKeys.events].array else {
            return .error(.missingKey(SessionResponseKeys.events))
        }
        
        guard let sessionsJson = input[SessionResponseKeys.sessions].array else {
            return .error(.missingKey(SessionResponseKeys.sessions))
        }
        
        guard case .success(let events) = EventsJSONAdapter().adapt(eventsJson) else {
            return .error(.invalidData)
        }
        
        guard case .success(let sessions) = SessionsJSONAdapter().adapt(sessionsJson) else {
            return .error(.invalidData)
        }
        
        guard case .success(let assets) = SessionAssetsJSONAdapter().adapt(sessionsJson) else {
            return .error(.invalidData)
        }
        
        events.forEach { event in
            let eventSessions = sessions.filter({ $0.eventIdentifier == event.identifier })
            
            event.sessions.append(objectsIn: eventSessions)
        }
        
        sessions.forEach { session in
            let components = session.identifier.components(separatedBy: "-")
            guard components.count == 2 else { return }
            guard let year = Int(components[0]) else { return }
            
            let sessionAssets = assets.flatMap({ $0 }).filter({ $0.year == year && $0.sessionId == components[1] })
            session.assets.append(objectsIn: sessionAssets)
        }
        
        let response = SessionsResponse(events: events, sessions: sessions, assets: assets.flatMap({$0}))
        
        return .success(response)
    }
    
}
