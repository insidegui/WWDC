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

    @available(macOS 10.12.2, *)
    public func makeTouchBar() -> NSTouchBar? {
        let bar = NSTouchBar()

        bar.customizationIdentifier = .player
        bar.delegate = self
        bar.defaultItemIdentifiers = [
            .goBackInTime,
            .previousAnnotation,
            .playPauseButton,
            .nextAnnotation,
            .goForwardInTime,
            .extraOptionsGroup
        ]

        return bar
    }

    private func makeTouchBarButton(image: NSImage, action: Selector) -> NSButton {
        return NSButton(image: image, target: playerView, action: action)
    }

    @available(macOS 10.12.2, *)
    private func makeTouchBarButtonItem(with identifier: NSTouchBarItem.Identifier, button: NSButton) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)

        item.view = button

        return item
    }

    // MARK: - State Management

    private var isPlaying: Bool {
        return playerView?.isPlaying == true
    }

    private var playbackSpeed: PUIPlaybackSpeed {
        return playerView?.playbackSpeed ?? .normal
    }

    private var playPauseButtonImage: NSImage {
        let image: NSImage = isPlaying ? .PUIPause : .PUIPlay

        return image.touchBarImage(with: 0.5)
    }

    private var goBackImage: NSImage {
        let image = playerView?.goBackInTimeImage ?? .PUIBack15s

        return image.touchBarImage(with: 0.8)
    }

    private var goForwardImage: NSImage {
        let image = playerView?.goForwardInTimeImage ?? .PUIForward15s

        return image.touchBarImage(with: 0.8)
    }

    func invalidate() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)

        perform(#selector(doInvalidate), with: nil, afterDelay: 0)
    }

    @objc private func doInvalidate() {
        playPauseButton.image = playPauseButtonImage
        backButton.image = goBackImage
        forwardButton.image = goForwardImage
        speedButton.image = playbackSpeed.icon
    }

    // MARK: - Controls

    private lazy var playPauseButton: NSButton = {
        return makeTouchBarButton(image: playPauseButtonImage, action: #selector(PUIPlayerView.togglePlaying))
    }()

    private lazy var backButton: NSButton = {
        return makeTouchBarButton(image: goBackImage, action: #selector(PUIPlayerView.goBackInTime))
    }()

    private lazy var forwardButton: NSButton = {
        return makeTouchBarButton(image: goForwardImage, action: #selector(PUIPlayerView.goForwardInTime))
    }()

    private lazy var previousAnnotationButton: NSButton = {
        return makeTouchBarButton(image: .PUIPreviousAnnotation, action: #selector(PUIPlayerView.previousAnnotation))
    }()

    private lazy var nextAnnotationButton: NSButton = {
        return makeTouchBarButton(image: .PUINextAnnotation, action: #selector(PUIPlayerView.nextAnnotation))
    }()

    private lazy var speedButton: NSButton = {
        return makeTouchBarButton(image: playbackSpeed.icon, action: #selector(PUIPlayerView.toggleSpeed))
    }()

    private lazy var addAnnotationButton: NSButton = {
        return makeTouchBarButton(image: .PUIAnnotation, action: #selector(PUIPlayerView.addAnnotation))
    }()

    private lazy var togglePictureInPictureButton: NSButton = {
        return makeTouchBarButton(image: .PUIPictureInPicture, action: #selector(PUIPlayerView.togglePip))
    }()

    private lazy var toggleFullscreenButton: NSButton = {
        return makeTouchBarButton(image: .PUIFullScreen, action: #selector(PUIPlayerView.toggleFullscreen))
    }()

}

// MARK: - Touch Bar Delegate

@available(macOS 10.12.2, *)
extension PUITouchBarController: NSTouchBarDelegate {

    public func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .playPauseButton:
            return makeTouchBarButtonItem(with: identifier, button: playPauseButton)
        case .scrubber:
            break
        case .goBackInTime:
            return makeTouchBarButtonItem(with: identifier, button: backButton)
        case .goForwardInTime:
            return makeTouchBarButtonItem(with: identifier, button: forwardButton)
        case .previousAnnotation:
            return makeTouchBarButtonItem(with: identifier, button: previousAnnotationButton)
        case .nextAnnotation:
            return makeTouchBarButtonItem(with: identifier, button: nextAnnotationButton)
        case .extraOptionsGroup:
            let items: [NSTouchBarItem] = [
                makeTouchBarButtonItem(with: .speed, button: speedButton),
                makeTouchBarButtonItem(with: .addAnnotation, button: addAnnotationButton),
                makeTouchBarButtonItem(with: .togglePictureInPicture, button: togglePictureInPictureButton),
                makeTouchBarButtonItem(with: .toggleFullscreen, button: toggleFullscreenButton)
            ]

            return NSGroupTouchBarItem(identifier: identifier, items: items)
        default: return nil
        }

        return nil
    }

}
