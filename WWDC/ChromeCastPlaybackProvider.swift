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

final class ChromeCastPlaybackProvider: NSObject, PUIExternalPlaybackProvider {
    
    fileprivate weak var consumer: PUIExternalPlaybackConsumer?
    
    private lazy var scanner: CastDeviceScanner = CastDeviceScanner()
    
    /// Initializes the external playback provider to start playing the media at the specified URL
    ///
    /// - Parameter consumer: The consumer that's going to be using this provider
    init(consumer: PUIExternalPlaybackConsumer) {
        self.consumer = consumer
        self.status = PUIExternalPlaybackMediaStatus()
        
        super.init()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(deviceListDidChange),
                                               name: CastDeviceScanner.DeviceListDidChange,
                                               object: self.scanner)
        
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
        self.isAvailable = scanner.devices.count > 0
        
        buildMenu()
    }
    
    private func buildMenu() {
        let menu = NSMenu()
        
        scanner.devices.forEach { device in
            let item = NSMenuItem(title: device.name, action: #selector(didSelectDeviceOnMenu(_:)), keyEquivalent: "")
            item.representedObject = device
            item.target = self
            menu.addItem(item)
        }
        
        // send menu to consumer
        consumer?.externalPlaybackProvider(self, deviceSelectionMenuDidChangeWith: menu)
    }
    
    @objc private func didSelectDeviceOnMenu(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? CastDevice else { return }
        
        if let previousClient = client {
            mediaStatusRefreshTimer?.invalidate()
            mediaStatusRefreshTimer = nil
            
            previousClient.disconnect()
            client = nil
        }
        
        if sender.state == NSOffState {
            client = CastClient(device: device)
            client?.delegate = self
            
            client?.connect()
            
            sender.state = NSOnState
        } else {
            sender.state = NSOffState
        }        
    }
    
    fileprivate var mediaForChromeCast: CastMedia? {
        guard let originalMediaURL = self.consumer?.remoteMediaUrl else {
            NSLog("Unable to play because the player view doesn't have a remote media URL associated with it")
            return nil
        }
        
        guard let mediaURL = originalMediaURL.chromeCastSupportedURL else {
            NSLog("Error generating ChromeCast-compatible media URL")
            return nil
        }
        
        #if DEBUG
            NSLog("Original media URL = \(originalMediaURL)")
            NSLog("ChromeCast-compatible media URL = \(mediaURL)")
        #endif
        
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
        
        #if DEBUG
            NSLog("Load media \(url) with \(app.sessionId)")
        #endif
        
        var currentTime: Double = 0
        
        if let playerTime = consumer?.player?.currentTime() {
            currentTime = Double(CMTimeGetSeconds(playerTime))
        }
        
        #if DEBUG
            NSLog("Current time is \(currentTime)s")
        #endif
        
        client?.load(media: media, with: app) { [weak self] error, mediaStatus in
            guard let mediaStatus = mediaStatus, error == nil else {
                if let error = error {
                    WWDCAlert.show(with: error)
                    #if DEBUG
                        NSLog("Error loading media: \(error)")
                    #endif
                }
                return
            }
            
            self?.currentSessionId = mediaStatus.mediaSessionId
            
            #if DEBUG
                NSLog("Media loaded. SessionID: \(mediaStatus.mediaSessionId).")
                NSLog("MEDIA STATUS:\n\(mediaStatus)")
            #endif
            
            self?.startFetchingMediaStatusPeriodically()
        }
    }
    
    fileprivate func startFetchingMediaStatusPeriodically() {
        mediaStatusRefreshTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(requestMediaStatus(_:)), userInfo: nil, repeats: true)
    }
    
    @objc private func requestMediaStatus(_ sender: Any?) {
        do {
            try client?.requestStatus()
        } catch {
            #if DEBUG
                NSLog("Error requesting status from connected device: \(error)")
            #endif
        }
    }
    
}

extension ChromeCastPlaybackProvider: CastClientDelegate {
    
    public func castClient(_ client: CastClient, willConnectTo device: CastDevice) {
        #if DEBUG
            NSLog("Will connect to \(device.name) (\(device.id))")
        #endif
    }
    
    public func castClient(_ client: CastClient, didConnectTo device: CastDevice) {
        #if DEBUG
            NSLog("Did connect to \(device.name) (\(device.id))")
        #endif
        
        consumer?.externalPlaybackProviderDidBecomeCurrent(self)
        
        #if DEBUG
            NSLog("Launching app \(CastAppIdentifier.defaultMediaPlayer.rawValue)")
        #endif
        
        client.launch(appId: .defaultMediaPlayer) { [weak self] error, app in
            guard let app = app, error == nil else {
                if let error = error {
                    #if DEBUG
                        NSLog("Error launching app \(CastAppIdentifier.defaultMediaPlayer.rawValue): \(error)")
                    #endif
                    
                    WWDCAlert.show(with: error)
                }
                return
            }

            #if DEBUG
                NSLog("App \(CastAppIdentifier.defaultMediaPlayer.rawValue) launched. Session: \(app.sessionId)")
            #endif
            
            self?.mediaPlayerApp = app
            self?.loadMediaOnDevice()
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
        self.status.volume = Float(status.volume)
        
        consumer?.externalPlaybackProviderDidChangeMediaStatus(self)
    }
    
    public func castClient(_ client: CastClient, mediaStatusDidChange status: CastMediaStatus) {
        let rate: Float = status.playerState == .playing ? 1.0 : 0.0
        
        let newStatus = PUIExternalPlaybackMediaStatus(rate: rate,
                                                       volume: self.status.volume,
                                                       currentTime: status.currentTime)
        
        self.status = newStatus
        
        #if DEBUG
            NSLog("# MEDIA STATUS #\n\(newStatus)\n---")
        #endif
        
        consumer?.externalPlaybackProviderDidChangeMediaStatus(self)
    }
    
}
