//
//  PUIRemoteCommandCoordinator.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 25/04/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import MediaPlayer

final class PUIRemoteCommandCoordinator {

    var pauseHandler: (() -> Void)? {
        didSet {
            updateCommandAvailability()
        }
    }

    var playHandler: (() -> Void)? {
        didSet {
            updateCommandAvailability()
        }
    }

    var stopHandler: (() -> Void)? {
        didSet {
            updateCommandAvailability()
        }
    }

    var togglePlayingHandler: (() -> Void)? {
        didSet {
            updateCommandAvailability()
        }
    }

    var skipForwardHandler: (() -> Void)? {
        didSet {
            updateCommandAvailability()
        }
    }

    var skipBackwardHandler: (() -> Void)? {
        didSet {
            updateCommandAvailability()
        }
    }

    var likeHandler: (() -> Void)? {
        didSet {
            updateCommandAvailability()
        }
    }

    init() {
        guard #available(macOS 10.12.2, *) else { return }

        let center = MPRemoteCommandCenter.shared()

        center.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.pauseHandler?() }

            return .success
        }

        center.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.playHandler?() }

            return .success
        }

        center.stopCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.stopHandler?() }

            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.togglePlayingHandler?() }

            return .success
        }

        center.skipForwardCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.skipForwardHandler?() }

            return .success
        }

        center.skipBackwardCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.skipBackwardHandler?() }

            return .success
        }

        center.likeCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.likeHandler?() }

            return .success
        }

        updateCommandAvailability()
    }

    private func updateCommandAvailability() {
        guard #available(macOS 10.12.2, *) else { return }

        let center = MPRemoteCommandCenter.shared()

        center.pauseCommand.isEnabled = pauseHandler != nil
        center.playCommand.isEnabled = playHandler != nil
        center.stopCommand.isEnabled = stopHandler != nil
        center.togglePlayPauseCommand.isEnabled = togglePlayingHandler != nil
        center.skipForwardCommand.isEnabled = skipForwardHandler != nil
        center.skipBackwardCommand.isEnabled = skipBackwardHandler != nil
        center.likeCommand.isEnabled = likeHandler != nil

        // Unsupported commands
        center.changePlaybackRateCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false
        center.ratingCommand.isEnabled = false
        center.dislikeCommand.isEnabled = false
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.seekForwardCommand.isEnabled = false
        center.seekBackwardCommand.isEnabled = false
        center.bookmarkCommand.isEnabled = false
    }

}
