//
//  RoomsJSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 08/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum RoomKeys: String, JSONSubscriptType {
    case name, mapName, floor
    
    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class RoomsJSONAdapter: Adapter {
    typealias InputType = JSON
    typealias OutputType = Room
    
    func adapt(_ input: JSON) -> Result<Room, AdapterError> {
        guard let name = input[RoomKeys.name].string else {
            return .error(.missingKey(RoomKeys.name))
        }
        
        guard let mapName = input[RoomKeys.mapName].string else {
            return .error(.missingKey(RoomKeys.mapName))
        }
        
        guard let floor = input[RoomKeys.floor].string else {
            return .error(.missingKey(RoomKeys.floor))
        }
        
        let room = Room.make(name: name, mapName: mapName, floor: floor)
        
        return .success(room)
    }
}
