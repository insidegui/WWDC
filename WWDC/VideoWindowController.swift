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
import ASCIIwwdc
import ViewUtils

private let _nibName = "VideoWindowController"

class VideoWindowController: NSWindowController {

    var session: Session?
    var event: LiveEvent?
    
    var videoURL: String?
    
    var asset: AVAsset!
    var item: AVPlayerItem!
    
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
    
    convenience init(event: LiveEvent, videoURL: String) {
        self.init(windowNibName: _nibName)
        self.event = event
        self.videoURL = videoURL
        NSNotificationCenter.defaultCenter().addObserverForName(LiveEventTitleAvailableNotification, object: nil, queue: NSOperationQueue.mainQueue()) { note in
            if let title = note.object as? String {
                self.window?.title = "\(title) (Live)"
            }
        }
    }
    
    @IBOutlet weak var customPlayerView: GRCustomPlayerView!
    @IBOutlet weak var playerView: AVPlayerView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    var player: AVPlayer? {
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
        
        activity = NSProcessInfo.processInfo().beginActivityWithOptions([.IdleDisplaySleepDisabled, .IdleSystemSleepDisabled, .UserInitiated], reason: "Playing WWDC session video")

        progressIndicator.startAnimation(nil)
        window?.backgroundColor = NSColor.blackColor()

        if let url = NSURL(string: videoURL!) {
            if event == nil {
                player = AVPlayer(URL: url)
                playerView.player = player
                
                // SESSION
                player?.currentItem!.asset.loadValuesAsynchronouslyForKeys(["tracks"]) {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.setupWindowSizing()
                        self.setupTimeObserver()
                        
                        if let session = self.session {
                            if session.currentPosition > 0 {
                                self.player?.seekToTime(CMTimeMakeWithSeconds(session.currentPosition, 1))
                            }
                        }
                        
                        self.player?.play()
                        self.progressIndicator.stopAnimation(nil)
                    }
                }
            }
        }
        
        if let session = self.session {
            window?.title = "WWDC \(session.year) | \(session.title)"
            
            // pause playback when a live event starts playing
            NSNotificationCenter.defaultCenter().addObserverForName(LiveEventWillStartPlayingNotification, object: nil, queue: nil) { _ in
                self.player?.pause()
            }
        }

		if Preferences.SharedPreferences().floatOnTopEnabled {
			window!.level = Int(CGWindowLevelForKey(CGWindowLevelKey.FloatingWindowLevelKey))
		}
        
        if let event = self.event {
            window?.title = "\(event.title) (Live)"
            
            loadEventVideo()
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName(NSWindowWillCloseNotification, object: self.window, queue: nil) { _ in
            if let activity = self.activity {
                NSProcessInfo.processInfo().endActivity(activity)
            }
            
            if self.event != nil {
                if self.item != nil {
                    self.item.removeObserver(self, forKeyPath: "status")
                }
            }
            
            self.transcriptWC?.close()
            
            self.player?.pause()
        }
    }
    
    private func loadEventVideo() {
        if let url = event!.stream {
            asset = AVURLAsset(URL: url, options: nil)
            asset.loadValuesAsynchronouslyForKeys(["playable"]) {
                dispatch_async(dispatch_get_main_queue()) {
                    if self.asset.playable {
                        self.playEventVideo()
                    }
                }
            }
        }
    }
    
    private func playEventVideo() {
        item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        item.addObserver(self, forKeyPath: "status", options: [.Initial, .New], context: nil)

        playerView.player = player
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "status" {
            if item.status == .ReadyToPlay {
                dispatch_async(dispatch_get_main_queue()) {
                    self.progressIndicator.stopAnimation(nil)
                    self.player?.play()
                }
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    func toggleFullScreen(sender: AnyObject?) {
        window!.toggleFullScreen(sender)
    }
    
    func showTranscriptWindow(sender: AnyObject?) {
        guard session != nil else { return }
        
        if transcriptWC != nil {
            if let window = transcriptWC.window {
                window.orderFront(sender)
            }
            
            return
        }
        
        if let session = session {
            transcriptWC = TranscriptWindowController(session: session)
            transcriptWC.showWindow(sender)
            transcriptWC.jumpToTimeCallback = { [unowned self] time in
                guard let player = self.player else { return }
                player.seekToTime(CMTimeMakeWithSeconds(time, 30))
            }
            transcriptWC.transcriptReadyCallback = { [unowned self] transcript in
                self.setupTranscriptSync(transcript)
            }
        }
    }
    
    var timeObserver: AnyObject?
    
    func setupTimeObserver() {
        guard session != nil else { return }
        
        timeObserver = player?.addPeriodicTimeObserverForInterval(CMTimeMakeWithSeconds(5, 1), queue: dispatch_get_main_queue()) { [unowned self] currentTime in
            let progress = Double(CMTimeGetSeconds(currentTime)/CMTimeGetSeconds(self.player!.currentItem!.duration))

            self.session!.progress = progress
            self.session!.currentPosition = CMTimeGetSeconds(currentTime)
        }
    }
    
    var boundaryObserver: AnyObject?
    
    func setupTranscriptSync(transcript: WWDCSessionTranscript) {
        guard transcriptWC != nil else { return }
        
        boundaryObserver = player?.addBoundaryTimeObserverForTimes(transcript.timecodes, queue: dispatch_get_main_queue()) { [unowned self] in
            guard self.transcriptWC != nil else { return }

            let roundedTimecode = WWDCTranscriptLine.roundedStringFromTimecode(CMTimeGetSeconds(self.player!.currentTime()))
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
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
        if let observer: AnyObject = timeObserver {
            player?.removeTimeObserver(observer)
        }
        if let observer: AnyObject = boundaryObserver {
            player?.removeTimeObserver(observer)
        }
    }
    
}
