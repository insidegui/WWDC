//
//  AVAsset+AsyncHelpers.swift
//  PlayerUI
//
//  Created by Allen Humphreys on 6/25/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import AVFoundation

extension AVAsset {

    public var durationIfLoaded: CMTime? {

        let error: NSErrorPointer = nil
        let durationStatus = statusOfValue(forKey: "duration", error: error)

        guard durationStatus == .loaded, error?.pointee == nil else { return nil }

        return duration
    }
}
