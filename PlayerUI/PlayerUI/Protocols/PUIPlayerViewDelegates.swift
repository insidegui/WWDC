//
//  PUIPlayerViewDelegate.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 01/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

public protocol PUIPlayerViewDelegate: class {
    
    func playerViewDidSelectAddAnnotation(_ playerView: PUIPlayerView, from view: NSView?)
    func playerViewDidSelectTogglePiP(_ playerView: PUIPlayerView)
    
}

public protocol PUIPlayerViewAppearanceDelegate: class {
    
    func playerViewShouldShowSubtitlesControl(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowPictureInPictureControl(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowSpeedControl(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowAnnotationControls(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowBackAndForwardControls(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowExternalPlaybackControls(_ playerView: PUIPlayerView) -> Bool
    func playerViewShouldShowFullScreenButton(_ playerView: PUIPlayerView) -> Bool
    
}
