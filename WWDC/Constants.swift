//
//  Constants.swift
//  WWDC
//
//  Created by Guilherme Rambo on 10/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct Constants {

    static let coreSchemaVersion: UInt64 = 44

    static let thumbnailHeight: CGFloat = 150

    static let autorefreshInterval: TimeInterval = 5 * 60

    /// The relative position within the video the user must be before it is considered fully watched
    static let watchedVideoRelativePosition: Double = 0.97

    /// How many seconds between each live session check
    static let liveSessionCheckInterval: TimeInterval = 10.0

    /// How many seconds to subtract from the start time of a live session to consider it live
    static let liveSessionStartTimeTolerance: TimeInterval = 300

    /// Whether to enable the new "Featured" tab
    static let isFeaturedTabEnabled = false

}
