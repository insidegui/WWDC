//
//  VideoDetailsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import KVOController

class VideoDetailsViewController: NSViewController {
    
    var videoControllers: [VideoWindowController] = []
    var slideControllers: [PDFWindowController] = []
    
    @IBOutlet weak var topBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleTopConstraint: NSLayoutConstraint!
    
    var searchTerm: String? {
        didSet {
            updateTranscriptsViewController()
        }
    }
    
    private var transcriptSearchResultsVC: TranscriptSearchResultsController?
    
    @IBOutlet weak var transcriptControllerContainerView: NSView!
    
    var selectedCount = 1
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
    @IBOutlet weak var downloadController: DownloadProgressViewController!
    @IBOutlet weak var actionButtonsController: ActionButtonsViewController!
    
    private func updateUI() {
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
            descriptionLabel.stringValue = session.summary
            descriptionLabel.hidden = false
            
            downloadController.session = session
            downloadController.downloadFinishedCallback = { [unowned self] in
                self.updateUI()
            }
        } else {
            titleLabel.stringValue = "No session selected"
            subtitleLabel.stringValue = "Select a session to see It here"
            descriptionLabel.hidden = true
            downloadController.session = nil
        }
        
        setupTranscriptResultsViewIfNeeded()
        updateTranscriptsViewController()
    }
    
    private func setupTranscriptResultsViewIfNeeded() {
        guard transcriptSearchResultsVC == nil else { return }
        transcriptSearchResultsVC = TranscriptSearchResultsController()
        transcriptSearchResultsVC!.view.frame = self.transcriptControllerContainerView.bounds
        transcriptSearchResultsVC!.view.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
        transcriptSearchResultsVC!.playCallback = { [unowned self] time in
            self.watchVideo(time)
        }
        self.transcriptControllerContainerView.addSubview(transcriptSearchResultsVC!.view)
    }
    
    private func updateTranscriptsViewController() {
        guard let term = searchTerm else {
            transcriptSearchResultsVC?.lines = nil
            return
        }
        
        guard term != "" else {
            transcriptSearchResultsVC?.lines = nil
            return
        }
        transcriptSearchResultsVC?.lines = session?.transcript?.lines.filter("text CONTAINS[c] %@", searchTerm!)
    }
    
    private func handleMultipleSelection() {
        titleLabel.stringValue = "\(selectedCount) sessions selected"
        subtitleLabel.stringValue = ""
        descriptionLabel.hidden = true
        actionButtonsController.view.hidden = true
        downloadController.view.hidden = true
    }
    
    private func setupActionCallbacks() {
        actionButtonsController.watchHDVideoCallback = { [unowned self] in
            if self.session!.hd_url != nil {
                if VideoStore.SharedStore().hasVideo(self.session!.hd_url!) {
                    self.doWatchVideo(nil, url: VideoStore.SharedStore().localVideoAbsoluteURLString(self.session!.hd_url!), startTime: nil)
                } else {
                    self.doWatchVideo(nil, url: self.session!.hd_url!, startTime: nil)
                }
            }
        }
        
        actionButtonsController.watchVideoCallback = { [unowned self] in
            self.doWatchVideo(nil, url: self.session!.videoURL, startTime: nil)
        }
        
        actionButtonsController.showSlidesCallback = { [unowned self] in
            if self.session!.slidesURL != "" {
                let slidesWindowController = PDFWindowController(session: self.session!)
                slidesWindowController.showWindow(nil)
                self.followWindowLifecycle(slidesWindowController.window)
                self.slideControllers.append(slidesWindowController)
            }
        }
        
        actionButtonsController.toggleWatchedCallback = { [unowned self] in
            WWDCDatabase.sharedDatabase.doChanges {
                if self.session!.progress < 100 {
                    self.session!.progress = 100
                } else {
                    self.session!.progress = 0
                }
            }
        }
        
        actionButtonsController.afterCallback = { [unowned self] in
            self.actionButtonsController.session = self.session
        }
    }
    
    private func playerControllerForSession(session: Session) -> VideoWindowController? {
        let filteredControllers = videoControllers.filter { videoWC in
            return videoWC.session?.uniqueId == session.uniqueId
        }

        return filteredControllers.first
    }
    
    private func watchVideo(startTime: Double) {
        if let existingController = playerControllerForSession(session!) {
            existingController.seekTo(startTime)
            return
        }
        
        if session!.hd_url != nil {
            if VideoStore.SharedStore().hasVideo(session!.hd_url!) {
                doWatchVideo(nil, url: VideoStore.SharedStore().localVideoAbsoluteURLString(session!.hd_url!), startTime: startTime)
            } else {
                doWatchVideo(nil, url: session!.videoURL, startTime: startTime)
            }
        } else {
            doWatchVideo(nil, url: session!.videoURL, startTime: startTime)
        }
    }
    
    private func doWatchVideo(sender: AnyObject?, url: String, startTime: Double?) {
        let playerWindowController = VideoWindowController(session: session!, videoURL: url, startTime: startTime)
        playerWindowController.showWindow(sender)
        followWindowLifecycle(playerWindowController.window)
        videoControllers.append(playerWindowController)
    }
    
    private func followWindowLifecycle(window: NSWindow!) {
        NSNotificationCenter.defaultCenter().addObserverForName(NSWindowWillCloseNotification, object: window, queue: nil) { note in
            if let window = note.object as? NSWindow {
                if let controller = window.windowController as? VideoWindowController {
                    self.videoControllers.remove(controller)
                } else if let controller = window.windowController as? PDFWindowController {
                    self.slideControllers.remove(controller)
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUI()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        setupSplitDetailBehavior()
    }
    
    // MARK: - SplitView containment
    
    private struct SplitBehaviorMetrics {
        struct Collapsed {
            static let titleTopConstant = CGFloat(28.0)
            static let heightConstant = CGFloat(74.0)
        }
        struct Expanded {
            static let titleTopConstant = CGFloat(16.0)
            static let heightConstant = CGFloat(62.0)
        }
    }
    
    private func setupSplitDetailBehavior() {
        guard let splitController = parentViewController as? NSSplitViewController where splitController.splitViewItems.count == 2 else { return }
        
        KVOController.observe(splitController.splitViewItems[0], keyPath: "collapsed", options: [.Initial, .New], action: #selector(splitViewCollapsedStatusDidChange))
    }
    
    @objc private func splitViewCollapsedStatusDidChange() {
        NSAnimationContext.runAnimationGroup({ _ in
            let sidebarSplitItem = (self.parentViewController as! NSSplitViewController).splitViewItems[0]
            
            if sidebarSplitItem.collapsed {
                self.titleTopConstraint.animator().constant = SplitBehaviorMetrics.Collapsed.titleTopConstant
                self.topBarHeightConstraint.animator().constant = SplitBehaviorMetrics.Collapsed.heightConstant
            } else {
                self.titleTopConstraint.animator().constant = SplitBehaviorMetrics.Expanded.titleTopConstant
                self.topBarHeightConstraint.animator().constant = SplitBehaviorMetrics.Expanded.heightConstant
            }
        }, completionHandler: nil)
    }
    
}
