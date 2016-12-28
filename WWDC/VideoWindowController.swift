//
//  VideoWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit
import WWDCAppKit

private let _nibName = "VideoWindowController"

class VideoWindowController: NSWindowController {
    
    var session: Session?
    
    var videoURL: String?
    var startTime: Double?
    
    weak var asset: AVAsset!
    weak var item: AVPlayerItem!
    
    var transcriptWC: TranscriptWindowController!
    var playerWindow: GRPlayerWindow {
        get {
            return window as! GRPlayerWindow
        }
    }
    var videoNaturalSize = CGSize.zero
    
    convenience init(session: Session, videoURL: String) {
        self.init(windowNibName: _nibName)
        self.session = session
        self.videoURL = videoURL
    }
    
    convenience init(session: Session, videoURL: String, startTime: Double?) {
        self.init(windowNibName: _nibName)
        self.session = session
        self.videoURL = videoURL
        self.startTime = startTime
    }
    
    @IBOutlet weak var playerView: AVPlayerView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    weak var player: AVPlayer? {
        didSet {
            if let player = player {
                if #available(OSX 10.11, *) {
                    player.allowsExternalPlayback = true
                }
                
                let args = ProcessInfo.processInfo.arguments
                if args.contains("zerovolume") {
                    player.volume = 0
                }
            }
        }
    }
    
    fileprivate var activity: NSObjectProtocol?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        guard let session = session else { return }
        
        setupPlayer()
        
        NotificationCenter.default.addObserver(self, selector: #selector(NSWindowDelegate.windowWillClose(_:)), name: NSNotification.Name.NSWindowWillClose, object: self.window)
        
        activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled, .userInitiated], reason: "Playing WWDC session video")
        
        progressIndicator.startAnimation(nil)
        window?.backgroundColor = NSColor.black
        
        window?.title = "\(session.event) \(session.year) | \(session.title)"
        
        // pause playback when a live event starts playing
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: LiveEventWillStartPlayingNotification), object: nil, queue: nil) { [weak self] _ in
            self?.player?.pause()
        }
        
        if Preferences.SharedPreferences().floatOnTopEnabled {
            window!.level = Int(CGWindowLevelForKey(CGWindowLevelKey.floatingWindow))
        }
    }
    
    func windowWillClose(_ note: Notification!) {
        NotificationCenter.default.removeObserver(self)
        
        if let player = player {
            player.cancelPendingPrerolls()
            player.pause()
            if #available(OSX 10.11, *) {
                removeRateObserver(player: player)
            }
        }
        
        asset = nil
        item = nil
        player = nil
        
        if let observer: AnyObject = timeObserver {
            player?.removeTimeObserver(observer)
        }
        if let observer: AnyObject = boundaryObserver {
            player?.removeTimeObserver(observer)
        }
        
        if let activity = self.activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        
        self.transcriptWC?.close()
        self.transcriptWC = nil
    }
    
    fileprivate func setupPlayer() {
        guard let videoURL = videoURL, let url = URL(string: videoURL) else { return }
        
        playerView.controlsStyle = .none
        
        player = AVPlayer(url: url)
        if #available(OSX 10.11, *) {
            addRateObserver(player: player!)
        }
        playerView.player = player
        
        player?.currentItem?.asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self] in
            DispatchQueue.main.async {
                self?.setupWindowSizing()
                self?.setupTimeObserver()
                
                if let session = self?.session {
                    if session.currentPosition > 0 {
                        self?.player?.seek(to: CMTimeMakeWithSeconds(session.currentPosition, 1))
                    }
                }
                
                if let startAt = self?.startTime {
                    self?.seekTo(startAt)
                }
                self?.player?.play()
                self?.progressIndicator.stopAnimation(nil)
                self?.playerView.controlsStyle = .floating
            }
        }
    }
    
    var rate: Float = 1.0
    
    // observing the key "rate" on AVPlayer caused a crash on 10.10
    @available(OSX 10.11, *)
    fileprivate func addRateObserver(player: AVPlayer) {
        player.addObserver(self, forKeyPath: "rate", options: [.new, .old], context: nil)
    }
    
    // observing the key "rate" on AVPlayer caused a crash on 10.10
    @available(OSX 10.11, *)
    fileprivate func removeRateObserver(player: AVPlayer) {
        player.removeObserver(self, forKeyPath: "rate")
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    self.progressIndicator.stopAnimation(nil)
                    self.player?.play()
                }
            }
        } else if keyPath == "rate" {
            if let change = change,
                let newRate = change[NSKeyValueChangeKey.newKey] as? Float,
                let oldRate = change[NSKeyValueChangeKey.oldKey] as? Float
            {
                if oldRate == 0.0 && newRate == 1.0 { // play button tapped
                    player!.rate = rate // set rate to stored one
                } else if newRate != 0.0 { // change rate button tapped
                    rate = newRate // store rate
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func seekTo(_ time: Double) {
        player?.seek(to: CMTimeMakeWithSeconds(time, 6000), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
    }
    
    func toggleFullScreen(_ sender: AnyObject?) {
        window!.toggleFullScreen(sender)
    }
    
    func showTranscriptWindow(_ sender: AnyObject?) {
        guard let session = session else { return }
        guard session.transcript != nil else {
            let alert = NSAlert()
            alert.messageText = "Transcript not available"
            if WWDCEnvironment.yearsToIgnoreTranscript.contains(session.year) {
                alert.informativeText = "Transcripts for \(session.year) sessions are not available yet."
            } else {
                alert.informativeText = "The transcript for this session is not available."
            }
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        if transcriptWC != nil {
            if let window = transcriptWC.window {
                window.orderFront(sender)
            }
            
            return
        }
        
        transcriptWC = TranscriptWindowController(session: session)
        transcriptWC.showWindow(sender)
        transcriptWC.jumpToTimeCallback = { [unowned self] time in
            guard let player = self.player else { return }
            player.seek(to: CMTimeMakeWithSeconds(time, player.currentItem!.duration.timescale))
        }
        
        setupTranscriptSync(session.transcript!)
    }
    
    var timeObserver: AnyObject?
    
    func setupTimeObserver() {
        guard session != nil && timeObserver == nil else { return }
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(5, 1), queue: DispatchQueue.main) { [weak self] currentTime in
            guard let weakSelf = self else { return }
            
            let progress = Double(CMTimeGetSeconds(currentTime)/CMTimeGetSeconds(weakSelf.player!.currentItem!.duration))
            
            WWDCDatabase.sharedDatabase.doChanges {
                weakSelf.session!.progress = progress
                weakSelf.session!.currentPosition = CMTimeGetSeconds(currentTime)
            }
        } as AnyObject?
    }
    
    var boundaryObserver: AnyObject?
    
    func setupTranscriptSync(_ transcript: Transcript) {
        guard !transcript.isInvalidated else { return }
        guard transcript.lines.count > 0 else { return }
        guard let player = player, transcriptWC != nil else { return }
        guard let playerItem = player.currentItem else { return }
        
        let timecodes = transcript.timecodesWithTimescale(playerItem.duration.timescale)
        guard timecodes.count > 0 else { return }
        
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: timecodes, queue: DispatchQueue.main) { [unowned self] in
            guard self.transcriptWC != nil else { return }
            
            let ct = CMTimeGetSeconds(self.player!.currentTime())
            let roundedTimecode = Transcript.roundedStringFromTimecode(ct)
            self.transcriptWC.highlightLineAt(roundedTimecode)
        } as AnyObject?
    }
    
    func setupWindowSizing()
    {
        if let asset = player?.currentItem?.asset {
            // get video dimensions and set window aspect ratio
            let tracks = asset.tracks(withMediaType: AVMediaTypeVideo)
            if tracks.count > 0 {
                let track = tracks[0]
                videoNaturalSize = track.naturalSize
                playerWindow.aspectRatio = videoNaturalSize
            } else {
                return
            }
        } else {
            return
        }
        
        // get saved scale
        let lastScale = Preferences.SharedPreferences().lastVideoWindowScale
        
        if lastScale != 100.0 {
            // saved scale matters, resize to preference
            sizeWindowTo(lastScale)
        } else {
            // saved scale is default, size to fit screen (default sizing)
            sizeWindowToFill(nil)
        }
    }
    
    // Toggles if the window should float on top of all other windows
    @IBAction func floatOnTop(_ sender: NSMenuItem) {
        if sender.state == NSOnState {
            window!.level = Int(CGWindowLevelForKey(CGWindowLevelKey.normalWindow))
            Preferences.SharedPreferences().floatOnTopEnabled = false
            
            sender.state = NSOffState
        } else {
            window!.level = Int(CGWindowLevelForKey(CGWindowLevelKey.floatingWindow))
            Preferences.SharedPreferences().floatOnTopEnabled = true
            
            sender.state = NSOnState
        }
    }
    
    // resizes the window so the video fills the entire screen without cropping
    @IBAction func sizeWindowToFill(_ sender: AnyObject?)
    {
        if (videoNaturalSize == CGSize.zero) {
            return
        }
        
        Preferences.SharedPreferences().lastVideoWindowScale = 100.0
        
        playerWindow.size(toFitVideoSize: videoNaturalSize, ignoringScreenSize: false, animated: false)
    }
    
    // resizes the window to a fraction of the video's size
    func sizeWindowTo(_ fraction: CGFloat)
    {
        if (videoNaturalSize == CGSize.zero) {
            return
        }
        
        Preferences.SharedPreferences().lastVideoWindowScale = fraction
        
        let scaledSize = CGSize(width: videoNaturalSize.width*fraction, height: videoNaturalSize.height*fraction)
        playerWindow.size(toFitVideoSize: scaledSize, ignoringScreenSize: true, animated: true)
    }
    
    @IBAction func sizeWindowToHalfSize(_ sender: AnyObject?) {
        sizeWindowTo(0.5)
    }
    
    @IBAction func sizeWindowToQuarterSize(_ sender: AnyObject?) {
        sizeWindowTo(0.25)
    }
    
}

extension Transcript {
    
    func timecodesWithTimescale(_ timescale: Int32) -> [NSValue] {
        var results: [NSValue] = []
        
        for line in lines {
            let time = CMTimeMakeWithSeconds(line.timecode, timescale)
            
            results.append(NSValue(time: time))
        }
        
        return results
    }
    
    class func roundedStringFromTimecode(_ timecode: Float64) -> String {
        let formatter = NumberFormatter()
        formatter.positiveFormat = "0.#"
        
        return formatter.string(from: NSNumber(value: timecode)) ?? "0.0"
    }
    
}
