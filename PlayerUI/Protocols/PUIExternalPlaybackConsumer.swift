//
//  PUIExternalPlaybackConsumer.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 01/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import AVFoundation

public protocol PUIExternalPlaybackConsumer: class {

    /// Tells the consumer that this provider's availability status has changed
    ///
    /// - Parameter provider: The provider that called the method
    func externalPlaybackProviderDidChangeAvailabilityStatus(_ provider: PUIExternalPlaybackProvider)

    /// Tells the consumer that the provider's media status has changed
    ///
    /// - Parameter provider: The provider that called the method
    func externalPlaybackProviderDidChangeMediaStatus(_ provider: PUIExternalPlaybackProvider)

    /// Tells the consumer that this provider's device selection menu has changed
    ///
    /// - Parameters:
    ///   - provider: The provider that called the method
    ///   - menu: The updated menu to be showed when the provider's icon is clicked
    func externalPlaybackProvider(_ provider: PUIExternalPlaybackProvider, deviceSelectionMenuDidChangeWith menu: NSMenu)

    /// Tells the consumer that the media is now playing on one of the devices offered by the provider
    ///
    /// - Parameter provider: The provider that called the method
    func externalPlaybackProviderDidBecomeCurrent(_ provider: PUIExternalPlaybackProvider)

    /// Tells the consumer that the current playback session for the provider is no longer valid
    ///
    /// - Parameter provider: The provider that called the method
    func externalPlaybackProviderDidInvalidatePlaybackSession(_ provider: PUIExternalPlaybackProvider)

    /// The media for the remote URL to be played by the provider
    var remoteMediaUrl: URL? { get }

    /// The URL for a poster image representing the current media
    var mediaPosterUrl: URL? { get }

    /// The title for the program being played
    var mediaTitle: String? { get }

    /// Whether the current media is a live stream
    var mediaIsLiveStream: Bool { get }

    /// The `AVPlayer` instance the consumer is using to play its media
    var player: AVPlayer? { get }

}
