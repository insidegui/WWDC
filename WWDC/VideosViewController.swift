//
//  ViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ASCIIwwdc

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
		nc.addObserverForName(VideoStoreFinishedDownloadNotification, object: nil, queue: NSOperationQueue.mainQueue()) { _ in
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
				self._displayedSessions = sessions
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
			if let term = currentSearchTerm {
				var term = term
				if term != "" {
					var qualifiers = term.qualifierSearchParser_parseQualifiers(["year", "focus", "track", "downloaded", "transcript"])
					indexOfLastSelectedRow = -1
					if let transcriptQuery: String = qualifiers["transcript"] as? String {
						ASCIIWWDCClient.sharedClient().fetchTranscriptsForQuery(transcriptQuery) { [weak self] (success, result) -> Void in
							// reload table
							if success {
								if let res = result {
									let resultArr = res as! [WWDCSessionTranscript]
									let sessIDArr = resultArr.map({ $0.sessionID })
									if let sessions = self?.sessions {
										var previouslyFiltered: [Int] = []
										var filtered: [Session]! = sessions.filter { session in
											if let obj = find(sessIDArr, session.id) {
												if let dup = find(previouslyFiltered, session.id) {
													return false
												}
												previouslyFiltered.append(session.id)
												return true
											}
											return false
										}
										let dispIDArr = self?._displayedSessions.map({ $0.id }) as [Int]!
										filtered = filtered.filter { session in
											if let obj = find(dispIDArr, session.id) {
												return true
											}
											return false
										}
										self?._displayedSessions = filtered
										dispatch_async(dispatch_get_main_queue()) {
											self?.reloadTablePreservingSelection()
										}
									}
								}
							}
						}
					}
					_displayedSessions = sessions.filter { session in
						if let year: String = qualifiers["year"] as? String {
							if session.year != year.toInt() {
								return false
							}
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
					reloadTablePreservingSelection()
				} else {
					self._displayedSessions.removeAll(keepCapacity: false)
					reloadTablePreservingSelection()
				}
			}
		}
	}
	
	func search(term: String) {
		currentSearchTerm = term
	}
	
	private var _displayedSessions: [Session] = []
	var displayedSessions: [Session]! {
		get {
			if _displayedSessions.count > 0 {
				return _displayedSessions
			}
			return sessions
		}
	}
    
}

