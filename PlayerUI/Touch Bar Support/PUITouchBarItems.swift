//
//  PUITouchBarItems.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 28/04/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa

@available(macOS 10.12.2, *)
extension NSTouchBar.CustomizationIdentifier {
    static let player = NSTouchBar.CustomizationIdentifier("Player")
}

@available(macOS 10.12.2, *)
extension NSTouchBarItem.Identifier {
    static let playPauseButton = NSTouchBarItem.Identifier("Play or Pause Button")
    static let scrubber = NSTouchBarItem.Identifier("Scrubber")
    static let back30s = NSTouchBarItem.Identifier("Back 30 seconds")
    static let forward30s = NSTouchBarItem.Identifier("Forward 30 seconds")
    static let back15s = NSTouchBarItem.Identifier("Back 15 seconds")
    static let forward15s = NSTouchBarItem.Identifier("Forward 15 seconds")
    static let previousAnnotation = NSTouchBarItem.Identifier("Previous Annotation")
    static let nextAnnotation = NSTouchBarItem.Identifier("Next Annotation")
    static let speed = NSTouchBarItem.Identifier("Playback Speed")
    static let addAnnotation = NSTouchBarItem.Identifier("Add Annotation")
    static let togglePictureInPicture = NSTouchBarItem.Identifier("Toggle Picture in Picture")
    static let toggleFullscreen = NSTouchBarItem.Identifier("Toggle Fullscreen")
    static let extraOptionsGroup = NSTouchBarItem.Identifier("Extra Options")
}

