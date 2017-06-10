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
    case name, color, darkColor, titleColor, lightBGColor, ordinal
    case identifier = "id"

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class TracksJSONAdapter: Adapter {

    typealias InputType = JSON
    typealias OutputType = Track

    func adapt(_ input: JSON) -> Result<Track, AdapterError> {
        guard let identifier = input[TrackKeys.identifier].int else {
            return .error(.missingKey(TrackKeys.identifier))
        }

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

        let track = Track.make(identifier: "\(identifier)",
                                name: name,
                                darkColor: darkColor,
                                lightBackgroundColor: lightBGColor,
                                lightColor: color,
                                titleColor: titleColor)

        track.order = input[TrackKeys.ordinal].intValue

        return .success(track)
    }

}
