//
//  AVAsset+AsyncHelpers.swift
//  PlayerUI
//
//  Created by Allen Humphreys on 25/6/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import AVFoundation

extension AVAsset {

    public var durationIfLoaded: CMTime? {

        let error: NSErrorPointer = nil
        let durationStatus = status(of: .duration)

        switch durationStatus {
        case .loaded(let time):
            return time
        case .failed, .notYetLoaded, .loading:
            return nil
        }
    }
}
