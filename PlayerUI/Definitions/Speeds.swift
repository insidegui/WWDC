//
//  Speeds.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 01/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

public enum PUIPlaybackSpeed: Float {
    case slow = 0.5
    case normal = 1
    case midFast = 1.25
    case fast = 1.5
    case faster = 1.75
    case fastest = 2

    public static var all: [PUIPlaybackSpeed] {
        return [.slow, .normal, .midFast, .fast, .faster, .fastest]
    }

    static var supportedPlaybackRates: [NSNumber] {
        return all.map { NSNumber(value: $0.rawValue) }
    }

    var icon: NSImage {
        switch self {
        case .slow:
            return .PUISpeedHalf
        case .normal:
            return .PUISpeedOne
        case .midFast:
            return .PUISpeedOneAndFourth
        case .fast:
            return .PUISpeedOneAndHalf
        case .faster:
            return .PUISpeedOneAndThreeFourths
        case .fastest:
            return .PUISpeedTwo
        }
    }

    public var previous: PUIPlaybackSpeed {
        guard let index = PUIPlaybackSpeed.all.firstIndex(of: self) else {
            fatalError("Tried to get next speed from nonsensical playback speed \(self). Probably missing in collection.")
        }

        let previousIndex = index - 1 > -1 ? index - 1 : PUIPlaybackSpeed.all.endIndex - 1

        return PUIPlaybackSpeed.all[previousIndex]
    }

    public var next: PUIPlaybackSpeed {
        guard let index = PUIPlaybackSpeed.all.firstIndex(of: self) else {
            fatalError("Tried to get next speed from nonsensical playback speed \(self). Probably missing in collection.")
        }

        let nextIndex = index + 1 < PUIPlaybackSpeed.all.count ? index + 1 : 0

        return PUIPlaybackSpeed.all[nextIndex]
    }
}
