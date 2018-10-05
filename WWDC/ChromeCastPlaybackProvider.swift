//
//  ChromeCastPlaybackProvider.swift
//  WWDC
//
//  Created by Guilherme Rambo on 03/06/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ChromeCastCore
import PlayerUI
import CoreMedia
import os.log

private struct ChromeCastConstants {
    static let defaultHost = "devstreaming-cdn.apple.com"
    static let chromeCastSupportedHost = "devstreaming.apple.com"
    static let placeholderImageURL = URL(string: "https://wwdc.io/images/placeholder.jpg")!
}

private extension URL {

    /// The default host returned by Apple's WWDC app has invalid headers for ChromeCast streaming,
    /// this rewrites the URL to use another host which returns a valid response for the ChromeCast device
    /// Calling this on a non-streaming URL doesn't change the URL
    var chromeCastSupportedURL: URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }

        if components.host == ChromeCastConstants.defaultHost {
            components.scheme = "http"
            components.host = ChromeCastConstants.chromeCastSupportedHost
        }

        return components.url
    }

}

final class ChromeCastPlaybackProvider: PUIExternalPlaybackProvider {

    fileprivate weak var consumer: PUIExternalPlaybackConsumer?

    private lazy var scanner: CastDeviceScanner = CastDeviceScanner()

    private let log = OSLog(subsystem: "WWDC", category: "ChromeCastPlaybackProvider")

    /// Initializes the external playback provider to start playing the media at the specified URL
    ///
    /// - Parameter consumer: The consumer that's going to be using this provider
    init(consumer: PUIExternalPlaybackConsumer) {
        self.consumer = consumer
        status = PUIExternalPlaybackMediaStatus()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(deviceListDidChange),
                                               name: CastDeviceScanner.DeviceListDidChange,
                                               object: scanner)

        scanner.startScanning()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Whether this provider only works with a remote URL or can be used with only the `AVPlayer` instance
    var requiresRemoteMediaUrl: Bool {
        return true
    }

    /// The name of the external playback system (ex: "AirPlay")
    static var name: String {
        return "ChromeCast"
    }

    /// An image to be used as the icon in the UI
    var icon: NSImage {
        return #imageLiteral(resourceName: "chromecast")
    }

    var image: NSImage {
        return #imageLiteral(resourceName: "chromecast-large")
    }

    var info: String {
        return "To control playback, use the Google Home app on your phone"
    }

    /// The current media status
    var status: PUIExternalPlaybackMediaStatus

    /// Return whether this playback system is available
    var isAvailable: Bool = false

    /// Tells the external playback provider to play
    func play() {

    }

    /// Tells the external playback provider to pause
    func pause() {

    }

    /// Tells the external playback provider to seek to the specified time (in seconds)
    func seek(to timestamp: Double) {

    }

    /// Tells the external playback provider to change the volume on the device
    ///
    /// - Parameter volume: The volume (value between 0 and 1)
    func setVolume(_ volume: Float) {

    }

    // MARK: - ChromeCast management

    fileprivate var client: CastClient?
    fileprivate var mediaPlayerApp: CastApp?
    fileprivate var currentSessionId: Int?
    fileprivate var mediaStatusRefreshTimer: Timer?

    @objc private func deviceListDidChange() {
        isAvailable = scanner.devices.count > 0

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        scanner.devices.forEach { device in
            let item = NSMenuItem(title: device.name, action: #selector(didSelectDeviceOnMenu), keyEquivalent: "")
            item.representedObject = device
            item.target = self

            if device.hostName == selectedDevice?.hostName {
                item.state = .on
            }

            menu.addItem(item)
        }

        // send menu to consumer
        consumer?.externalPlaybackProvider(self, deviceSelectionMenuDidChangeWith: menu)
    }

    private var selectedDevice: CastDevice?

    @objc private func didSelectDeviceOnMenu(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? CastDevice else { return }

        scanner.stopScanning()

        if let previousClient = client {
            if let app = mediaPlayerApp {
                client?.stop(app: app)
            }

            mediaStatusRefreshTimer?.invalidate()
            mediaStatusRefreshTimer = nil

            previousClient.disconnect()
            client = nil
        }

        if device.hostName == selectedDevice?.hostName {
            sender.state = .off

            consumer?.externalPlaybackProviderDidInvalidatePlaybackSession(self)
        } else {
            selectedDevice = device
            sender.state = .on

            client = CastClient(device: device)
            client?.delegate = self

            client?.connect()

            consumer?.externalPlaybackProviderDidBecomeCurrent(self)
        }
    }

    fileprivate var mediaForChromeCast: CastMedia? {
        guard let originalMediaURL = consumer?.remoteMediaUrl else {
            os_log("Unable to play because the player view doesn't have a remote media URL associated with it", log: log, type: .error)
            return nil
        }

        guard let mediaURL = originalMediaURL.chromeCastSupportedURL else {
            os_log("Error generating ChromeCast-compatible media URL", log: log, type: .error)
            return nil
        }

        os_log("ChromeCast media URL is %{public}@", log: log, type: .info, mediaURL.absoluteString)

        let posterURL: URL

        if let poster = consumer?.mediaPosterUrl {
            posterURL = poster
        } else {
            posterURL = ChromeCastConstants.placeholderImageURL
        }

        let title: String

        if let playerTitle = consumer?.mediaTitle {
            title = playerTitle
        } else {
            title = "WWDC Video"
        }

        let streamType: CastMediaStreamType

        if let isLive = consumer?.mediaIsLiveStream {
            streamType = isLive ? .live : .buffered
        } else {
            streamType = .buffered
        }

        var currentTime: Double = 0

        if let playerTime = consumer?.player?.currentTime() {
            currentTime = Double(CMTimeGetSeconds(playerTime))
        }

        let media = CastMedia(title: title,
                              url: mediaURL,
                              poster: posterURL,
                              contentType: "application/vnd.apple.mpegurl",
                              streamType: streamType,
                              autoplay: true,
                              currentTime: currentTime)

        return media
    }

    fileprivate func loadMediaOnDevice() {
        guard let media = mediaForChromeCast else { return }
        guard let app = mediaPlayerApp else { return }
        guard let url = consumer?.remoteMediaUrl else { return }

        os_log("Load media at %{public}@ on session ID %{public}@", log: log, type: .debug, url.absoluteString, app.sessionId)

        var currentTime: Double = 0

        if let playerTime = consumer?.player?.currentTime() {
            currentTime = Double(CMTimeGetSeconds(playerTime))
        }

        os_log("Will start media on ChromeCast at %{public}fs", log: log, type: .info, currentTime)

        client?.load(media: media, with: app) { [weak self] error, mediaStatus in
            guard let self = self else { return }

            guard let mediaStatus = mediaStatus, error == nil else {
                if let error = error {
                    os_log("Failed to load media on ChromeCast: %{public}@", log: self.log, type: .error, String(describing: error))
                    WWDCAlert.show(with: error)
                }
                return
            }

            self.currentSessionId = mediaStatus.mediaSessionId

            os_log("The media is now loaded with session ID %{public}d", log: self.log, type: .info, mediaStatus.mediaSessionId)
            os_log("Current media status is %{public}@", log: self.log, type: .info, String(describing: mediaStatus))

            self.startFetchingMediaStatusPeriodically()
        }
    }

    fileprivate func startFetchingMediaStatusPeriodically() {
        mediaStatusRefreshTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(requestMediaStatus), userInfo: nil, repeats: true)
    }

    @objc private func requestMediaStatus(_ sender: Any?) {
        do {
            try client?.requestStatus()
        } catch {
            os_log("Failed to obtain status from connected ChromeCast device: %{public}@", log: log, type: .error, String(describing: error))
        }
    }

}

extension ChromeCastPlaybackProvider: CastClientDelegate {

    public func castClient(_ client: CastClient, willConnectTo device: CastDevice) {
        os_log("Will connect to device %{public}@", log: log, type: .debug, device.name)
    }

    public func castClient(_ client: CastClient, didConnectTo device: CastDevice) {
        os_log("Connected to device %{public}@. Launching media player app.", log: log, type: .debug, device.name)

        client.launch(appId: .defaultMediaPlayer) { [weak self] error, app in
            guard let self = self else { return }

            guard let app = app, error == nil else {
                if let error = error {
                    os_log("Failed to launch media player app: %{public}@", log: self.log, type: .error, String(describing: error))
                    WWDCAlert.show(with: error)
                }
                return
            }

            os_log("Media player launched. Session id is %{public}@", log: self.log, type: .info, app.sessionId)

            self.mediaPlayerApp = app
            self.loadMediaOnDevice()
        }
    }

    public func castClient(_ client: CastClient, didDisconnectFrom device: CastDevice) {
        consumer?.externalPlaybackProviderDidInvalidatePlaybackSession(self)
    }

    public func castClient(_ client: CastClient, connectionTo device: CastDevice, didFailWith error: NSError) {
        WWDCAlert.show(with: error)

        consumer?.externalPlaybackProviderDidInvalidatePlaybackSession(self)
    }

    public func castClient(_ client: CastClient, deviceStatusDidChange status: CastStatus) {
        self.status.volume = Float(status.volume.level)

        consumer?.externalPlaybackProviderDidChangeMediaStatus(self)
    }

    public func castClient(_ client: CastClient, mediaStatusDidChange status: CastMediaStatus) {
        let rate: Float = status.playerState == .playing ? 1.0 : 0.0

        let newStatus = PUIExternalPlaybackMediaStatus(rate: rate,
                                                       volume: self.status.volume,
                                                       currentTime: status.currentTime)

        self.status = newStatus

        os_log("Media status: %{public}@", log: log, type: .debug, String(describing: newStatus))

        consumer?.externalPlaybackProviderDidChangeMediaStatus(self)
    }

}
