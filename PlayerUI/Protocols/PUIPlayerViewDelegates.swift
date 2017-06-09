//
//  PUIPlayerViewDelegate.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 01/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

public protocol PUIPlayerViewDelegate: class {

    func playerViewWillEnterPictureInPictureMode(_ playerView: PUIPlayerView)
    func playerViewWillExitPictureInPictureMode(_ playerView: PUIPlayerView, isReturningFromPiP: Bool)
    func playerViewDidSelectAddAnnotation(_ playerView: PUIPlayerView, at timestamp: Double)
    func playerViewDidSelectToggleFullScreen(_ playerView: PUIPlayerView)

}

public protocol PUIPlayerViewAppearanceDelegate: class {

    func playerViewShouldShowTimelineView(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowSubtitlesControl(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowPictureInPictureControl(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowSpeedControl(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowAnnotationControls(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowBackAndForwardControls(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowTimestampLabels(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowExternalPlaybackControls(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowFullScreenButton(_ playerView: PUIPlayerView) -> Bool
    func PlayerViewShouldShowBackAndForward30SecondsButtons(_ playerView: PUIPlayerView) -> Bool

}
