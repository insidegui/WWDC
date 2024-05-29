//
//  Speeds.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 01/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

public enum PUIPlaybackSpeed: Float, Identifiable {
    public var id: RawValue { rawValue }

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

    private static let descriptionFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 2
        return f
    }()

    var localizedDescription: String { (Self.descriptionFormatter.string(from: NSNumber(value: rawValue)) ?? "") + "×" }

    var buttonTitle: String {
        let prefix: String

        switch rawValue {
        case 0.5:
            prefix = "½"
        case 1:
            prefix = "1"
        case 1.25:
            prefix = "1¼"
        case 1.5:
            prefix = "1½"
        case 1.75:
            prefix = "1¾"
        case 2:
            prefix = "2"
        default:
            prefix = (Self.descriptionFormatter.string(from: NSNumber(value: rawValue)) ?? "")
        }

        return prefix 
    }
}

