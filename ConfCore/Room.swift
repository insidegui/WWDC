//
//  Room.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Represents a room or venue where sessions are held
class Room: Object {
    
    /// Name of the map file (maps are not present in the macOS app because they are embedded in the iOS app's binary, not given by the API)
    dynamic var mapName = ""
    
    /// Name of the room
    dynamic var name = ""
    
    /// Room floor name
    dynamic var floor = ""
    
    /// Session instances held at this room
    let instances = List<SessionInstance>()
    
    override class func primaryKey() -> String? {
        return "name"
    }
    
    static func make(name: String, mapName: String, floor: String) -> Room {
        let room = Room()
        
        room.name = name
        room.mapName = mapName
        room.floor = floor
        
        return room
    }
    
}
