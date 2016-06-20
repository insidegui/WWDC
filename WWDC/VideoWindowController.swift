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
    var videoNaturalSize = CGSizeZero
    
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
                
                let args = NSProcessInfo.processInfo().arguments
                if args.contains("zerovolume") {
                    player.volume = 0
                }
            }
        }
    }
    
    private var activity: NSObjectProtocol?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        guard let session = session else { return }
        
        setupPlayer()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(NSWindowDelegate.windowWillClose(_:)), name: NSWindowWillCloseNotification, object: self.window)
        
        activity = NSProcessInfo.processInfo().beginActivityWithOptions([.IdleDisplaySleepDisabled, .IdleSystemSleepDisabled, .UserInitiated], reason: "Playing WWDC session video")
        
        progressIndicator.startAnimation(nil)
        window?.backgroundColor = NSColor.blackColor()
        
        window?.title = "\(session.event) \(session.year) | \(session.title)"
        
        // pause playback when a live event starts playing
        NSNotificationCenter.defaultCenter().addObserverForName(LiveEventWillStartPlayingNotification, object: nil, queue: nil) { [weak self] _ in
            self?.player?.pause()
        }
        
        if Preferences.SharedPreferences().floatOnTopEnabled {
            window!.level = Int(CGWindowLevelForKey(CGWindowLevelKey.FloatingWindowLevelKey))
        }
    }
    
    func windowWillClose(note: NSNotification!) {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
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
            NSProcessInfo.processInfo().endActivity(activity)
        }
        
        self.transcriptWC?.close()
        self.transcriptWC = nil
    }
    
    private func setupPlayer() {
        guard let videoURL = videoURL, url = NSURL(string: videoURL) else { return }
        
        playerView.controlsStyle = .None
        
        player = AVPlayer(URL: url)
        if #available(OSX 10.11, *) {
            addRateObserver(player: player!)
        }
        playerView.player = player
        
        player?.currentItem?.asset.loadValuesAsynchronouslyForKeys(["tracks"]) { [weak self] in
            dispatch_async(dispatch_get_main_queue()) {
                self?.setupWindowSizing()
                self?.setupTimeObserver()
                
                if let session = self?.session {
                    if session.currentPosition > 0 {
                        self?.player?.seekToTime(CMTimeMakeWithSeconds(session.currentPosition, 1))
                    }
                }
                
                if let startAt = self?.startTime {
                    self?.seekTo(startAt)
                }
                self?.player?.play()
                self?.progressIndicator.stopAnimation(nil)
                self?.playerView.controlsStyle = .Floating
            }
        }
    }
    
    var rate: Float = 1.0
    
    // observing the key "rate" on AVPlayer caused a crash on 10.10
    @available(OSX 10.11, *)
    private func addRateObserver(player player: AVPlayer) {
        player.addObserver(self, forKeyPath: "rate", options: [.New, .Old], context: nil)
    }
    
    // observing the key "rate" on AVPlayer caused a crash on 10.10
    @available(OSX 10.11, *)
    private func removeRateObserver(player player: AVPlayer) {
        player.removeObserver(self, forKeyPath: "rate")
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "status" {
            if item.status == .ReadyToPlay {
                dispatch_async(dispatch_get_main_queue()) {
                    self.progressIndicator.stopAnimation(nil)
                    self.player?.play()
                }
            }
        } else if keyPath == "rate" {
            if let change = change,
                let newRate = change[NSKeyValueChangeNewKey] as? Float,
                let oldRate = change[NSKeyValueChangeOldKey] as? Float
            {
                if oldRate == 0.0 && newRate == 1.0 { // play button tapped
                    player!.rate = rate // set rate to stored one
                } else if newRate != 0.0 { // change rate button tapped
                    rate = newRate // store rate
                }
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    func seekTo(time: Double) {
        player?.seekToTime(CMTimeMakeWithSeconds(time, 6000), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
    }
    
    func toggleFullScreen(sender: AnyObject?) {
        window!.toggleFullScreen(sender)
    }
    
    func showTranscriptWindow(sender: AnyObject?) {
        guard let session = session else { return }
        guard session.transcript != nil else {
            let alert = NSAlert()
            alert.messageText = "Transcript not available"
            if WWDCEnvironment.yearsToIgnoreTranscript.contains(session.year) {
                alert.informativeText = "Transcripts for \(session.year) sessions are not available yet."
            } else {
                alert.informativeText = "The transcript for this session is not available."
            }
            alert.addButtonWithTitle("OK")
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
            player.seekToTime(CMTimeMakeWithSeconds(time, player.currentItem!.duration.timescale))
        }
        
        setupTranscriptSync(session.transcript!)
    }
    
    var timeObserver: AnyObject?
    
    func setupTimeObserver() {
        guard session != nil && timeObserver == nil else { return }
        
        timeObserver = player?.addPeriodicTimeObserverForInterval(CMTimeMakeWithSeconds(5, 1), queue: dispatch_get_main_queue()) { [weak self] currentTime in
            guard let weakSelf = self else { return }
            
            let progress = Double(CMTimeGetSeconds(currentTime)/CMTimeGetSeconds(weakSelf.player!.currentItem!.duration))
            
            WWDCDatabase.sharedDatabase.doChanges {
                weakSelf.session!.progress = progress
                weakSelf.session!.currentPosition = CMTimeGetSeconds(currentTime)
            }
        }
    }
    
    var boundaryObserver: AnyObject?
    
    func setupTranscriptSync(transcript: Transcript) {
        guard !transcript.invalidated else { return }
        guard transcript.lines.count > 0 else { return }
        guard let player = player where transcriptWC != nil else { return }
        guard let playerItem = player.currentItem else { return }
        
        let timecodes = transcript.timecodesWithTimescale(playerItem.duration.timescale)
        guard timecodes.count > 0 else { return }
        
        boundaryObserver = player.addBoundaryTimeObserverForTimes(timecodes, queue: dispatch_get_main_queue()) { [unowned self] in
            guard self.transcriptWC != nil else { return }
            
            let ct = CMTimeGetSeconds(self.player!.currentTime())
            let roundedTimecode = Transcript.roundedStringFromTimecode(ct)
            self.transcriptWC.highlightLineAt(roundedTimecode)
        }
    }
    
    func setupWindowSizing()
    {
        if let asset = player?.currentItem?.asset {
            // get video dimensions and set window aspect ratio
            let tracks = asset.tracksWithMediaType(AVMediaTypeVideo)
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
    @IBAction func floatOnTop(sender: NSMenuItem) {
        if sender.state == NSOnState {
            window!.level = Int(CGWindowLevelForKey(CGWindowLevelKey.NormalWindowLevelKey))
            Preferences.SharedPreferences().floatOnTopEnabled = false
            
            sender.state = NSOffState
        } else {
            window!.level = Int(CGWindowLevelForKey(CGWindowLevelKey.FloatingWindowLevelKey))
            Preferences.SharedPreferences().floatOnTopEnabled = true
            
            sender.state = NSOnState
        }
    }
    
    // resizes the window so the video fills the entire screen without cropping
    @IBAction func sizeWindowToFill(sender: AnyObject?)
    {
        if (videoNaturalSize == CGSizeZero) {
            return
        }
        
        Preferences.SharedPreferences().lastVideoWindowScale = 100.0
        
        playerWindow.sizeToFitVideoSize(videoNaturalSize, ignoringScreenSize: false, animated: false)
    }
    
    // resizes the window to a fraction of the video's size
    func sizeWindowTo(fraction: CGFloat)
    {
        if (videoNaturalSize == CGSizeZero) {
            return
        }
        
        Preferences.SharedPreferences().lastVideoWindowScale = fraction
        
        let scaledSize = CGSize(width: videoNaturalSize.width*fraction, height: videoNaturalSize.height*fraction)
        playerWindow.sizeToFitVideoSize(scaledSize, ignoringScreenSize: true, animated: true)
    }
    
    @IBAction func sizeWindowToHalfSize(sender: AnyObject?) {
        sizeWindowTo(0.5)
    }
    
    @IBAction func sizeWindowToQuarterSize(sender: AnyObject?) {
        sizeWindowTo(0.25)
    }
    
}

extension Transcript {
    
    func timecodesWithTimescale(timescale: Int32) -> [NSValue] {
        var results: [NSValue] = []
        
        for line in lines {
            let time = CMTimeMakeWithSeconds(line.timecode, timescale)
            results.append(NSValue(CMTime: time))
        }
        
        return results
    }
    
    class func roundedStringFromTimecode(timecode: Float64) -> String {
        let formatter = NSNumberFormatter()
        formatter.positiveFormat = "0.#"
        
        return formatter.stringFromNumber(timecode)!
    }
    
}