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

    // MARK: - Static Functions

    static func validateMediaDurationWithSeconds(_ duration: Double) -> Bool {
        return !duration.isNaN && !duration.isInfinite && !duration.isZero
    }

    static func validateMediaDuration(_ duration: CMTime) -> Bool {
        return validateMediaDurationWithSeconds(Double(CMTimeGetSeconds(duration)))
    }

    // MARK: - Public Properties

    var hasValidMediaDuration: Bool {
        guard let duration = currentItem?.asset.durationIfLoaded else { return false }

        return AVPlayer.validateMediaDuration(duration)
    }

    var hasFinishedPlaying: Bool {
        let currentTimeSeconds = currentTime().seconds
        guard let durationSeconds =  currentItem?.asset.durationIfLoaded?.seconds else { return false }

        return abs(currentTimeSeconds - durationSeconds) < 1
    }
}
