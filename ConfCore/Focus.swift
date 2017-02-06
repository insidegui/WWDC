//
//  Focus.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Focuses are basically platform names (ex: "macOS", "iOS")
class Focus: Object {

    /// The name of the focus area
    dynamic var name = ""
    
    /// Sessions containing this focus
    let sessions = List<Session>()
    
    override class func primaryKey() -> String? {
        return "name"
    }
    
}
