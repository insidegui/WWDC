//
//  Constants.swift
//  WWDC
//
//  Created by Guilherme Rambo on 10/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct Constants {

    static let coreSchemaVersion: UInt64 = 60

    static let thumbnailHeight: CGFloat = 150

    static let autorefreshInterval: TimeInterval = 5 * 60

    /// Maximum number of videos to list in the "Continue Watching" section.
    static let maxContinueWatchingItems = 10

    /// Videos will only be considered for the "Continue Watching" feature if the current progress is above this limit,
    /// this prevents videos that have basically just had the play button pressed from showing up in continue watching
    static let continueWatchingMinRelativePosition: Double = 0.05

    /// Videos will only be considered for the "Continue Watching" feature if the current progress is below this limit
    static let continueWatchingMaxRelativePosition: Double = 0.9

    /// Videos will only be considered for the "Continue Watching" feature if the current progress was registered
    /// within the past X days, so that videos started a long time ago are not displayed in the section.
    static let continueWatchingMaxLastProgressUpdateInterval = DateComponents(day: -30)

    /// Maximum number of videos to list in the "Recent Favorites" section.
    static let maxRecentFavoritesItems = 20

    /// Videos will only be considered for the "Recent Favorites" feature if the current progress was registered
    static let recentFavoritesMaxDateInterval = DateComponents(day: -30)

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

    /// How long before the scheduled start date for a special event the Explore tab will start showing it on the list.
    static let exploreTabSpecialEventLiveSoonInterval: TimeInterval = 12 * 60 * 60

}
