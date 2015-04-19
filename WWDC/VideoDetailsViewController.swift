//
//  VideoDetailsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class VideoDetailsViewController: NSViewController {
    
    var players: [VideoWindowController] = []
    
    var session: Session? {
        didSet {
            if let session = session {
                titleLabel.stringValue = session.title
                subtitleLabel.stringValue = "\(session.track) | Session \(session.id)"
                descriptionLabel.stringValue = session.description
                descriptionLabel.hidden = false
                watchVideoButton.hidden = false
                if session.slides != nil {
                    viewSlidesButton.hidden = false
                }
                if session.progress > 0 && session.progress < 1 {
                    markAsUnwatchedButton.hidden = false
                }
            } else {
                titleLabel.stringValue = "No session selected"
                subtitleLabel.stringValue = "Select a session to see It here"
                descriptionLabel.hidden = true
                watchVideoButton.hidden = true
                viewSlidesButton.hidden = true
                markAsUnwatchedButton.hidden = true
            }
        }
    }
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var subtitleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var watchVideoButton: NSButton!
    @IBOutlet weak var viewSlidesButton: NSButton!
    @IBOutlet weak var markAsUnwatchedButton: NSButton!
    
    @IBAction func watchVideo(sender: NSButton) {
        let playerVC = VideoWindowController(session: session!)
        players.append(playerVC)
        playerVC.showWindow(sender)
        
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserverForName(NSWindowWillCloseNotification, object: playerVC.window!, queue: nil) { _ in
            self.players.removeObject(playerVC)
        }
    }
    
    @IBAction func viewSlides(sender: NSButton) {
        if let url = NSURL(string: session!.slides!) {
            NSWorkspace.sharedWorkspace().openURL(url)
        }
    }
    
    @IBAction func markAsUnwatched(sender: NSButton) {
        session?.progress = 0
        sender.hidden = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}
