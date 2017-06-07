//
//  ScheduleSection.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// A section from the schedule, representing a time slot of the conference
public final class ScheduleSection: Object {
    
    public dynamic var identifier: String = ""
    public dynamic var eventIdentifier: String = ""
    public dynamic var representedDate: Date = .distantPast
    public let instances = List<SessionInstance>()
    
    public override class func primaryKey() -> String {
        return "identifier"
    }
    
    public override static func indexedProperties() -> [String] {
        return [
            "identifier",
            "eventIdentifier",
            "representedDate"
        ]
    }
    
    internal static var identifierFormatter: DateFormatter {
        let f = DateFormatter()
        
        f.dateFormat = "MM-dd-yyyy'@'HH:mm"
        
        return f
    }
    
}
