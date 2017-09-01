//
//  AVPlayer+Validation.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 30/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import AVFoundation

extension AVPlayer {

    static func validateMediaDurationWithSeconds(_ duration: Double) -> Bool {
        return !duration.isNaN && !duration.isInfinite && !duration.isZero
    }

    static func validateMediaDuration(_ duration: CMTime) -> Bool {
        return validateMediaDurationWithSeconds(Double(CMTimeGetSeconds(duration)))
    }

    var hasValidMediaDuration: Bool {
        guard let item = currentItem else { return false }

        return AVPlayer.validateMediaDuration(item.duration)
    }

}
