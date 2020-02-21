//
//  Constants.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 21/02/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

public struct Constants {

    public static let coreSchemaVersion: UInt64 = 44

    public static let thumbnailHeight: CGFloat = 150

    public static let autorefreshInterval: TimeInterval = 5 * 60

    /// The relative position within the video the user must be before it is considered fully watched
    public static let watchedVideoRelativePosition: Double = 0.97

    /// How many seconds between each live session check
    public static let liveSessionCheckInterval: TimeInterval = 60.0

    /// How many seconds of tolerance to give the live session check timer
    public static let liveSessionCheckTolerance: TimeInterval = 30.0

    /// How many MINUTES to subtract from the start time of a live session to consider it live
    public static let liveSessionStartTimeTolerance: Int = 3

}
