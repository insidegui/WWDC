//
//  PUINowPlayingInfo.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 22/04/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa
import MediaPlayer

public struct PUINowPlayingInfo {

    public var title: String
    public var artist: String
    public var progress: Double
    public var isLive: Bool
    public var image: NSImage?

    public init(title: String, artist: String, progress: Double = 0, isLive: Bool = false, image: NSImage? = nil) {
        self.title = title
        self.artist = artist
        self.progress = progress
        self.isLive = isLive
        self.image = image
    }

}

extension PUINowPlayingInfo {

    var dictionaryRepresentation: [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist
        ]

        info[MPNowPlayingInfoPropertyPlaybackProgress] = progress
        info[MPNowPlayingInfoPropertyIsLiveStream] = isLive

        if let image = self.image {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ in image })
        }

        return info
    }

}
