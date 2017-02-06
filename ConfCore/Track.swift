//
//  Track.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Tracks represent a specific are of interest (ex: "System Frameworks", "Graphics and Games")
class Track: Object {

    /// The order to display in lists
    dynamic var displayOrder = 0
    
    /// The name of the track
    dynamic var name = ""
    
    /// Dark theme color
    dynamic var darkColor = ""
    
    /// Color for light backgrounds
    dynamic var lightBackgroundColor = ""
    
    /// Color for light contexts
    dynamic var lightColor = ""
    
    /// Theme title color
    dynamic var titleColor = ""
    
    /// Sessions related to this track
    let sessions = List<Session>()
    
    override class func primaryKey() -> String? {
        return "name"
    }
    
}
