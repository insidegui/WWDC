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
    
    convenience init(session: Session) {
        self.init(windowNibName: "VideoWindowController")
        self.session = session
    }
    
    @IBOutlet weak var playerView: AVPlayerView!
    var player: AVPlayer?
    
    override func windowDidLoad() {
        super.windowDidLoad()

        window?.backgroundColor = NSColor.blackColor()
        
        if let session = session {
            if let url = NSURL(string: session.url) {
                player = AVPlayer(URL: url)
                playerView.player = player
                setupTimeObserver()
                if session.currentPosition > 0 {
                    player?.seekToTime(CMTimeMakeWithSeconds(session.currentPosition, 1))
                }
                player?.play()
            }
            
            window?.title = "WWDC \(session.year) | \(session.title)"
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName(NSWindowWillCloseNotification, object: self.window, queue: nil) { _ in
            player?.pause()
        }
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
