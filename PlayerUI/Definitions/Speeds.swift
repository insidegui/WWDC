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
    case fastest = 2

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
        case .fastest:
            return .PUISpeedTwo
        }
    }

    private var all: [PUIPlaybackSpeed] {
        return [.slow, .normal, .midFast, .fast, .fastest]
    }

    public var next: PUIPlaybackSpeed {
        guard let idx = all.index(of: self) else {
            fatalError("Tried to get next speed from nonsensical playback speed \(self). Probably missing in collection.")
        }

        let nextIdx = idx + 1 < all.count ? idx + 1 : 0

        return all[nextIdx]
    }
}
