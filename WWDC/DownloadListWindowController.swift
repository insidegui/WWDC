//
//  DownloadListWindowController.swift
//  WWDC
//
//  Created by Ruslan Alikhamov on 26/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

private class DownloadListItem : NSObject {
	
	var url: String?
	var progress: Double?
	var session: Session?
	var task: NSURLSessionDownloadTask?
	
	convenience init(url: String, progress: Double, session: Session, task: NSURLSessionDownloadTask) {
		self.init()
		self.url = url
		self.progress = progress
		self.session = session
		self.task = task
	}
}

private let DownloadListCellIdentifier = "DownloadListCellIdentifier"

class DownloadListWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {
	
	@IBOutlet var tableView: NSTableView!
	
	private var items: [DownloadListItem] = []
	private var downloadStartedHndl: AnyObject?
	private var downloadFinishedHndl: AnyObject?
	private var downloadChangedHndl: AnyObject?
	private var downloadCancelledHndl: AnyObject?
	private var downloadPausedHndl: AnyObject?
	private var downloadResumedHndl: AnyObject?
	
	override func windowDidLoad() {
		super.windowDidLoad()
		self.tableView.setDelegate(self)
		self.tableView.setDataSource(self)
		self.tableView.columnAutoresizingStyle = .FirstColumnOnlyAutoresizingStyle
		let nc = NSNotificationCenter.defaultCenter()
		self.downloadStartedHndl = nc.addObserverForName(VideoStoreNotificationDownloadStarted, object: nil, queue: NSOperationQueue.mainQueue()) { note in
			let url = note.object as! String?
			if url != nil {
				let (item, idx) = self.listItemForURL(url)
				if item != nil {
					return
				}
				let tasks = self.videoStore.allTasks()
				for task in tasks {
					if let _url = task.originalRequest.URL?.absoluteString where _url == url {
						let sessions = DataStore.SharedStore.cachedSessions!
						let session = sessions.filter { $0.hd_url == url }.first
						var item = DownloadListItem(url: url!, progress: 0, session: session!, task: task)
						self.items.append(item)
						self.tableView.insertRowsAtIndexes(NSIndexSet(index: self.items.count), withAnimation: .SlideUp)
					}
				}
			}
		}
		self.downloadFinishedHndl = nc.addObserverForName(VideoStoreNotificationDownloadFinished, object: nil, queue: NSOperationQueue.mainQueue()) { note in
			if let object = note.object as? String {
				let url = object as String
				let (item, idx) = self.listItemForURL(url)
				if item != nil {
					self.items.removeObject(item!)
					self.tableView.removeRowsAtIndexes(NSIndexSet(index: idx), withAnimation: .SlideDown)
				}
			}
		}
		self.downloadChangedHndl = nc.addObserverForName(VideoStoreNotificationDownloadProgressChanged, object: nil, queue: NSOperationQueue.mainQueue()) { note in
			if let info = note.userInfo {
				if let object = note.object as? String {
					let url = object as String
					let (item, idx) = self.listItemForURL(url)
					if item != nil {
						if let expected = info["totalBytesExpectedToWrite"] as? Int,
							let written = info["totalBytesWritten"] as? Int
						{
							let progress = Double(written) / Double(expected)
							item!.progress = progress * 100
							self.tableView.reloadDataForRowIndexes(NSIndexSet(index: idx), columnIndexes: NSIndexSet(index: 0))
						}
					}
				}
			}
		}
		self.downloadCancelledHndl = nc.addObserverForName(VideoStoreNotificationDownloadCancelled, object: nil, queue: NSOperationQueue.mainQueue()) { note in
			if let object = note.object as? String {
				let url = object as String
				let (item, idx) = self.listItemForURL(url)
				if item != nil {
					self.items.removeObject(item!)
					self.tableView.removeRowsAtIndexes(NSIndexSet(index: idx), withAnimation: .SlideDown)
				}
			}
		}
		self.downloadPausedHndl = nc.addObserverForName(VideoStoreNotificationDownloadPaused, object: nil, queue: NSOperationQueue.mainQueue()) { note in
			if let object = note.object as? String {
				let url = object as String
				let (item, idx) = self.listItemForURL(url)
				if item != nil {
					self.tableView.reloadDataForRowIndexes(NSIndexSet(index: idx), columnIndexes: NSIndexSet(index: 0))
				}
			}
		}
		self.downloadResumedHndl = nc.addObserverForName(VideoStoreNotificationDownloadResumed, object: nil, queue: NSOperationQueue.mainQueue()) { note in
			if let object = note.object as? String {
				let url = object as String
				let (item, idx) = self.listItemForURL(url)
				if item != nil {
					self.tableView.reloadDataForRowIndexes(NSIndexSet(index: idx), columnIndexes: NSIndexSet(index: 0))
				}
			}
		}
	}
	
	private func listItemForURL(url: String!) -> (DownloadListItem?, Int) {
		for (idx, item) in enumerate(self.items) {
			if item.url == url {
				return (item, idx)
			}
		}
		return (nil, NSNotFound)
	}
	
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self.downloadStartedHndl!)
		NSNotificationCenter.defaultCenter().removeObserver(self.downloadFinishedHndl!)
		NSNotificationCenter.defaultCenter().removeObserver(self.downloadChangedHndl!)
		NSNotificationCenter.defaultCenter().removeObserver(self.downloadCancelledHndl!)
		NSNotificationCenter.defaultCenter().removeObserver(self.downloadPausedHndl!)
		NSNotificationCenter.defaultCenter().removeObserver(self.downloadResumedHndl!)
	}
	
	override func showWindow(sender: AnyObject?) {
		super.showWindow(sender)
		self.items.removeAll(keepCapacity: false)
		let tasks = self.videoStore.allTasks()
		let sessions = DataStore.SharedStore.cachedSessions!
		for task in tasks {
			if let url = task.originalRequest.URL?.absoluteString {
				let session = sessions.filter { $0.hd_url == url }.first
				var item = DownloadListItem(url: url, progress: 0, session: session!, task: task)
				self.items.append(item)
			}
		}
		self.tableView.reloadData()
	}
	
	var videoStore: VideoStore {
		get {
			return VideoStore.SharedStore()
		}
	}
	
	convenience init() {
		self.init(windowNibName: "DownloadListWindowController")
	}
	
	func numberOfRowsInTableView(tableView: NSTableView) -> Int {
		return self.items.count
	}
	
	func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let identifier = tableColumn?.identifier
		var cellView = tableView.makeViewWithIdentifier(identifier!, owner: self) as! DownloadListCellView
		let item = self.items[row]
		cellView.textField?.stringValue = item.session!.title
		if item.progress > 0 {
			if cellView.started == false {
				cellView.startProgress()
			}
			cellView.progressIndicator.doubleValue = item.progress!
		}
		cellView.item = item
		cellView.statusBlock = { [weak self] item, cell in
			let listItem = item as! DownloadListItem
			let task = listItem.task
			switch task!.state {
			case .Running:
				cell.statusBtn.title = NSLocalizedString("Resume", comment: "resume title in video download view")
				self?.videoStore.pauseDownload(listItem.url!)
			case .Suspended:
				cell.statusBtn.title = NSLocalizedString("Pause", comment: "pause title in video download view")
				self?.videoStore.resumeDownload(listItem.url!)
			default: break
			}
		}
		cellView.cancelBlock = { [weak self] item, cell in
			let listItem = item as! DownloadListItem
			if let url = listItem.url {
				self?.videoStore.cancelDownload(url)
			}
		};
		switch item.task!.state {
		case .Running:
			cellView.statusBtn.title = NSLocalizedString("Pause", comment: "pause title in video download view")
		case .Suspended:
			cellView.statusBtn.title = NSLocalizedString("Resume", comment: "resume title in video download view")
		default: break
		}
		return cellView
	}
	
}
