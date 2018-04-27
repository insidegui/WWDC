//
//  PUIPlayerView+TouchBar.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 26/04/18.
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

@available(macOS 10.12.2, *)
extension PUIPlayerView {

    public override func makeTouchBar() -> NSTouchBar? {
        let bar = NSTouchBar()

        let skipBackIdentifier: NSTouchBarItem.Identifier = isConfiguredForBackAndForward30s ? .back30s : .back15s
        let skipForwardIdentifier: NSTouchBarItem.Identifier = isConfiguredForBackAndForward30s ? .forward30s : .forward15s

        let identifiers: [NSTouchBarItem.Identifier] = [
            skipBackIdentifier,
            .previousAnnotation,
            .playPauseButton,
            .nextAnnotation,
            skipForwardIdentifier,
            .extraOptionsGroup
        ]

        bar.customizationIdentifier = .player
        bar.defaultItemIdentifiers = identifiers
        bar.delegate = self

        return bar
    }

}

@available(macOS 10.12.2, *)
extension PUIPlayerView: NSTouchBarDelegate {

    private func makeTouchBarButtonItem(with identifier: NSTouchBarItem.Identifier, image: NSImage, action: Selector) -> NSTouchBarItem {
        let button = NSButton(image: image, target: self, action: action)

        let item = NSCustomTouchBarItem(identifier: identifier)

        item.view = button

        return item
    }

    private var playPauseButtonImage: NSImage {
        return isPlaying ? .PUIPause : .PUIPlay
    }

    public func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .playPauseButton:
            return makeTouchBarButtonItem(with: identifier,
                                          image: playPauseButtonImage.touchBarImage(with: 0.5),
                                          action: #selector(togglePlaying))
        case .scrubber:
            break
        case .back30s:
            return makeTouchBarButtonItem(with: identifier,
                                          image: NSImage.PUIBack30s.touchBarImage(with: 0.8),
                                          action: #selector(goBackInTime30))
        case .forward30s:
            return makeTouchBarButtonItem(with: identifier,
                                          image: NSImage.PUIForward30s.touchBarImage(with: 0.8),
                                          action: #selector(goForwardInTime30))
        case .back15s:
            return makeTouchBarButtonItem(with: identifier,
                                          image: NSImage.PUIBack15s.touchBarImage(with: 0.8),
                                          action: #selector(goBackInTime15))
        case .forward15s:
            return makeTouchBarButtonItem(with: identifier,
                                          image: NSImage.PUIForward15s.touchBarImage(with: 0.8),
                                          action: #selector(goForwardInTime15))
        case .previousAnnotation:
            return makeTouchBarButtonItem(with: identifier,
                                          image: .PUIPreviousAnnotation,
                                          action: #selector(previousAnnotation))
        case .nextAnnotation:
            return makeTouchBarButtonItem(with: identifier,
                                          image: .PUINextAnnotation,
                                          action: #selector(nextAnnotation))
        case .extraOptionsGroup:
            let speedItem = makeTouchBarButtonItem(with: .speed,
                                                   image: playbackSpeed.icon,
                                                   action: #selector(toggleSpeed))

            let addAnnotationItem = makeTouchBarButtonItem(with: .addAnnotation,
                                                           image: .PUIAnnotation,
                                                           action: #selector(addAnnotation))

            let togglePictureInPictureItem = makeTouchBarButtonItem(with: .togglePictureInPicture,
                                                                    image: .PUIPictureInPicture,
                                                                    action: #selector(togglePip))

            let toggleFullscreenItem = makeTouchBarButtonItem(with: .toggleFullscreen,
                                                              image: .PUIFullScreen,
                                                              action: #selector(toggleFullscreen))

            let items: [NSTouchBarItem] = [
                speedItem,
                addAnnotationItem,
                toggleFullscreenItem,
                togglePictureInPictureItem
            ]

            return NSGroupTouchBarItem(identifier: identifier, items: items)
        default: return nil
        }

        return nil
    }

}
