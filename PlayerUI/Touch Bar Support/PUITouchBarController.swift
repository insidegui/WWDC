//
//  PUITouchBarController.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 26/04/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class PUITouchBarController: NSObject {

    weak var playerView: PUIPlayerView?

    init(playerView: PUIPlayerView) {
        self.playerView = playerView

        super.init()
    }

    private var isPlaying: Bool {
        return playerView?.isPlaying == true
    }

    private var playbackSpeed: PUIPlaybackSpeed {
        return playerView?.playbackSpeed ?? .normal
    }

    @available(macOS 10.12.2, *)
    public func makeTouchBar() -> NSTouchBar? {
        guard let playerView = playerView else { return nil }

        let bar = NSTouchBar()

        let skipBackIdentifier: NSTouchBarItem.Identifier = playerView.isConfiguredForBackAndForward30s ? .back30s : .back15s
        let skipForwardIdentifier: NSTouchBarItem.Identifier = playerView.isConfiguredForBackAndForward30s ? .forward30s : .forward15s

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
extension PUITouchBarController: NSTouchBarDelegate {

    private func makeTouchBarButtonItem(with identifier: NSTouchBarItem.Identifier, image: NSImage, action: Selector) -> NSTouchBarItem {
        let button = NSButton(image: image, target: playerView, action: action)

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
                                          action: #selector(PUIPlayerView.togglePlaying))
        case .scrubber:
            break
        case .back30s:
            return makeTouchBarButtonItem(with: identifier,
                                          image: NSImage.PUIBack30s.touchBarImage(with: 0.8),
                                          action: #selector(PUIPlayerView.goBackInTime30))
        case .forward30s:
            return makeTouchBarButtonItem(with: identifier,
                                          image: NSImage.PUIForward30s.touchBarImage(with: 0.8),
                                          action: #selector(PUIPlayerView.goForwardInTime30))
        case .back15s:
            return makeTouchBarButtonItem(with: identifier,
                                          image: NSImage.PUIBack15s.touchBarImage(with: 0.8),
                                          action: #selector(PUIPlayerView.goBackInTime15))
        case .forward15s:
            return makeTouchBarButtonItem(with: identifier,
                                          image: NSImage.PUIForward15s.touchBarImage(with: 0.8),
                                          action: #selector(PUIPlayerView.goForwardInTime15))
        case .previousAnnotation:
            return makeTouchBarButtonItem(with: identifier,
                                          image: .PUIPreviousAnnotation,
                                          action: #selector(PUIPlayerView.previousAnnotation))
        case .nextAnnotation:
            return makeTouchBarButtonItem(with: identifier,
                                          image: .PUINextAnnotation,
                                          action: #selector(PUIPlayerView.nextAnnotation))
        case .extraOptionsGroup:
            let speedItem = makeTouchBarButtonItem(with: .speed,
                                                   image: playbackSpeed.icon,
                                                   action: #selector(PUIPlayerView.toggleSpeed))

            let addAnnotationItem = makeTouchBarButtonItem(with: .addAnnotation,
                                                           image: .PUIAnnotation,
                                                           action: #selector(PUIPlayerView.addAnnotation))

            let togglePictureInPictureItem = makeTouchBarButtonItem(with: .togglePictureInPicture,
                                                                    image: .PUIPictureInPicture,
                                                                    action: #selector(PUIPlayerView.togglePip))

            let toggleFullscreenItem = makeTouchBarButtonItem(with: .toggleFullscreen,
                                                              image: .PUIFullScreen,
                                                              action: #selector(PUIPlayerView.toggleFullscreen))

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
