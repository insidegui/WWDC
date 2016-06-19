//
//  ViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import WWDCAppKit
import RealmSwift

class VideosViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var scrollView: GRScrollView!
    @IBOutlet weak var tableView: NSTableView!
    
    var splitManager: SplitManager?
    
    var finishedInitialSetup = false
    var loadedStoryboard = false
    
    lazy var headerController: VideosHeaderViewController! = VideosHeaderViewController.loadDefaultController()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        if splitManager == nil && loadedStoryboard {
            if let splitViewController = parentViewController as? NSSplitViewController {
                splitManager = SplitManager(splitView: splitViewController.splitView)
            }
        }
        
        loadedStoryboard = true
    }
    
    override func awakeAfterUsingCoder(aDecoder: NSCoder) -> AnyObject? {
        return super.awakeAfterUsingCoder(aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupScrollView()

        tableView.gridColor = Theme.WWDCTheme.separatorColor
        loadSessions(refresh: false, quiet: false)
        
        let nc = NSNotificationCenter.defaultCenter()

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

       setupViewHeader(insetHeight)
        setupFilterBar()
    }
    
    func setupViewHeader(insetHeight: CGFloat) {
        guard let superview = scrollView.superview else { return }

        superview.addSubview(headerController.view)
        headerController.view.frame = CGRectMake(0, NSHeight(superview.frame)-insetHeight, NSWidth(superview.frame), insetHeight)
        headerController.view.autoresizingMask = [NSAutoresizingMaskOptions.ViewWidthSizable, NSAutoresizingMaskOptions.ViewMinYMargin]
        headerController.performSearch = search
    }
    
    var searchTermFilter: SearchFilter? {
        didSet {
            applySearchFilters()
        }
    }
    
    var searchFilters: SearchFilters = [] {
        didSet {
            applySearchFilters()
        }
    }
    
    private func applySearchFilters() {
        fetchLocalSessions()
        
        for filter in searchFilters {
            sessions = (sessions as NSArray).filteredArrayUsingPredicate(filter.predicate) as! [Session]
        }
        
        if let termFilter = searchTermFilter {
            sessions = (sessions as NSArray).filteredArrayUsingPredicate(termFilter.predicate) as! [Session]
        }
    }
    
    var filterBarController: FilterBarController?
    func setupFilterBar() {
        guard let superview = scrollView.superview else { return }
        
        filterBarController = FilterBarController(scrollView: scrollView)
        superview.addSubview(filterBarController!.view, positioned: .Below, relativeTo: headerController.view)
        filterBarController!.view.frame = CGRectMake(0, NSHeight(superview.frame)-NSHeight(headerController.view.frame), NSWidth(superview.frame), 44.0)
        filterBarController!.view.autoresizingMask = [.ViewWidthSizable, .ViewMinYMargin]
        
        filterBarController!.filtersDidChangeCallback = { [weak self] in
            guard let weakSelf = self else { return }
            weakSelf.searchFilters = weakSelf.filterBarController!.filters
        }
    }

    var sessions: Array<Session>! {
        didSet {
            guard sessions != nil else { return }
            
            headerController.enable()
            
            reloadTablePreservingSelection()
        }
    }
    
    // MARK: Table View Menu Validation
    
    private enum TableViewMenuItemTags: Int {
        case Watched = 1000
        case Unwatched = 1001
        case Favorite = 1002
        case RemoveFavorite = 1003
        case Download = 1004
        case RemoveDownload = 1005
        case CopyURL = 1006
    }
    
    override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        guard let item = TableViewMenuItemTags(rawValue: menuItem.tag) else { return false }
        
        // this validation only applies to the row where the right-click happened, not when many rows are selected
        guard tableView.selectedRowIndexes.count <= 1 else { return true }
        
        let tableViewRow = tableView.clickedRow
        let session = sessions[tableViewRow]
        
        guard !session.invalidated else { return false }
        
        switch item {
        case .Watched:
            return session.progress != 100
            
        case .Unwatched:
            return session.progress == 100
            
        case .Favorite:
            return session.favorite ? false : true
            
        case .RemoveFavorite:
            return session.favorite
            
        case .Download:
            return self.validateDownloadMenuItemsFrom(session).shouldEnableDownload
            
        case .RemoveDownload:
            return self.validateDownloadMenuItemsFrom(session).shouldEnableRemoveDownload
            
        case .CopyURL:
            return true
        }
    }
    
    func validateDownloadMenuItemsFrom(session: Session) -> (shouldEnableDownload: Bool, shouldEnableRemoveDownload:Bool) {
        guard !session.invalidated else { return (false, false) }
        
        if session.year < 2013 {
            return (false, false)
        }
        
        if VideoStore.SharedStore().isDownloading(session.hdVideoURL) {
            return (false, true)
        }
        
        if session.isScheduled == false {
            return (session.downloaded ? false:true, session.downloaded)
        } else {
            return (false, false)
        }
    }

    // MARK: Session loading
        
    func loadSessions(refresh refresh: Bool, quiet: Bool) {
        if !quiet {
            if let window = view.window {
                GRLoadingView.showInWindow(window)
            }
        }
        
        fetchLocalSessions()
        
        WWDCDatabase.sharedDatabase.transcriptIndexingStartedCallback = { [weak self] in
            self?.headerController.progress = WWDCDatabase.sharedDatabase.transcriptIndexingProgress
        }
        WWDCDatabase.sharedDatabase.sessionListChangedCallback = { [weak self] newSessionKeys in
            print("\(newSessionKeys.count) new session(s) available")

            GRLoadingView.dismissAllAfterDelay(0.3)
            
            self?.fetchLocalSessions()
            
            self?.splitManager?.restoreDividerPosition()
            self?.splitManager?.startSavingDividerPosition()
            self?.setupAutomaticSessionRefresh()
            
            self?.restoreSearchIfNeeded()
        }
        WWDCDatabase.sharedDatabase.refresh()
        
        restoreSearchIfNeeded()
    }
    
    func restoreSearchIfNeeded() {
        applySearchFilters()
        
        guard let term = headerController.searchTerm else { return }
        
        mainQ { self.search(term) }
    }
    
    func fetchLocalSessions() {
        sessions = WWDCDatabase.sharedDatabase.standardSessionList.sort { session1, session2 in
            guard let schedule1 = session1.schedule, schedule2 = session2.schedule else { return false }
            
            return schedule1.startsAt.isLessThan(schedule2.startsAt)
        }
        filterBarController?.updateMenus()
        if sessions.count > 0 {
            GRLoadingView.dismissAllAfterDelay(0.3)
        }
    }
    
    @IBAction func refresh(sender: AnyObject?) {
        loadSessions(refresh: true, quiet: false)
    }
    
    var sessionListRefreshTimer: NSTimer?
    
    func setupAutomaticSessionRefresh() {
        if Preferences.SharedPreferences().automaticRefreshEnabled {
            if sessionListRefreshTimer == nil {
                sessionListRefreshTimer = NSTimer.scheduledTimerWithTimeInterval(Preferences.SharedPreferences().automaticRefreshInterval, target: self, selector: #selector(VideosViewController.sessionListRefreshFromTimer), userInfo: nil, repeats: true)
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
    
    private var selectionIndexesBeforeRefresh: NSIndexSet?
    
    func reloadTablePreservingSelection() {
        selectionIndexesBeforeRefresh = tableView.selectedRowIndexes
        
        tableView.reloadData()
        
        if let indexes = selectionIndexesBeforeRefresh {
            tableView.selectRowIndexes(indexes, byExtendingSelection: false)
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
        if row > displayedSessions.count {
            return nil
        }
        
        let session = displayedSessions[row]
        
        if session.isScheduled {
            return cellForScheduledSession(session)
        } else {
            return cellForRegularSession(session)
        }
    }
    
    private func cellForScheduledSession(session: Session) -> NSView? {
        let cell = tableView.makeViewWithIdentifier("scheduledSession", owner: tableView) as! ScheduledSessionTableCellView
        
        cell.session = session
        
        return cell
    }
    
    private func cellForRegularSession(session: Session) -> NSView? {
        let cell = tableView.makeViewWithIdentifier("video", owner: tableView) as! VideoTableCellView
        
        cell.session = session
        
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
            let session = displayedSessions[tableView.clickedRow]
            WWDCDatabase.sharedDatabase.doChanges {
                session.progress = 100
            }
        } else {
            doMassiveSessionPropertyUpdate(.Progress(100))
        }
    }
    
    @IBAction func markAsUnwatchedMenuAction(sender: NSMenuItem) {
        // if there is only one row selected, change the status of the clicked row instead of using the selection
        if tableView.selectedRowIndexes.count < 2 {
            let session = displayedSessions[tableView.clickedRow]
            WWDCDatabase.sharedDatabase.doChanges {
                session.progress = 0
            }
        } else {
            doMassiveSessionPropertyUpdate(.Progress(0))
        }
    }
    
    @IBAction func addToFavoritesMenuAction(sender: NSMenuItem) {
        // if there is only one row selected, change the status of the clicked row instead of using the selection
        if tableView.selectedRowIndexes.count < 2 {
            let session = displayedSessions[tableView.clickedRow]
            WWDCDatabase.sharedDatabase.doChanges {
                session.favorite = true
            }
        } else {
            doMassiveSessionPropertyUpdate(.Favorite(true))
        }
    }
    
    @IBAction func removeFromFavoritesMenuAction(sender: NSMenuItem) {
        // if there is only one row selected, change the status of the clicked row instead of using the selection
        if tableView.selectedRowIndexes.count < 2 {
            let session = displayedSessions[tableView.clickedRow]
            WWDCDatabase.sharedDatabase.doChanges {
                session.favorite = false
            }
            restoreSearchIfNeeded()
            reloadTablePreservingSelection()
        } else {
            doMassiveSessionPropertyUpdate(.Favorite(false))
            reloadTablePreservingSelection()
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
                var sessionKey = ""
                mainQS { sessionKey = self.displayedSessions[idx].uniqueId }
                WWDCDatabase.sharedDatabase.doBackgroundChanges { realm in
                    guard let session = realm.objectForPrimaryKey(Session.self, key: sessionKey) else { return }
                    switch property {
                    case .Progress(let progress):
                        session.progress = progress
                    case .Favorite(let favorite):
                        session.favorite = favorite
                    }
                }
            }
            mainQ { self.restoreSearchIfNeeded() }
        }
    }

    @IBAction func downloadMenuAction(sender: AnyObject) {
        if tableView.selectedRowIndexes.count < 2 {
            let session = sessions[tableView.clickedRow]
            addDownloadForSession(session)
        } else {
            tableView.selectedRowIndexes.enumerateIndexesUsingBlock { idx, _ in
                let session = self.sessions[idx]
                self.addDownloadForSession(session)
            }
        }
    }
    
    @IBAction func removeDownloadMenuAction(sender: AnyObject) {
        if tableView.selectedRowIndexes.count < 2 {
            let session = sessions[tableView.clickedRow]
            removeDownloadForURL(session.hdVideoURL)
        } else {
            tableView.selectedRowIndexes.enumerateIndexesUsingBlock { idx, _ in
                let session = self.sessions[idx]
                self.removeDownloadForURL(session.hdVideoURL)
            }
        }
        
        reloadTablePreservingSelection()
    }
    
    private func addDownloadForSession(session: Session) {
        guard session.hdVideoURL != "" else { return }
        guard !VideoStore.SharedStore().hasVideo(session.hdVideoURL) else { return }
        guard !VideoStore.SharedStore().isDownloading(session.hdVideoURL) else { return }
        
        VideoStore.SharedStore().download(session.hdVideoURL)
    }
    
    private func removeDownloadForURL(url: String) {
        
        switch VideoStore.SharedStore().removeDownload(url) {
        case .Error(let e):
            print("Couldn't remove download. Error: \(e)")
            // Also show as Alert?!
            break
        case .NotDownloaded:
            print("Couldn't remove download, because the file is not downloaded.")
            break
        case .Removed:
            break
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
    
    @IBAction func performFindPanelAction(sender: AnyObject) {
        headerController.activateSearchField(sender)
    }

    private let searchQueue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)
    func search(term: String) {
        detailsViewController?.searchTerm = term
        Preferences.SharedPreferences().searchTerm = term
        
        if term != "" {
            dispatch_async(searchQueue) {
                let realm = try! Realm()
                let transcripts = realm.objects(Transcript.self).filter("fullText CONTAINS[c] %@", term)
                let keysMatchingTranscripts = transcripts.map({ $0.session!.uniqueId })
                mainQ {
                    self.searchTermFilter = SearchFilter.Arbitrary(NSPredicate(format: "title CONTAINS[c] %@ OR uniqueId CONTAINS[c] %@ OR summary CONTAINS[c] %@ OR uniqueId IN %@", term, term, term, keysMatchingTranscripts))
                }
            }
        } else {
            self.searchTermFilter = nil
        }
    }
    
    var displayedSessions: [Session]! {
        get {
            return sessions
        }
    }
    
}

