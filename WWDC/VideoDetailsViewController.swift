//
//  VideoDetailsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class VideoDetailsViewController: NSViewController {
    
    var auxWindowControllers: [NSWindowController] = []
    
    var session: Session? {
        didSet {
            updateUI()
        }
    }
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var subtitleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var watchVideoButton: NSButton!
    @IBOutlet weak var viewSlidesButton: NSButton!
    @IBOutlet weak var markAsUnwatchedButton: NSButton!
    
    private func updateUI()
    {
        if let session = self.session {
            titleLabel.stringValue = session.title
            subtitleLabel.stringValue = "\(session.track) | Session \(session.id)"
            descriptionLabel.stringValue = session.description
            descriptionLabel.hidden = false
            watchVideoButton.hidden = false
            if session.slides != nil {
                viewSlidesButton.hidden = false
            } else {
                viewSlidesButton.hidden = true
            }
            if session.progress > 0 && session.progress < 1 {
                markAsUnwatchedButton.hidden = false
            } else {
                markAsUnwatchedButton.hidden = true
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
    
    @IBAction func watchVideo(sender: NSButton) {
        let playerWindowController = VideoWindowController(session: session!)
        playerWindowController.showWindow(sender)
        followWindowLifecycle(playerWindowController.window)
        auxWindowControllers.append(playerWindowController)
    }
    
    @IBAction func viewSlides(sender: NSButton) {
        if session!.slides != nil {
            let slidesWindowController = PDFWindowController(session: session!)
            slidesWindowController.showWindow(sender)
            followWindowLifecycle(slidesWindowController.window)
            auxWindowControllers.append(slidesWindowController)
        }
    }
    
    private func followWindowLifecycle(window: NSWindow!) {
        NSNotificationCenter.defaultCenter().addObserverForName(NSWindowWillCloseNotification, object: window, queue: nil) { note in
            if let window = note.object as? NSWindow {
                if let controller = window.windowController() as? NSWindowController {
                    self.auxWindowControllers.removeObject(controller)
                }
            }
        }
    }
    
    @IBAction func markAsUnwatched(sender: NSButton) {
        session?.progress = 0
        sender.hidden = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUI()
    }
    
}
