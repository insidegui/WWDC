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
import EventKit

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
    
    fileprivate var transcriptSearchResultsVC: TranscriptSearchResultsController?
    
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
                liveIndicatorView.font = NSFont.systemFont(ofSize: 11.0, weight: NSFontWeightMedium)
            } else {
                liveIndicatorView.font = NSFont.systemFont(ofSize: 11.0)
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
            if #available(OSX 10.11, *) {
                let pStyle = NSMutableParagraphStyle()
                pStyle.alignment = NSCenterTextAlignment
                
                let attrs = [
                    NSFontAttributeName: NSFont.controlContentFont(ofSize: 13.0),
                    NSForegroundColorAttributeName: NSColor.white,
                    NSParagraphStyleAttributeName: pStyle
                ]
                watchLiveButton.attributedTitle = NSAttributedString(string: "Watch Live", attributes: attrs)
                
                watchLiveButton.appearance = NSAppearance(named: "LiveButton")
                watchLiveButton.sizeToFit()
            }
        }
    }
    @IBOutlet weak var reminderButton: NSButton!
    
    fileprivate func updateUI() {
        if let session = session {
            guard !session.isInvalidated else { return }
        }
        
        if multipleSelection {
            handleMultipleSelection()
            return
        }
        
        watchLiveButton.isHidden = true
        reminderButton.isHidden = true
        downloadController.view.isHidden = false
        
        actionButtonsController.session = session
        setupActionCallbacks()
        
        titleLabel.textColor = NSColor.labelColor
        
        if let session = self.session {
            actionButtonsController.view.isHidden = false
            titleLabel.stringValue = session.title
            subtitleLabel.stringValue = "\(session.track) | Session \(session.id)"
            descriptionLabel.stringValue = session.summary
            descriptionLabel.isHidden = false
            
            restoreColors()
            
            downloadController.session = session
            downloadController.downloadFinishedCallback = { [unowned self] in
                self.updateUI()
            }
            
            if let schedule = session.schedule, session.isScheduled {
                showScheduledState(schedule)
            }
        } else {
            actionButtonsController.view.isHidden = true
            titleLabel.stringValue = "No session selected"
            subtitleLabel.stringValue = "Select a session to see It here"
            descriptionLabel.isHidden = true
            downloadController.session = nil
            
            restoreColors()
        }
        
        setupTranscriptResultsViewIfNeeded()
        updateTranscriptsViewController()
    }
    
    fileprivate func showScheduledState(_ schedule: ScheduledSession) {
        guard let track = schedule.track else { return }
        
        watchLiveButton.isHidden = false
        reminderButton.isHidden = false
        actionButtonsController.view.isHidden = true
        
        topBarBackgroundView.backgroundColor = NSColor(hexString: track.darkColor)
        topBarSeparatorView.backgroundColor = NSColor.black
        titleLabel.textColor = NSColor(hexString: track.titleColor)
        subtitleLabel.textColor = NSColor(hexString: track.color)
        
        updateLiveState()
        updateReminderButton()
    }
    
    @objc fileprivate func updateReminderButton() {
        DispatchQueue.main.async {
            guard let schedule = self.session?.schedule else { return }
            
            self.reminderButton.isEnabled = true
            
            self.calendarHelper.hasReminderForScheduledSession(schedule) { [weak self] hasReminder in
                if hasReminder {
                    self?.reminderButton.title = "Remove Reminder"
                    self?.reminderButton.tag = 1
                } else {
                    self?.reminderButton.title = "Create Reminder"
                    self?.reminderButton.tag = 0
                }
            }
        }
    }
    
    fileprivate lazy var startDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        
        formatter.locale = Locale(identifier: "en")
        formatter.dateFormat = "EEEE 'at' "
        
        return formatter
    }()
    
    fileprivate lazy var startTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        
        formatter.timeStyle = .short
        
        return formatter
    }()
    
    @objc fileprivate func updateLiveState(_ note: Notification? = nil) {
        guard let schedule = session?.schedule else {
            watchLiveButton.isEnabled = false
            liveIndicatorView.isHidden = true
            return
        }
        
        let tooltip: String
        if schedule.isLive {
            tooltip = "This session is live streaming right now, click to watch!"
        } else {
            tooltip = "This session will be live streamed! Come back on " + startDateFormatter.string(from: schedule.startsAt as Date) + startTimeFormatter.string(from: schedule.startsAt as Date) + " to watch It."
        }
        
        watchLiveButton.toolTip = tooltip
        
        watchLiveButton.isEnabled = schedule.isLive
        liveIndicatorView.isHidden = !schedule.isLive
    }
    
    @IBAction func watchLive(_ sender: NSButton) {
        guard let liveSession = session?.schedule?.liveSession else { return }
        
        let playerVC = VideoPlayerViewController.withLiveSession(liveSession)
        let playerWindowController = VideoPlayerWindowController(playerViewController: playerVC)
        
        videoControllers.append(playerWindowController)
        followWindowLifecycle(playerWindowController.window)
        
        playerWindowController.showWindow(sender)
    }
    
    fileprivate lazy var calendarHelper = CalendarHelper()
    
    @IBAction func reminderButtonAction(_ sender: NSButton) {
        guard let schedule = session?.schedule else { return }
        
        sender.isEnabled = false
        
        if sender.tag == 0 {
            calendarHelper.registerReminderForScheduledSession(schedule)
        } else {
            calendarHelper.unregisterReminderForScheduledSession(schedule)
        }
    }
    
    fileprivate func restoreColors() {
        titleLabel.textColor = NSColor.labelColor
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        topBarBackgroundView.backgroundColor = .white
        topBarSeparatorView.backgroundColor = Theme.WWDCTheme.separatorColor
    }
    
    fileprivate func setupTranscriptResultsViewIfNeeded() {
        guard transcriptSearchResultsVC == nil else { return }
        transcriptSearchResultsVC = TranscriptSearchResultsController()
        transcriptSearchResultsVC!.view.frame = self.transcriptControllerContainerView.bounds
        transcriptSearchResultsVC!.view.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        transcriptSearchResultsVC!.playCallback = { [unowned self] time in
            self.watchVideo(time)
        }
        self.transcriptControllerContainerView.addSubview(transcriptSearchResultsVC!.view)
    }
    
    fileprivate func updateTranscriptsViewController() {
        guard let term = searchTerm else {
            transcriptSearchResultsVC?.lines = nil
            return
        }
        
        guard term != "" else {
            transcriptSearchResultsVC?.lines = nil
            return
        }
        
        if let relevantLines = session?.transcript?.lines.filter("text CONTAINS[c] %@", searchTerm!), relevantLines.count > 0 {
            transcriptSearchResultsVC?.lines = relevantLines
            transcriptControllerContainerView.isHidden = false
        } else {
            transcriptSearchResultsVC?.lines = nil
            transcriptControllerContainerView.isHidden = true
        }
        
    }
    
    fileprivate func handleMultipleSelection() {
        restoreColors()
        
        liveIndicatorView.isHidden = true
        watchLiveButton.isHidden = true
        reminderButton.isHidden = true
        titleLabel.stringValue = "\(selectedCount) sessions selected"
        subtitleLabel.stringValue = ""
        descriptionLabel.isHidden = true
        actionButtonsController.view.isHidden = true
        downloadController.view.isHidden = true
        transcriptControllerContainerView.isHidden = true
    }
    
    fileprivate func setupActionCallbacks() {
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
            guard !self.session!.videoURL.isEmpty else {
                self.showVideoNotAvailableAlert()
                return
            }
            
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
    
    fileprivate func showVideoNotAvailableAlert() {
        let alert = NSAlert()
        alert.messageText = "Video not available"
        alert.informativeText = "The video for this session is not available yet, please come back later to watch it. You can try refreshing now to see if it became available (⌘R)."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    fileprivate func playerControllerForSession(_ session: Session) -> VideoWindowController? {
        let filteredControllers = videoControllers.filter { videoWC in
            return (videoWC as? VideoWindowController)?.session?.uniqueId == session.uniqueId
        }

        return filteredControllers.first as? VideoWindowController
    }
    
    fileprivate func watchVideo(_ startTime: Double) {
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
    
    fileprivate func doWatchVideo(_ sender: AnyObject?, url: String, startTime: Double?) {
        let playerWindowController = VideoWindowController(session: session!, videoURL: url, startTime: startTime)
        playerWindowController.showWindow(sender)
        followWindowLifecycle(playerWindowController.window)
        videoControllers.append(playerWindowController)
    }
    
    fileprivate func followWindowLifecycle(_ window: NSWindow!) {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSWindowWillClose, object: window, queue: nil) { note in
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateLiveState), name: NSNotification.Name(rawValue: LiveSessionsListDidChangeNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateReminderButton), name: NSNotification.Name.EKEventStoreChanged, object: nil)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        setupSplitDetailBehavior()
    }
    
    // MARK: - SplitView containment
    
    fileprivate struct SplitBehaviorMetrics {
        struct Collapsed {
            static let titleTopConstant = CGFloat(28.0)
            static let heightConstant = CGFloat(74.0)
        }
        struct Expanded {
            static let titleTopConstant = CGFloat(16.0)
            static let heightConstant = CGFloat(62.0)
        }
    }
    
    fileprivate func setupSplitDetailBehavior() {
        guard let splitController = parent as? NSSplitViewController, splitController.splitViewItems.count == 2 else { return }
        
        kvoController.observe(splitController.splitViewItems[0], keyPath: "collapsed", options: [.initial, .new], action: #selector(splitViewCollapsedStatusDidChange))
    }
    
    @objc fileprivate func splitViewCollapsedStatusDidChange() {
        NSAnimationContext.runAnimationGroup({ _ in
            let sidebarSplitItem = (self.parent as! NSSplitViewController).splitViewItems[0]
            
            if sidebarSplitItem.isCollapsed {
                self.titleTopConstraint.animator().constant = SplitBehaviorMetrics.Collapsed.titleTopConstant
                self.topBarHeightConstraint.animator().constant = SplitBehaviorMetrics.Collapsed.heightConstant
            } else {
                self.titleTopConstraint.animator().constant = SplitBehaviorMetrics.Expanded.titleTopConstant
                self.topBarHeightConstraint.animator().constant = SplitBehaviorMetrics.Expanded.heightConstant
            }
        }, completionHandler: nil)
    }
    
}
