//
//  PUITouchBarItems.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 28/04/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension NSTouchBar.CustomizationIdentifier {
    static let player = NSTouchBar.CustomizationIdentifier("Player")
}

extension NSTouchBarItem.Identifier {
    static let playPauseButton = NSTouchBarItem.Identifier("Play/Pause")
    static let scrubber = NSTouchBarItem.Identifier("Scrubber")
    static let goBackInTime = NSTouchBarItem.Identifier("Back")
    static let goForwardInTime = NSTouchBarItem.Identifier("Forward")
    static let previousAnnotation = NSTouchBarItem.Identifier("Previous Annotation")
    static let nextAnnotation = NSTouchBarItem.Identifier("Next Annotation")
    static let speed = NSTouchBarItem.Identifier("Playback Speed")
    static let addAnnotation = NSTouchBarItem.Identifier("Add Annotation")
    static let togglePictureInPicture = NSTouchBarItem.Identifier("Toggle PiP")
    static let toggleFullscreen = NSTouchBarItem.Identifier("Toggle Fullscreen")
    static let exitFullscreen = NSTouchBarItem.Identifier("Exit Fullscreen")
}
