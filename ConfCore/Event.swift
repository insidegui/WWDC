//
//  Event.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Represents a past, present or future WWDC edition (ex: WWDC-2016)
class Event: Object {

    /// Unique identifier
    dynamic var identifier = ""
    
    /// Event name
    dynamic var name = ""
    
    /// When the event starts
    dynamic var startDate = Date.distantPast
    
    /// When the event ends
    dynamic var endDate = Date.distantPast
    
    /// Is this the current event?
    dynamic var isCurrent = false
    
    /// Sessions held at this event
    let sessions = List<Session>()
    
    override class func primaryKey() -> String? {
        return "identifier"
    }
    
    static func make(identifier: String, name: String, startDate: Date, endDate: Date, isCurrent: Bool) -> Event {
        let event = Event()
        
        event.identifier = identifier
        event.name = name
        event.startDate = startDate
        event.endDate = endDate
        event.isCurrent = isCurrent
        
        return event
    }
    
}
