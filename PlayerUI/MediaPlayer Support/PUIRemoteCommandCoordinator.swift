//
//  PUIRemoteCommandCoordinator.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 25/04/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import MediaPlayer

final class PUIRemoteCommandCoordinator: NSObject {

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

    var nextTrackHandler: (() -> Void)? {
        didSet {
            updateCommandAvailability()
        }
    }

    var previousTrackHandler: (() -> Void)? {
        didSet {
            updateCommandAvailability()
        }
    }

    var likeHandler: (() -> Void)? {
        didSet {
            updateCommandAvailability()
        }
    }

    var changePlaybackPositionHandler: ((TimeInterval) -> Void)? {
        didSet {
            updateCommandAvailability()
        }
    }

    var changePlaybackRateHandler: ((PUIPlaybackSpeed) -> Void)? {
        didSet {
            updateCommandAvailability()
        }
    }

    override init() {
        super.init()

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

        center.nextTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.nextTrackHandler?() }

            return .success
        }

        center.previousTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.previousTrackHandler?() }

            return .success
        }

        center.likeCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.likeHandler?() }

            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let effectiveEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }

            self?.changePlaybackPositionHandler?(effectiveEvent.positionTime)

            return .success
        }

        center.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let effectiveEvent = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }

            guard let speed = PUIPlaybackSpeed(rawValue: effectiveEvent.playbackRate) else { return .commandFailed }

            self?.changePlaybackRateHandler?(speed)

            return .success
        }

        updateCommandAvailability()
    }

    private func updateCommandAvailability() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)

        perform(#selector(doUpdateCommandAvailability), with: nil, afterDelay: 0)
    }

    @objc private func doUpdateCommandAvailability() {
        let center = MPRemoteCommandCenter.shared()

        center.pauseCommand.isEnabled = pauseHandler != nil
        center.playCommand.isEnabled = playHandler != nil
        center.stopCommand.isEnabled = stopHandler != nil
        center.togglePlayPauseCommand.isEnabled = togglePlayingHandler != nil
        center.nextTrackCommand.isEnabled = nextTrackHandler != nil
        center.previousTrackCommand.isEnabled = previousTrackHandler != nil
        center.likeCommand.isEnabled = likeHandler != nil
        center.changePlaybackPositionCommand.isEnabled = changePlaybackPositionHandler != nil

        if changePlaybackRateHandler != nil {
            center.changePlaybackRateCommand.isEnabled = true
            center.changePlaybackRateCommand.supportedPlaybackRates = PUIPlaybackSpeed.supportedPlaybackRates
        } else {
            center.changePlaybackRateCommand.isEnabled = false
        }

        // Unsupported commands
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
        center.ratingCommand.isEnabled = false
        center.dislikeCommand.isEnabled = false
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.seekForwardCommand.isEnabled = false
        center.seekBackwardCommand.isEnabled = false
        center.bookmarkCommand.isEnabled = false
    }

}
