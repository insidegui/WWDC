//
//  ViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ViewUtils
import RealmSwift

class VideosViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var scrollView: GRScrollView!
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

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateScrollInsets:", name: LiveEventBannerVisibilityChangedNotification, object: nil)
        
        setupViewHeader(insetHeight)
        setupFilterBar()
    }
    
    func updateScrollInsets(note: NSNotification?) {
        if let bannerController = LiveEventBannerViewController.DefaultController {
            scrollView.contentInsets = NSEdgeInsets(top: scrollView.contentInsets.top, left: 0, bottom: bannerController.barHeight, right: 0)
        }
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
            sessions = sessions.filter(filter.predicate)
        }
        
        if let termFilter = searchTermFilter {
            sessions = sessions.filter(termFilter.predicate)
        }
    }
    
    var filterBarController: FilterBarController?
    func setupFilterBar() {
        guard let superview = scrollView.superview else { return }
        
        filterBarController = FilterBarController(scrollView: scrollView)
        superview.addSubview(filterBarController!.view, positioned: .Below, relativeTo: headerController.view)
        filterBarController!.view.frame = CGRectMake(0, NSHeight(superview.frame)-NSHeight(headerController.view.frame), NSWidth(superview.frame), 44.0)
        filterBarController!.view.autoresizingMask = [.ViewWidthSizable, .ViewMinYMargin]
        
        filterBarController!.filtersDidChangeCallback = {
            self.searchFilters = self.filterBarController!.filters
        }
    }

    var sessions: Results<Session>! {
        didSet {
            guard sessions != nil else { return }
            
            headerController.enable()
            headerController.searchTerm = Preferences.SharedPreferences().searchTerm

            tableView.reloadData()
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
        
        WWDCDatabase.sharedDatabase.transcriptIndexingStartedCallback = {
            self.headerController.progress = WWDCDatabase.sharedDatabase.transcriptIndexingProgress
        }
        WWDCDatabase.sharedDatabase.sessionListChangedCallback = { newSessionKeys in
            print("\(newSessionKeys.count) new session(s) available")

            GRLoadingView.dismissAllAfterDelay(0.3)
            
            self.fetchLocalSessions()
            
            self.splitManager?.restoreDividerPosition()
            self.splitManager?.startSavingDividerPosition()
            self.setupAutomaticSessionRefresh()
        }
        WWDCDatabase.sharedDatabase.refresh()
        
        if Preferences.SharedPreferences().searchTerm != "" {
            search(Preferences.SharedPreferences().searchTerm)
        }
    }
    
    func fetchLocalSessions() {
        sessions = WWDCDatabase.sharedDatabase.standardSessionList
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
    
    private func addDownloadForSession(session: Session) {
        guard session.hdVideoURL != "" else { return }
        guard !VideoStore.SharedStore().hasVideo(session.hdVideoURL) else { return }
        guard !VideoStore.SharedStore().isDownloading(session.hdVideoURL) else { return }
        
        VideoStore.SharedStore().download(session.hdVideoURL)
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
                    self.searchTermFilter = SearchFilter.Arbitrary(NSPredicate(format: "title CONTAINS[c] %@ OR summary CONTAINS[c] %@ OR uniqueId IN %@", term, term, keysMatchingTranscripts))
                }
            }
        } else {
            self.searchTermFilter = nil
        }
    }
    
    var displayedSessions: Results<Session>! {
        get {
            return sessions
        }
    }
    
}

