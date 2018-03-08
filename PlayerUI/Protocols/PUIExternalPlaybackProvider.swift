//
//  PUIExternalPlaybackProvider.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 01/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

public struct PUIExternalPlaybackMediaStatus {

    /// The rate at which the media is playing (1 = playing. 0 = paused)
    public var rate: Float

    /// The current timestamp the media is playing at (in seconds)
    public var currentTime: Double

    /// The volume on the external device (between 0 and 1)
    public var volume: Float

    public init(rate: Float = 0, volume: Float = 1, currentTime: Double = 0) {
        self.rate = rate
        self.volume = volume
        self.currentTime = currentTime
    }

}

public protocol PUIExternalPlaybackProvider: class {

    /// Initializes the external playback provider to start playing the media at the specified URL
    ///
    /// - Parameter consumer: The consumer that's going to be using this provider
    init(consumer: PUIExternalPlaybackConsumer)

    /// Whether this provider only works with a remote URL or can be used with only the `AVPlayer` instance
    var requiresRemoteMediaUrl: Bool { get }

    /// The name of the external playback system (ex: "AirPlay")
    static var name: String { get }

    /// An image to be used as the icon in the UI
    var icon: NSImage { get }

    /// A larger image to be used when the provider is current
    var image: NSImage { get }

    /// The current media status
    var status: PUIExternalPlaybackMediaStatus { get }

    /// Extra information to be displayed on-screen when this playback provider is current
    var info: String { get }

    /// Return whether this playback system is available
    var isAvailable: Bool { get }

    /// Tells the external playback provider to play
    func play()

    /// Tells the external playback provider to pause
    func pause()

    /// Tells the external playback provider to seek to the specified time (in seconds)
    func seek(to timestamp: Double)

    /// Tells the external playback provider to change the volume on the device
    ///
    /// - Parameter volume: The volume (value between 0 and 1)
    func setVolume(_ volume: Float)

}
