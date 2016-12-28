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
            if let splitViewController = parent as? NSSplitViewController {
                splitManager = SplitManager(splitView: splitViewController.splitView)
            }
        }
        
        loadedStoryboard = true
    }
    
    override func awakeAfter(using aDecoder: NSCoder) -> Any? {
        return super.awakeAfter(using: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupScrollView()

        tableView.gridColor = Theme.WWDCTheme.separatorColor
        loadSessions(refresh: false, quiet: false)
        
        let nc = NotificationCenter.default

        nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadStarted), object: nil, queue: OperationQueue.main) { _ in
            self.reloadTablePreservingSelection()
        }
        nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadFinished), object: nil, queue: OperationQueue.main) { _ in
            self.reloadTablePreservingSelection()
        }
        nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreDownloadedFilesChangedNotification), object: nil, queue: OperationQueue.main) { _ in
            self.reloadTablePreservingSelection()
        }
        nc.addObserver(forName: NSNotification.Name(rawValue: AutomaticRefreshPreferenceChangedNotification), object: nil, queue: OperationQueue.main) { _ in
            self.setupAutomaticSessionRefresh()
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if finishedInitialSetup {
            return
        }
        
        _ = GRLoadingView.show(in: self.view.window!)
        
        finishedInitialSetup = true
    }
    
    func setupScrollView() {
        let insetHeight = NSHeight(headerController.view.frame)
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = EdgeInsets(top: insetHeight, left: 0, bottom: 0, right: 0)

       setupViewHeader(insetHeight)
        setupFilterBar()
    }
    
    func setupViewHeader(_ insetHeight: CGFloat) {
        guard let superview = scrollView.superview else { return }

        superview.addSubview(headerController.view)
        headerController.view.frame = CGRect(x: 0, y: NSHeight(superview.frame)-insetHeight, width: NSWidth(superview.frame), height: insetHeight)
        headerController.view.autoresizingMask = [NSAutoresizingMaskOptions.viewWidthSizable, NSAutoresizingMaskOptions.viewMinYMargin]
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
    
    fileprivate func applySearchFilters() {
        fetchLocalSessions()
        
        for filter in searchFilters {
            sessions = (sessions as NSArray).filtered(using: filter.predicate) as! [Session]
        }
        
        if let termFilter = searchTermFilter {
            sessions = (sessions as NSArray).filtered(using: termFilter.predicate) as! [Session]
        }
    }
    
    var filterBarController: FilterBarController?
    func setupFilterBar() {
        guard let superview = scrollView.superview else { return }
        
        filterBarController = FilterBarController(scrollView: scrollView)
        superview.addSubview(filterBarController!.view, positioned: .below, relativeTo: headerController.view)
        filterBarController!.view.frame = CGRect(x: 0, y: NSHeight(superview.frame)-NSHeight(headerController.view.frame), width: NSWidth(superview.frame), height: 44.0)
        filterBarController!.view.autoresizingMask = [.viewWidthSizable, .viewMinYMargin]
        
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
    
    fileprivate enum TableViewMenuItemTags: Int {
        case watched = 1000
        case unwatched = 1001
        case favorite = 1002
        case removeFavorite = 1003
        case download = 1004
        case removeDownload = 1005
        case copyURL = 1006
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let item = TableViewMenuItemTags(rawValue: menuItem.tag) else { return false }
        
        // this validation only applies to the row where the right-click happened, not when many rows are selected
        guard tableView.selectedRowIndexes.count <= 1 else { return true }
        
        let tableViewRow = tableView.clickedRow
        let session = sessions[tableViewRow]
        
        guard !session.isInvalidated else { return false }
        
        switch item {
        case .watched:
            return session.progress != 100
            
        case .unwatched:
            return session.progress == 100
            
        case .favorite:
            return session.favorite ? false : true
            
        case .removeFavorite:
            return session.favorite
            
        case .download:
            return self.validateDownloadMenuItemsFrom(session).shouldEnableDownload
            
        case .removeDownload:
            return self.validateDownloadMenuItemsFrom(session).shouldEnableRemoveDownload
            
        case .copyURL:
            return true
        }
    }
    
    func validateDownloadMenuItemsFrom(_ session: Session) -> (shouldEnableDownload: Bool, shouldEnableRemoveDownload:Bool) {
        guard !session.isInvalidated else { return (false, false) }
        
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
        
    func loadSessions(refresh: Bool, quiet: Bool) {
        if !quiet {
            if let window = view.window {
                GRLoadingView.show(in: window)
            }
        }
        
        fetchLocalSessions()
        
        WWDCDatabase.sharedDatabase.transcriptIndexingStartedCallback = { [weak self] in
            self?.headerController.progress = WWDCDatabase.sharedDatabase.transcriptIndexingProgress
        }
        WWDCDatabase.sharedDatabase.sessionListChangedCallback = { [weak self] newSessionKeys in
            print("\(newSessionKeys.count) new session(s) available")

            GRLoadingView.dismissAll(afterDelay: 0.3)
            
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
        sessions = WWDCDatabase.sharedDatabase.standardSessionList.sorted { session1, session2 in
            guard let schedule1 = session1.schedule, let schedule2 = session2.schedule else { return false }
            
            return schedule1.startsAt < schedule2.startsAt
        }
        filterBarController?.updateMenus()
        if sessions.count > 0 {
            GRLoadingView.dismissAll(afterDelay: 0.3)
        }
    }
    
    @IBAction func refresh(_ sender: AnyObject?) {
        loadSessions(refresh: true, quiet: false)
    }
    
    var sessionListRefreshTimer: Timer?
    
    func setupAutomaticSessionRefresh() {
        if Preferences.SharedPreferences().automaticRefreshEnabled {
            if sessionListRefreshTimer == nil {
                sessionListRefreshTimer = Timer.scheduledTimer(timeInterval: Preferences.SharedPreferences().automaticRefreshInterval, target: self, selector: #selector(VideosViewController.sessionListRefreshFromTimer), userInfo: nil, repeats: true)
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
    
    fileprivate var selectionIndexesBeforeRefresh: IndexSet?
    
    func reloadTablePreservingSelection() {
        selectionIndexesBeforeRefresh = tableView.selectedRowIndexes
        
        tableView.reloadData()
        
        if let indexes = selectionIndexesBeforeRefresh {
            tableView.selectRowIndexes(indexes, byExtendingSelection: false)
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if let count = displayedSessions?.count {
            return count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
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
    
    fileprivate func cellForScheduledSession(_ session: Session) -> NSView? {
        let cell = tableView.make(withIdentifier: "scheduledSession", owner: tableView) as! ScheduledSessionTableCellView
        
        cell.session = session
        
        return cell
    }
    
    fileprivate func cellForRegularSession(_ session: Session) -> NSView? {
        let cell = tableView.make(withIdentifier: "video", owner: tableView) as! VideoTableCellView
        
        cell.session = session
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 40.0
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return tableView.make(withIdentifier: "row", owner: tableView) as? NSTableRowView
    }
    
    // MARK: Table Menu

    @IBAction func markAsWatchedMenuAction(_ sender: NSMenuItem) {
        // if there is only one row selected, change the status of the clicked row instead of using the selection
        if tableView.selectedRowIndexes.count < 2 {
            let session = displayedSessions[tableView.clickedRow]
            WWDCDatabase.sharedDatabase.doChanges {
                session.progress = 100
            }
        } else {
            doMassiveSessionPropertyUpdate(.progress(100))
        }
    }
    
    @IBAction func markAsUnwatchedMenuAction(_ sender: NSMenuItem) {
        // if there is only one row selected, change the status of the clicked row instead of using the selection
        if tableView.selectedRowIndexes.count < 2 {
            let session = displayedSessions[tableView.clickedRow]
            WWDCDatabase.sharedDatabase.doChanges {
                session.progress = 0
            }
        } else {
            doMassiveSessionPropertyUpdate(.progress(0))
        }
    }
    
    @IBAction func addToFavoritesMenuAction(_ sender: NSMenuItem) {
        // if there is only one row selected, change the status of the clicked row instead of using the selection
        if tableView.selectedRowIndexes.count < 2 {
            let session = displayedSessions[tableView.clickedRow]
            WWDCDatabase.sharedDatabase.doChanges {
                session.favorite = true
            }
        } else {
            doMassiveSessionPropertyUpdate(.favorite(true))
        }
    }
    
    @IBAction func removeFromFavoritesMenuAction(_ sender: NSMenuItem) {
        // if there is only one row selected, change the status of the clicked row instead of using the selection
        if tableView.selectedRowIndexes.count < 2 {
            let session = displayedSessions[tableView.clickedRow]
            WWDCDatabase.sharedDatabase.doChanges {
                session.favorite = false
            }
            restoreSearchIfNeeded()
            reloadTablePreservingSelection()
        } else {
            doMassiveSessionPropertyUpdate(.favorite(false))
            reloadTablePreservingSelection()
        }
    }
    
    fileprivate let userInitiatedQ = DispatchQueue.global(qos: .userInitiated)
    fileprivate enum MassiveUpdateProperty {
        case progress(Double)
        case favorite(Bool)
    }
    // changes the property of all selected sessions on a background queue
    fileprivate func doMassiveSessionPropertyUpdate(_ property: MassiveUpdateProperty) {
        userInitiatedQ.async {
            (self.tableView.selectedRowIndexes as NSIndexSet).enumerate({ idx, _ in
                var sessionKey = ""
                mainQS { sessionKey = self.displayedSessions[idx].uniqueId }
                WWDCDatabase.sharedDatabase.doBackgroundChanges { realm in
                    guard let session = realm.object(ofType: Session.self, forPrimaryKey: sessionKey as AnyObject) else { return }
                    switch property {
                    case .progress(let progress):
                        session.progress = progress
                    case .favorite(let favorite):
                        session.favorite = favorite
                    }
                }
            })
            mainQ { self.restoreSearchIfNeeded() }
        }
    }

    @IBAction func downloadMenuAction(_ sender: AnyObject) {
        if tableView.selectedRowIndexes.count < 2 {
            let session = sessions[tableView.clickedRow]
            addDownloadForSession(session)
        } else {
            (tableView.selectedRowIndexes as NSIndexSet).enumerate({ idx, _ in
                let session = self.sessions[idx]
                self.addDownloadForSession(session)
            })
        }
    }
    
    @IBAction func removeDownloadMenuAction(_ sender: AnyObject) {
        if tableView.selectedRowIndexes.count < 2 {
            let session = sessions[tableView.clickedRow]
            removeDownloadForURL(session.hdVideoURL)
        } else {
            (tableView.selectedRowIndexes as NSIndexSet).enumerate({ idx, _ in
                let session = self.sessions[idx]
                self.removeDownloadForURL(session.hdVideoURL)
            })
        }
        
        reloadTablePreservingSelection()
    }
    
    fileprivate func addDownloadForSession(_ session: Session) {
        guard session.hdVideoURL != "" else { return }
        guard !VideoStore.SharedStore().hasVideo(session.hdVideoURL) else { return }
        guard !VideoStore.SharedStore().isDownloading(session.hdVideoURL) else { return }
        
        VideoStore.SharedStore().download(session.hdVideoURL)
    }
    
    fileprivate func removeDownloadForURL(_ url: String) {
        
        switch VideoStore.SharedStore().removeDownload(url) {
        case .error(let e):
            print("Couldn't remove download. Error: \(e)")
            // Also show as Alert?!
            break
        case .notDownloaded:
            print("Couldn't remove download, because the file is not downloaded.")
            break
        case .removed:
            break
        }
    }
    
    @IBAction func copyURL(_ sender: NSMenuItem) {
        var stringToCopy:String?
        
        if tableView.selectedRowIndexes.count < 2 && tableView.clickedRow >= 0 {
            let session = displayedSessions[tableView.clickedRow]
            stringToCopy = session.shareURL
        } else {
            stringToCopy = ""
            for idx in tableView.selectedRowIndexes {
                let session = self.displayedSessions[idx]
                stringToCopy? += session.shareURL
                if tableView.selectedRowIndexes.last != idx {
                    stringToCopy? += "\n"
                }
            }
        }
        
        if let string = stringToCopy {
            let pb = NSPasteboard.general()
            pb.clearContents()
            pb.writeObjects([string as NSPasteboardWriting])
        }
    }
    
    @IBAction func copy(_ sender: NSMenuItem) {
        copyURL(sender)
    }
    
    // MARK: Navigation

    var detailsViewController: VideoDetailsViewController? {
        get {
            if let splitViewController = parent as? NSSplitViewController {
                return splitViewController.childViewControllers[1] as? VideoDetailsViewController
            } else {
                return nil
            }
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
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
    
    @IBAction func performFindPanelAction(_ sender: AnyObject) {
        headerController.activateSearchField(sender)
    }

    fileprivate let searchQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive)
    func search(_ term: String) {
        detailsViewController?.searchTerm = term
        Preferences.SharedPreferences().searchTerm = term
        
        if term != "" {
            searchQueue.async {
                let realm = try! Realm()
                let transcripts = realm.objects(Transcript.self).filter("fullText CONTAINS[c] %@", term)
                let keysMatchingTranscripts = Array(transcripts.map({ $0.session!.uniqueId }))
                mainQ {
                    self.searchTermFilter = SearchFilter.arbitrary(NSPredicate(format: "title CONTAINS[c] %@ OR uniqueId CONTAINS[c] %@ OR summary CONTAINS[c] %@ OR uniqueId IN %@", term, term, term, keysMatchingTranscripts))
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

