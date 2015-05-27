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

enum FloatOnTopStyle: Int {
    case Never = 0, WhilePlaying = 1, Always = 2
}

class VideoWindowController: NSWindowController {

    var session: Session?
    var event: LiveEvent?
    
    var videoURL: String?
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
    }
    
    @IBOutlet weak var playerView: AVPlayerView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    var player: AVPlayer?
    let kFloatOnTopStyle = "Float on Top Style"
    var floatOnTopStyle: FloatOnTopStyle = .Never
    
    override func windowDidLoad() {
        super.windowDidLoad()

        progressIndicator.startAnimation(nil)
        window?.backgroundColor = NSColor.blackColor()

        if let floatOnTopStyle = FloatOnTopStyle(rawValue: NSUserDefaults.standardUserDefaults().integerForKey(kFloatOnTopStyle)) {
            self.floatOnTopStyle = floatOnTopStyle
            if let mainMenu = NSApplication.sharedApplication().mainMenu {
                self.updateFloatOnTopMenuState(inMenu: mainMenu)
            }
        }
        
        if let url = NSURL(string: videoURL!) {
            player = AVPlayer(URL: url)
            playerView.player = player
            player?.currentItem.asset.loadValuesAsynchronouslyForKeys(["tracks"]) {
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

            player?.addObserver(self, forKeyPath: "rate", options: .New, context: nil)
        }
        
        if let session = self.session {
            window?.title = "WWDC \(session.year) | \(session.title)"
            
            // pause playback when a live event starts playing
            NSNotificationCenter.defaultCenter().addObserverForName(LiveEventWillStartPlayingNotification, object: nil, queue: nil) { _ in
                self.player?.pause()
            }
        }
        
        if let event = self.event {
            window?.title = "\(event.title) (live)"
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName(NSWindowWillCloseNotification, object: self.window, queue: nil) { _ in
            self.transcriptWC?.close()
            
            self.player?.pause()
        }
    }
    
    func toggleFullScreen(sender: AnyObject?) {
        window!.toggleFullScreen(sender)
    }
    
    func showTranscriptWindow(sender: AnyObject?) {
        if session == nil {
            return
        }
        
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
                if let player = self.player {
                    player.seekToTime(CMTimeMakeWithSeconds(time, 30))
                }
            }
            transcriptWC.transcriptReadyCallback = { [unowned self] transcript in
                self.setupTranscriptSync(transcript)
            }
        }
    }
    
    var timeObserver: AnyObject?
    
    func setupTimeObserver() {
        if session == nil {
            return
        }
        
        timeObserver = player?.addPeriodicTimeObserverForInterval(CMTimeMakeWithSeconds(5, 1), queue: dispatch_get_main_queue()) { [unowned self] currentTime in
            let progress = Double(CMTimeGetSeconds(currentTime)/CMTimeGetSeconds(self.player!.currentItem.duration))

            self.session!.progress = progress
            self.session!.currentPosition = CMTimeGetSeconds(currentTime)
        }
    }
    
    var boundaryObserver: AnyObject?
    
    func setupTranscriptSync(transcript: WWDCSessionTranscript) {
        if self.transcriptWC == nil {
            return
        }
        
        boundaryObserver = player?.addBoundaryTimeObserverForTimes(transcript.timecodes, queue: dispatch_get_main_queue()) { [unowned self] in
            if self.transcriptWC == nil {
                return
            }
            
            let roundedTimecode = WWDCTranscriptLine.roundedStringFromTimecode(CMTimeGetSeconds(self.player!.currentTime()))
            self.transcriptWC.highlightLineAt(roundedTimecode)
        }
    }
    
    func setupWindowSizing()
    {
        // get video dimensions and set window aspect ratio
        if let tracks = player?.currentItem.asset.tracksWithMediaType(AVMediaTypeVideo) as? [AVAssetTrack] {
            if tracks.count > 0 {
                let track = tracks[0]
                videoNaturalSize = track.naturalSize
                playerWindow.aspectRatio = videoNaturalSize
            }
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

    @IBAction func changeFloatOnTop(sender: AnyObject?) {
        if let menuItem = sender as? NSMenuItem {
            menuItem.state = NSOnState
            if let floatOnTopStyle = FloatOnTopStyle(rawValue: menuItem.tag) {
                self.floatOnTopStyle = floatOnTopStyle
                NSUserDefaults.standardUserDefaults().setInteger(self.floatOnTopStyle.rawValue, forKey: kFloatOnTopStyle)

                self.updateFloatOnTopWindowState()
                if let mainMenu = NSApplication.sharedApplication().mainMenu {
                    self.updateFloatOnTopMenuState(inMenu: mainMenu)
                }
            }
        }
    }

    func updateFloatOnTopMenuState(inMenu menu: NSMenu) {
        var floatOnTopStyle = self.floatOnTopStyle.rawValue
        for subAnyItem in menu.itemArray {
            if let subItem = subAnyItem as? NSMenuItem {
                if subItem.submenu != nil {
                    updateFloatOnTopMenuState(inMenu: subItem.submenu!)
                }
                else if subItem.action == "changeFloatOnTop:" {
                    subItem.state = subItem.tag == floatOnTopStyle ? NSOnState : NSOffState
                }
            }
        }
    }
    
    func updateFloatOnTopWindowState() {
        switch self.floatOnTopStyle {
        case .Never:
            self.window?.level = Int(CGWindowLevelForKey(Int32(kCGNormalWindowLevelKey)));
        case .Always:
            self.window?.level = Int(CGWindowLevelForKey(Int32(kCGMainMenuWindowLevelKey)))
        case .WhilePlaying:
            if let player = self.player {
                let isPlaying = player.rate != 0
                self.window?.level = isPlaying ? Int(CGWindowLevelForKey(Int32(kCGMainMenuWindowLevelKey)))
                                               : Int(CGWindowLevelForKey(Int32(kCGNormalWindowLevelKey)))
            }
        }
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if let player = self.player {
            if player == object as! NSObject {
                self.updateFloatOnTopWindowState()
            }
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
        if let observer: AnyObject = timeObserver {
            player?.removeTimeObserver(observer)
        }
        if let observer: AnyObject = boundaryObserver {
            player?.removeTimeObserver(observer)
        }
        
        player?.removeObserver(self, forKeyPath: "rate", context: nil)
    }
    
}
