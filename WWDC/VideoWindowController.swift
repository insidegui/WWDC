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

class VideoWindowController: NSWindowController {

    var session: Session?
    var videoURL: String?
    
    convenience init(session: Session, videoURL: String) {
        self.init(windowNibName: "VideoWindowController")
        self.session = session
        self.videoURL = videoURL
    }
    
    @IBOutlet weak var playerView: AVPlayerView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    var player: AVPlayer?
    
    override func windowDidLoad() {
        super.windowDidLoad()

        progressIndicator.startAnimation(nil)
        window?.backgroundColor = NSColor.blackColor()
        
        if let session = session {
            if let url = NSURL(string: videoURL!) {
                player = AVPlayer(URL: url)
                playerView.player = player
                player?.currentItem.asset.loadValuesAsynchronouslyForKeys(["duration"]) {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.setupTimeObserver()
                        if session.currentPosition > 0 {
                            self.player?.seekToTime(CMTimeMakeWithSeconds(session.currentPosition, 1))
                        }
                        self.player?.play()
                        self.progressIndicator.stopAnimation(nil)
                    }
                }
            }
            
            window?.title = "WWDC \(session.year) | \(session.title)"
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName(NSWindowWillCloseNotification, object: self.window, queue: nil) { _ in
            player?.pause()
        }
    }
    
    func toggleFullScreen(sender: AnyObject?) {
        window!.toggleFullScreen(sender)
    }
    
    var timeObserver: AnyObject?
    
    func setupTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserverForInterval(CMTimeMakeWithSeconds(5, 1), queue: dispatch_get_main_queue()) { [unowned self] currentTime in
            let progress = Double(CMTimeGetSeconds(currentTime)/CMTimeGetSeconds(self.player!.currentItem.duration))
            println("p: \(progress)")
            self.session!.progress = progress
            self.session!.currentPosition = CMTimeGetSeconds(currentTime)
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
        if let observer: AnyObject = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }
    
}
