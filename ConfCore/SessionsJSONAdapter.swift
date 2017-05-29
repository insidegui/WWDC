//
//  SessionsJSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 15/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum SessionKeys: String, JSONSubscriptType {
    case id, year, title, track, focus, description, startGMT
    
    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class SessionsJSONAdapter: Adapter {
    
    typealias InputType = JSON
    typealias OutputType = Session
    
    func adapt(_ input: JSON) -> Result<Session, AdapterError> {
        guard let id = input[SessionKeys.id].string else {
            return .error(.missingKey(SessionKeys.id))
        }
        
        var eventYear = ""
        
        if let year = input[SessionKeys.year].int {
            eventYear = "\(year)"
        } else if let startGMT = input[SessionKeys.startGMT].string {
            guard let year = startGMT.components(separatedBy: "-").first else {
                return .error(.missingKey(SessionKeys.year))
            }
            
            eventYear = year
        }
        
        let identifier = "\(eventYear)-\(id)"
        let eventIdentifier = "wwdc\(eventYear)"
        
        guard let title = input[SessionKeys.title].string else {
            return .error(.missingKey(SessionKeys.title))
        }

        guard let summary = input[SessionKeys.description].string else {
            return .error(.missingKey(SessionKeys.description))
        }
        
        guard let trackName = input[SessionKeys.track].string else {
            return .error(.missingKey(SessionKeys.track))
        }
        
        guard let focusesJson = input[SessionKeys.focus].array else {
            return .error(.missingKey(SessionKeys.focus))
        }
        
        guard case .success(let focuses) = FocusesJSONAdapter().adapt(focusesJson) else {
            return .error(.invalidData)
        }
        
        let session = Session()
        
        session.identifier = identifier
        session.year = Int(eventYear) ?? -1
        session.number = id
        session.title = title
        session.summary = summary
        session.trackName = trackName
        session.focuses.append(objectsIn: focuses)
        session.eventIdentifier = eventIdentifier
        
        return .success(session)
    }
    
}
