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
    
    
    var selectedCount = 1 {
        didSet {
            updateUI()
        }
    }
    var multipleSelection: Bool {
        get {
            return selectedCount > 1
        }
    }
    var session: Session? {
        didSet {
            updateUI()
        }
    }
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var subtitleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet var downloadController: DownloadProgressViewController!
    @IBOutlet var actionButtonsController: ActionButtonsViewController!
    
    private func updateUI()
    {
        if multipleSelection {
            handleMultipleSelection()
            return
        }
        
        actionButtonsController.view.hidden = false
        downloadController.view.hidden = false
        
        actionButtonsController.session = session
        setupActionCallbacks()
        
        if let session = self.session {
            titleLabel.stringValue = session.title
            subtitleLabel.stringValue = "\(session.track) | Session \(session.id)"
            descriptionLabel.stringValue = session.description
            descriptionLabel.hidden = false
            
            downloadController.session = session
            downloadController.downloadFinishedCallback = { [unowned self] in
                self.updateUI()
            }
        } else {
            titleLabel.stringValue = "No session selected"
            subtitleLabel.stringValue = "Select a session to see It here"
            descriptionLabel.hidden = true
        }
    }
    
    private func handleMultipleSelection()
    {
        titleLabel.stringValue = "\(selectedCount) sessions selected"
        subtitleLabel.stringValue = ""
        descriptionLabel.hidden = true
        actionButtonsController.view.hidden = true
        downloadController.view.hidden = true
    }
    
    private func setupActionCallbacks()
    {
        actionButtonsController.watchHDVideoCallback = { [unowned self] in
            if self.session!.hd_url != nil {
                if VideoStore.SharedStore().hasVideo(self.session!.hd_url!) {
                    self.doWatchVideo(nil, url: VideoStore.SharedStore().localVideoAbsoluteURLString(self.session!.hd_url!))
                } else {
                    self.doWatchVideo(nil, url: self.session!.hd_url!)
                }
            }
        }
        
        actionButtonsController.watchVideoCallback = { [unowned self] in
            self.doWatchVideo(nil, url: self.session!.url)
        }
        
        actionButtonsController.showSlidesCallback = { [unowned self] in
            if self.session!.slides != nil {
                let slidesWindowController = PDFWindowController(session: self.session!)
                slidesWindowController.showWindow(nil)
                self.followWindowLifecycle(slidesWindowController.window)
                self.auxWindowControllers.append(slidesWindowController)
            }
        }
        
        actionButtonsController.toggleWatchedCallback = { [unowned self] in
            if self.session!.progress < 100 {
                self.session!.progress = 100
            } else {
                self.session!.progress = 0
            }
        }
        
        actionButtonsController.afterCallback = { [unowned self] in
            self.actionButtonsController.session = self.session
        }
    }
    
    private func doWatchVideo(sender: AnyObject?, url: String)
    {
        let playerWindowController = VideoWindowController(session: session!, videoURL: url)
        playerWindowController.showWindow(sender)
        followWindowLifecycle(playerWindowController.window)
        auxWindowControllers.append(playerWindowController)
    }
    
    private func followWindowLifecycle(window: NSWindow!) {
        NSNotificationCenter.defaultCenter().addObserverForName(NSWindowWillCloseNotification, object: window, queue: nil) { note in
            if let window = note.object as? NSWindow {
                if let controller = window.windowController {
                    self.auxWindowControllers.remove(controller)
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUI()
    }
    
    
    
}
