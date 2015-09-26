//
//  ViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ViewUtils

class VideosViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    
    var splitManager: SplitManager?
    
    var indexOfLastSelectedRow = -1
    let savedSearchTerm = Preferences.SharedPreferences().searchTerm
    var finishedInitialSetup = false
    var restoredSelection = false
    var loadedStoryboard = false
    
    lazy var headerController: VideosHeaderViewController! = VideosHeaderViewController.loadDefaultController()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        if splitManager == nil && loadedStoryboard {
            if let splitViewController = parentViewController as? NSSplitViewController {
                splitManager = SplitManager(splitView: splitViewController.splitView)
//                this caused a crash when running on 10.11...
//                splitViewController.splitView.delegate = self.splitManager
            }
        }
        
        loadedStoryboard = true
    }
    
    override func awakeAfterUsingCoder(aDecoder: NSCoder) -> AnyObject? {
        return super.awakeAfterUsingCoder(aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSearching()
        
        setupScrollView()

        tableView.gridColor = Theme.WWDCTheme.separatorColor
        
        loadSessions(refresh: false, quiet: false)
        
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserverForName(SessionProgressDidChangeNotification, object: nil, queue: nil) { _ in
            self.reloadTablePreservingSelection()
        }
        nc.addObserverForName(SessionFavoriteStatusDidChangeNotification, object: nil, queue: nil) { _ in
            self.reloadTablePreservingSelection()
        }
        nc.addObserverForName(VideoStoreNotificationDownloadStarted, object: nil, queue: NSOperationQueue.mainQueue()) { _ in
            self.reloadTablePreservingSelection()
        }
        nc.addObserverForName(VideoStoreNotificationDownloadFinished, object: nil, queue: NSOperationQueue.mainQueue()) { _ in
            self.reloadTablePreservingSelection()
        }
        nc.addObserverForName(VideoStoreDownloadedFilesChangedNotification, object: nil, queue: NSOperationQueue.mainQueue()) { _ in
            self.reloadTablePreservingSelection()
        }
        nc.addObserverForName(AutomaticRefreshPreferenceChangedNotification, object: nil, queue: NSOperationQueue.mainQueue()) { _ in
            self.setupAutomaticSessionRefresh()
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if finishedInitialSetup {
            return
        }
        
        GRLoadingView.showInWindow(self.view.window!)
        
        finishedInitialSetup = true
    }
    
    func setupScrollView() {
        let insetHeight = NSHeight(headerController.view.frame)
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: insetHeight, left: 0, bottom: 0, right: 0)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateScrollInsets:", name: LiveEventBannerVisibilityChangedNotification, object: nil)
        
        setupViewHeader(insetHeight)
    }
    
    func updateScrollInsets(note: NSNotification?) {
        if let bannerController = LiveEventBannerViewController.DefaultController {
            scrollView.contentInsets = NSEdgeInsets(top: scrollView.contentInsets.top, left: 0, bottom: bannerController.barHeight, right: 0)
        }
    }
    
    func setupViewHeader(insetHeight: CGFloat) {
        if let superview = scrollView.superview {
            superview.addSubview(headerController.view)
            headerController.view.frame = CGRectMake(0, NSHeight(superview.frame)-insetHeight, NSWidth(superview.frame), insetHeight)
            headerController.view.autoresizingMask = [NSAutoresizingMaskOptions.ViewWidthSizable, NSAutoresizingMaskOptions.ViewMinYMargin]
            headerController.performSearch = search
        }
        
        // show search term from previous launch in search bar
        headerController.searchBar.stringValue = savedSearchTerm
    }

    var sessions: [Session]! {
        didSet {
            if sessions != nil {
                // run transcript indexing service if needed
                TranscriptStore.SharedStore.runIndexerIfNeeded(sessions)
                
                headerController.enable()
                
                // restore search from previous launch
                if  savedSearchTerm != "" {
                    search(savedSearchTerm)
                    indexOfLastSelectedRow = Preferences.SharedPreferences().selectedSession
                }
                
                searchController.sessions = sessions
            }
            
            if savedSearchTerm == "" {
                reloadTablePreservingSelection()
            }
        }
    }

    // MARK: Session loading
    
    func loadSessions(refresh refresh: Bool, quiet: Bool) {
        if !quiet {
            if let window = view.window {
                GRLoadingView.showInWindow(window)
            }
        }
        
        let completionHandler: DataStore.fetchSessionsCompletionHandler = { success, sessions in
            dispatch_async(dispatch_get_main_queue()) {
                self.sessions = sessions
                
                self.splitManager?.restoreDividerPosition()
                self.splitManager?.startSavingDividerPosition()
                
                if !quiet {
                    GRLoadingView.dismissAllAfterDelay(0.3)
                }

                self.setupAutomaticSessionRefresh()
            }
        }
        
        DataStore.SharedStore.fetchSessions(completionHandler, disableCache: refresh)
    }
    
    @IBAction func refresh(sender: AnyObject?) {
        loadSessions(refresh: true, quiet: false)
    }
    
    var sessionListRefreshTimer: NSTimer?
    
    func setupAutomaticSessionRefresh() {
        if Preferences.SharedPreferences().automaticRefreshEnabled {
            if sessionListRefreshTimer == nil {
                sessionListRefreshTimer = NSTimer.scheduledTimerWithTimeInterval(Preferences.SharedPreferences().automaticRefreshInterval, target: self, selector: "sessionListRefreshFromTimer", userInfo: nil, repeats: true)
            }
        } else {
            sessionListRefreshTimer?.invalidate()
            sessionListRefreshTimer = nil
        }
    }
    
    func sessionListRefreshFromTimer() {
        loadSessions(refresh: true, quiet: true)
    }
    
    // MARK: TableView
    
    func reloadTablePreservingSelection() {
        tableView.reloadData()
        
        if !restoredSelection {
            indexOfLastSelectedRow = Preferences.SharedPreferences().selectedSession
            restoredSelection = true
        }
        
        if indexOfLastSelectedRow > -1 {
            tableView.selectRowIndexes(NSIndexSet(index: indexOfLastSelectedRow), byExtendingSelection: false)
        }
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if let count = displayedSessions?.count {
            return count
        } else {
            return 0
        }
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeViewWithIdentifier("video", owner: tableView) as! VideoTableCellView
        
        if row > displayedSessions.count {
            return cell
        }
        
        cell.session = displayedSessions[row]

        return cell
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 40.0
    }
    
    func tableView(tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return tableView.makeViewWithIdentifier("row", owner: tableView) as? NSTableRowView
    }
    
    // MARK: Table Menu

    @IBAction func markAsWatchedMenuAction(sender: NSMenuItem) {
        // if there is only one row selected, change the status of the clicked row instead of using the selection
        if tableView.selectedRowIndexes.count < 2 {
            var session = displayedSessions[tableView.clickedRow]
            session.progress = 100
        } else {
            doMassiveSessionPropertyUpdate(.Progress(100))
        }
    }
    
    @IBAction func markAsUnwatchedMenuAction(sender: NSMenuItem) {
        // if there is only one row selected, change the status of the clicked row instead of using the selection
        if tableView.selectedRowIndexes.count < 2 {
            var session = displayedSessions[tableView.clickedRow]
            session.progress = 0
        } else {
            doMassiveSessionPropertyUpdate(.Progress(0))
        }
    }
    
    @IBAction func addToFavoritesMenuAction(sender: NSMenuItem) {
        // if there is only one row selected, change the status of the clicked row instead of using the selection
        if tableView.selectedRowIndexes.count < 2 {
            var session = displayedSessions[tableView.clickedRow]
            session.favorite = true
        } else {
            doMassiveSessionPropertyUpdate(.Favorite(true))
        }
    }
    
    @IBAction func removeFromFavoritesMenuAction(sender: NSMenuItem) {
        // if there is only one row selected, change the status of the clicked row instead of using the selection
        if tableView.selectedRowIndexes.count < 2 {
            var session = displayedSessions[tableView.clickedRow]
            session.favorite = false
        } else {
            doMassiveSessionPropertyUpdate(.Favorite(false))
        }
    }
    
    private let userInitiatedQ = dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.rawValue), 0)
    private enum MassiveUpdateProperty {
        case Progress(Double)
        case Favorite(Bool)
    }
    // changes the property of all selected sessions on a background queue
    private func doMassiveSessionPropertyUpdate(property: MassiveUpdateProperty) {
        dispatch_async(userInitiatedQ) {
            self.tableView.selectedRowIndexes.enumerateIndexesUsingBlock { idx, _ in
                let session = self.displayedSessions[idx]
                switch property {
                case .Progress(let progress):
                    session.setProgressWithoutSendingNotification(progress)
                case .Favorite(let favorite):
                    session.setFavoriteWithoutSendingNotification(favorite)
                }
            }
            dispatch_async(dispatch_get_main_queue()) {
                self.reloadTablePreservingSelection()
            }
        }
    }

    @IBAction func copyURL(sender: NSMenuItem) {
        var stringToCopy:String?
        
        if tableView.selectedRowIndexes.count < 2 && tableView.clickedRow >= 0 {
            let session = displayedSessions[tableView.clickedRow]
            stringToCopy = session.shareURL
        } else {
            stringToCopy = ""
            for idx in tableView.selectedRowIndexes {
                let session = self.displayedSessions[idx]
                stringToCopy? += session.shareURL
                if tableView.selectedRowIndexes.lastIndex != idx {
                    stringToCopy? += "\n"
                }
            }
        }
        
        if let string = stringToCopy {
            let pb = NSPasteboard.generalPasteboard()
            pb.clearContents()
            pb.writeObjects([string])
        }
    }
    
    @IBAction func copy(sender: NSMenuItem) {
        copyURL(sender)
    }
    
    // MARK: Navigation

    var detailsViewController: VideoDetailsViewController? {
        get {
            if let splitViewController = parentViewController as? NSSplitViewController {
                return splitViewController.childViewControllers[1] as? VideoDetailsViewController
            } else {
                return nil
            }
        }
    }
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        if let detailsVC = detailsViewController {
            detailsVC.selectedCount = tableView.selectedRowIndexes.count
        }
        
        if tableView.selectedRow >= 0 {

            Preferences.SharedPreferences().selectedSession = tableView.selectedRow
            
            indexOfLastSelectedRow = tableView.selectedRow

            let session = displayedSessions[tableView.selectedRow]
            if let detailsVC = detailsViewController {
                detailsVC.session = session
            }
        } else {
            if let detailsVC = detailsViewController {
                detailsVC.session = nil
            }
        }
    }
    
    // MARK: Search
    
    var searchController = SearchController()
    
    private func setupSearching() {
        searchController.searchDidFinishCallback = {
            dispatch_async(dispatch_get_main_queue()) {
                self.reloadTablePreservingSelection()
            }
        }
    }
    
    var currentSearchTerm: String? {
        didSet {
            if currentSearchTerm != nil {
                Preferences.SharedPreferences().searchTerm = currentSearchTerm!
            } else {
                Preferences.SharedPreferences().searchTerm = ""
            }
        }
    }
    
    func search(term: String) {
        currentSearchTerm = term
        
        searchController.searchFor(currentSearchTerm)
    }
    
    var displayedSessions: [Session]! {
        get {
            return searchController.displayedSessions
        }
    }
    
}

