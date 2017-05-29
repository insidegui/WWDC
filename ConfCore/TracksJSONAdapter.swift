//
//  TracksJSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 08/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum TrackKeys: String, JSONSubscriptType {
    case name, color, darkColor, titleColor, lightBGColor
    
    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class TracksJSONAdapter: Adapter {
    
    typealias InputType = JSON
    typealias OutputType = Track
    
    func adapt(_ input: JSON) -> Result<Track, AdapterError> {
        guard let name = input[TrackKeys.name].string else {
            return .error(.missingKey(TrackKeys.name))
        }
        
        guard let color = input[TrackKeys.color].string else {
            return .error(.missingKey(TrackKeys.color))
        }
        
        guard let darkColor = input[TrackKeys.darkColor].string else {
            return .error(.missingKey(TrackKeys.darkColor))
        }
        
        guard let titleColor = input[TrackKeys.titleColor].string else {
            return .error(.missingKey(TrackKeys.titleColor))
        }
        
        guard let lightBGColor = input[TrackKeys.lightBGColor].string else {
            return .error(.missingKey(TrackKeys.lightBGColor))
        }
        
        let track = Track.make(name: name,
                               darkColor: darkColor,
                               lightBackgroundColor: lightBGColor,
                               lightColor: color,
                               titleColor: titleColor)
        
        return .success(track)
    }
    
}
