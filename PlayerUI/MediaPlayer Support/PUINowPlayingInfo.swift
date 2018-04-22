//
//  PUINowPlayingInfo.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 22/04/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import MediaPlayer

public struct PUINowPlayingInfo {

    public var title: String
    public var artist: String
    public var progress: Double

    public init(title: String, artist: String, progress: Double = 0) {
        self.title = title
        self.artist = artist
        self.progress = progress
    }

}

extension PUINowPlayingInfo {

    var dictionaryRepresentation: [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist
        ]

        if #available(OSX 10.12.2, *) {
            info[MPNowPlayingInfoPropertyPlaybackProgress] = progress
        }

        return info
    }

}
