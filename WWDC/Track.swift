//
//  Track.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import SwiftyJSON

//"color":
//"#9E9E9E",
//"darkColor":
//"#32353D",
//"lightBGColor":
//"#32353D",
//"name":
//"Featured",
//"titleColor":
//"#D9D9DD"

class Track: Object {
    
    dynamic var name = ""
    dynamic var titleColor = ""
    dynamic var color = ""
    dynamic var darkColor = ""
    dynamic var lightBGColor = ""
    
    let scheduledSessions = LinkingObjects(fromType: ScheduledSession.self, property: "track")
    
    convenience required init(json: JSON) {
        self.init()
        
        self.name = json["name"].stringValue
        self.titleColor = json["titleColor"].stringValue
        self.color = json["color"].stringValue
        self.darkColor = json["darkColor"].stringValue
        self.lightBGColor = json["lightBGColor"].stringValue
    }
    
    override static func primaryKey() -> String? {
        return "name"
    }
    
    override static func indexedProperties() -> [String] {
        return ["name"]
    }
    
}