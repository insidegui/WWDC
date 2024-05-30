//
//  Speeds.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 01/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

public enum PUIPlaybackSpeed: RawRepresentable, Identifiable, Hashable {
    public typealias RawValue = Float

    public var id: RawValue { rawValue }

    case slow
    case normal
    case midFast
    case fast
    case faster
    case fastest
    case custom(rate: Float)

    public static var all: [PUIPlaybackSpeed] {
        return [.slow, .normal, .midFast, .fast, .faster, .fastest]
    }

    public init?(rawValue: Float) {
        switch rawValue {
        case 0.5: self = .slow
        case 1: self = .normal
        case 1.25: self = .midFast
        case 1.5: self = .fast
        case 1.75: self = .faster
        case 2: self = .fastest
        default: self = .custom(rate: rawValue)
        }
    }

    public var rawValue: Float {
        switch self {
        case .slow: return 0.5
        case .normal: return 1
        case .midFast: return 1.25
        case .fast: return 1.5
        case .faster: return 1.75
        case .fastest: return 2
        case .custom(let rate): return rate
        }
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
        default:
            return .PUISpeedTwo
        }
    }

    public var previous: PUIPlaybackSpeed {
        /// Wrap around if trying to go back from the first speed.
        guard self != PUIPlaybackSpeed.all.first else { return PUIPlaybackSpeed.all.last ?? .normal }
        return PUIPlaybackSpeed.all.last(where: { $0.rawValue < rawValue }) ?? .normal
    }

    public var next: PUIPlaybackSpeed {
        /// Wrap around if trying to go forward from the last speed.
        guard self != PUIPlaybackSpeed.all.last else { return PUIPlaybackSpeed.all.first ?? .normal }
        return PUIPlaybackSpeed.all.first(where: { $0.rawValue > rawValue }) ?? .normal
    }

    // MARK: Custom Speed Support

    public var isCustom: Bool {
        guard case .custom = self else { return false }
        return true
    }

    public static let minCustomSpeed: Float = 0.25
    public static let maxCustomSpeed: Float = 3.5

    public static func validateCustomSpeed(_ speed: Float) -> Bool {
        speed >= minCustomSpeed && speed <= maxCustomSpeed
    }

    // MARK: Formatting

    static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 2
        return f
    }()

    static let buttonTitleFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    var localizedDescription: String { (Self.formatter.string(from: NSNumber(value: rawValue)) ?? "") + "×" }

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
            prefix = (Self.buttonTitleFormatter.string(from: NSNumber(value: rawValue)) ?? "")
        }

        return prefix 
    }
}
