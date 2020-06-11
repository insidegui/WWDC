//
//  Constants.swift
//  WWDC
//
//  Created by Guilherme Rambo on 10/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct Constants {

    static let coreSchemaVersion: UInt64 = 55

    static let thumbnailHeight: CGFloat = 150

    static let autorefreshInterval: TimeInterval = 5 * 60

    /// The relative position within the video the user must be before it is considered fully watched
    static let watchedVideoRelativePosition: Double = 0.97

    /// How many seconds between each live session check
    static let liveSessionCheckInterval: TimeInterval = 60.0

    /// How many seconds of tolerance to give the live session check timer
    static let liveSessionCheckTolerance: TimeInterval = 30.0

    /// How many MINUTES to subtract from the start time of a live session to consider it live
    static let liveSessionStartTimeTolerance: Int = 3

    /// How many MINUTES to add to the end time of a live session to consider it not live anymore
    static let liveSessionEndTimeTolerance: Int = 30

}
