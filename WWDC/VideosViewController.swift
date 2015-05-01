//
//  ViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class VideosViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    
    var indexOfLastSelectedRow = -1
    
    lazy var headerController: VideosHeaderViewController! = VideosHeaderViewController.loadDefaultController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupScrollView()
        
        tableView.gridColor = Theme.WWDCTheme.separatorColor
        
        loadSessions()
        
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserverForName(SessionProgressDidChangeNotification, object: nil, queue: nil) { _ in
            self.reloadTablePreservingSelection()
        }
        nc.addObserverForName(VideoStoreNotificationDownloadFinished, object: nil, queue: NSOperationQueue.mainQueue()) { _ in
            self.reloadTablePreservingSelection()
        }
        nc.addObserverForName(VideoStoreDownloadedFilesChangedNotification, object: nil, queue: NSOperationQueue.mainQueue()) { _ in
            self.reloadTablePreservingSelection()
        }
    }
    
    func setupScrollView() {
        let insetHeight = NSHeight(headerController.view.frame)
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: insetHeight, left: 0, bottom: 0, right: 0)
        
        setupViewHeader(insetHeight)
    }
    
    func setupViewHeader(insetHeight: CGFloat) {
        if let superview = scrollView.superview {
            superview.addSubview(headerController.view)
            headerController.view.frame = CGRectMake(0, NSHeight(superview.frame)-insetHeight, NSWidth(superview.frame), insetHeight)
            headerController.view.autoresizingMask = NSAutoresizingMaskOptions.ViewWidthSizable | NSAutoresizingMaskOptions.ViewMinYMargin
            headerController.performSearch = search
        }
    }

    var sessions: [Session]! {
        didSet {
            if sessions != nil {
                headerController.enable()
            }
            reloadTablePreservingSelection()
        }
    }

    // MARK: Session loading
    
    func loadSessions() {
        DataStore.SharedStore.fetchSessions() { success, sessions in
            dispatch_async(dispatch_get_main_queue()) {
                self.sessions = sessions
            }
        }
    }
    
    // MARK: TableView
    
    func reloadTablePreservingSelection() {
        tableView.reloadData()
        
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
        
        let session = displayedSessions[row]
        cell.titleField.stringValue = session.title
        cell.trackField.stringValue = session.track
        cell.platformsField.stringValue = ", ".join(session.focus)
        cell.detailsField.stringValue = "\(session.year) - Session \(session.id)"
        cell.progressView.progress = DataStore.SharedStore.fetchSessionProgress(session)
        if let url = session.hd_url {
            cell.downloadedImage.hidden = !VideoStore.SharedStore().hasVideo(url)
        }
        
        return cell
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 40.0
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
        if tableView.selectedRow >= 0 {
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
    
    var currentSearchTerm: String? {
        didSet {
            reloadTablePreservingSelection()
        }
    }
    
    func search(term: String) {
        currentSearchTerm = term
    }
    
    var displayedSessions: [Session]! {
        get {
            if let term = currentSearchTerm {
                var term = term
                if term != "" {
                    var qualifiers = term.qualifierSearchParser_parseQualifiers(["year", "focus", "track", "downloaded"])
                    indexOfLastSelectedRow = -1
                    return sessions.filter { session in

                        if let year: String = qualifiers["year"] as? String {
							let yearStr = "\(session.year)"
							let result = (yearStr as NSString).rangeOfString(year, options: .CaseInsensitiveSearch)
							if result.location + result.length == count(yearStr) {
								return true
							}
							return false
                        }
                        
                        if let focus: String = qualifiers["focus"] as? String {
                            var fixedFocus: String = focus
                            if focus.lowercaseString == "osx" || focus.lowercaseString == "os x" {
                                fixedFocus = "OS X"
                            } else if focus.lowercaseString == "ios" {
                                fixedFocus = "iOS"
                            }
                            
                            if !contains(session.focus, fixedFocus) {
                                return false
                            }
                        }
                        
                        if let track: String = qualifiers["track"] as? String {
                            if session.track.lowercaseString != track.lowercaseString {
                                return false
                            }
                        }
                        
                        if let downloaded: String = qualifiers["downloaded"] as? String {
                            if let url = session.hd_url {
                                return (VideoStore.SharedStore().hasVideo(url) == downloaded.boolValue)
                            } else {
                                return false
                            }
                        }
                        
                        if let query: String = qualifiers["_query"] as? String {
                            if query != "" {
                                if let range = session.title.rangeOfString(query, options: .CaseInsensitiveSearch | .DiacriticInsensitiveSearch, range: nil, locale: nil) {
                                    //Nothing here...
                                } else {
                                    return false
                                }
                            }
                        }
                        
                        return true
                    }
                } else {
                    return sessions
                }
            } else {
                return sessions
            }
        }
    }
    
}

