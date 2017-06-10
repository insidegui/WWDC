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
    case identifier = "id"

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class RoomsJSONAdapter: Adapter {
    typealias InputType = JSON
    typealias OutputType = Room

    func adapt(_ input: JSON) -> Result<Room, AdapterError> {
        guard let identifier = input[RoomKeys.identifier].int else {
            return .error(.missingKey(RoomKeys.identifier))
        }

        guard let name = input[RoomKeys.name].string else {
            return .error(.missingKey(RoomKeys.name))
        }

        let room = Room.make(identifier: "\(identifier)", name: name, mapName: "", floor: "")

        return .success(room)
    }
}
