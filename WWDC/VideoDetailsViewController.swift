//
//  VideoDetailsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import KVOController
import WWDCPlayer
import WWDCAppKit

class VideoDetailsViewController: NSViewController {
    
    var videoControllers: [NSWindowController] = []
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
    
    @IBOutlet weak var liveIndicatorView: RoundRectLabel! {
        didSet {
            liveIndicatorView.tintColor = Theme.WWDCTheme.liveColor
            liveIndicatorView.title = "LIVE"
            
            if #available(OSX 10.11, *) {
                liveIndicatorView.font = NSFont.systemFontOfSize(11.0, weight: NSFontWeightMedium)
            } else {
                liveIndicatorView.font = NSFont.systemFontOfSize(11.0)
            }
        }
    }
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var subtitleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var downloadController: DownloadProgressViewController!
    @IBOutlet weak var actionButtonsController: ActionButtonsViewController!
    @IBOutlet weak var topBarBackgroundView: GRWindowMovingView!
    @IBOutlet weak var topBarSeparatorView: SeparatorView!
    
    @IBOutlet weak var watchLiveButton: NSButton! {
        didSet {
            let pStyle = NSMutableParagraphStyle()
            pStyle.alignment = NSCenterTextAlignment
            let attrs = [
                NSFontAttributeName: NSFont.controlContentFontOfSize(13.0),
                NSForegroundColorAttributeName: NSColor.whiteColor(),
                NSParagraphStyleAttributeName: pStyle
            ]
            watchLiveButton.attributedTitle = NSAttributedString(string: "Watch Live", attributes: attrs)
            watchLiveButton.appearance = NSAppearance(named: "LiveButton")
            watchLiveButton.sizeToFit()
        }
    }
    
    private func updateUI() {
        if multipleSelection {
            handleMultipleSelection()
            return
        }
        
        watchLiveButton.hidden = true
        actionButtonsController.view.hidden = false
        downloadController.view.hidden = false
        
        actionButtonsController.session = session
        setupActionCallbacks()
        
        titleLabel.textColor = NSColor.labelColor()
        
        if let session = self.session {
            titleLabel.stringValue = session.title
            subtitleLabel.stringValue = "\(session.track) | Session \(session.id)"
            descriptionLabel.stringValue = session.summary
            descriptionLabel.hidden = false
            
            restoreColors()
            
            downloadController.session = session
            downloadController.downloadFinishedCallback = { [unowned self] in
                self.updateUI()
            }
            
            if let schedule = session.schedule {
                showScheduledState(schedule)
            }
        } else {
            titleLabel.stringValue = "No session selected"
            subtitleLabel.stringValue = "Select a session to see It here"
            descriptionLabel.hidden = true
            downloadController.session = nil
            
            restoreColors()
        }
        
        setupTranscriptResultsViewIfNeeded()
        updateTranscriptsViewController()
    }
    
    private func showScheduledState(schedule: ScheduledSession) {
        guard let track = schedule.track else { return }
        
        watchLiveButton.hidden = false
        actionButtonsController.view.hidden = true
        
        topBarBackgroundView.backgroundColor = NSColor(hexString: track.darkColor)
        topBarSeparatorView.backgroundColor = NSColor.blackColor()
        titleLabel.textColor = NSColor(hexString: track.titleColor)
        subtitleLabel.textColor = NSColor(hexString: track.color)
        
        updateLiveState()
    }
    
    @objc private func updateLiveState(note: NSNotification? = nil) {
        guard let schedule = session?.schedule else {
            watchLiveButton.enabled = false
            liveIndicatorView.hidden = true
            return
        }
        
        watchLiveButton.enabled = schedule.isLive
        liveIndicatorView.hidden = !schedule.isLive
    }
    
    @IBAction func watchLive(sender: NSButton) {
        guard let liveSession = session?.schedule?.liveSession else { return }
        
        let playerVC = VideoPlayerViewController.withLiveSession(liveSession)
        let playerWindowController = VideoPlayerWindowController(playerViewController: playerVC)
        
        videoControllers.append(playerWindowController)
        followWindowLifecycle(playerWindowController.window)
        
        playerWindowController.showWindow(sender)
    }
    
    private func restoreColors() {
        titleLabel.textColor = NSColor.labelColor()
        subtitleLabel.textColor = NSColor.secondaryLabelColor()
        topBarBackgroundView.backgroundColor = NSColor.whiteColor()
        topBarSeparatorView.backgroundColor = Theme.WWDCTheme.separatorColor
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
            return (videoWC as? VideoWindowController)?.session?.uniqueId == session.uniqueId
        }

        return filteredControllers.first as? VideoWindowController
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
                let controller = window.windowController
                
                if controller is VideoWindowController || controller is VideoPlayerWindowController {
                    self.videoControllers.remove(controller!)
                } else if let controller = window.windowController as? PDFWindowController {
                    self.slideControllers.remove(controller)
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUI()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(updateLiveState), name: LiveSessionsListDidChangeNotification, object: nil)
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
