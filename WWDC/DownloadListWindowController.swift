//
//  DownloadListWindowController.swift
//  WWDC
//
//  Created by Ruslan Alikhamov on 26/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

private class DownloadListItem : NSObject {
    
    let url: String
    let session: Session
    let task: URLSessionDownloadTask
    var totalSize: Int?
    var downloadedSize: Int = 0
    
    var progress: Double {
        if let totalSize = totalSize, totalSize > 0 {
            return Double(downloadedSize) / Double(totalSize)
        } else {
            return 0
        }
    }
    
    init(url: String, session: Session, task: URLSessionDownloadTask) {
        self.url = url
        self.session = session
        self.task = task
    }
}

private let DownloadListCellIdentifier = "DownloadListCellIdentifier"

class DownloadListWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet var tableView: NSTableView!
    
    fileprivate var items: [DownloadListItem] = []
    fileprivate var downloadStartedHndl: AnyObject?
    fileprivate var downloadFinishedHndl: AnyObject?
    fileprivate var downloadChangedHndl: AnyObject?
    fileprivate var downloadCancelledHndl: AnyObject?
    fileprivate var downloadPausedHndl: AnyObject?
    fileprivate var downloadResumedHndl: AnyObject?
    
    fileprivate var fileSizeFormatter: ByteCountFormatter!
    fileprivate var percentFormatter: NumberFormatter!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        
        fileSizeFormatter = ByteCountFormatter()
        fileSizeFormatter.zeroPadsFractionDigits = true
        fileSizeFormatter.allowsNonnumericFormatting = false
        
        percentFormatter = NumberFormatter()
        percentFormatter.numberStyle = .percent
        percentFormatter.minimumFractionDigits = 1
        
        let nc = NotificationCenter.default
        self.downloadStartedHndl = nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadStarted), object: nil, queue: OperationQueue.main) { note in
            let url = note.object as! String?
            if url != nil {
                let (item, _) = self.listItemForURL(url)
                if item != nil {
                    return
                }
                let tasks = self.videoStore.allTasks()
                for task in tasks {
                    if let _url = task.originalRequest?.url?.absoluteString, _url == url {
                        guard let session = WWDCDatabase.sharedDatabase.realm.objects(Session.self).filter("hdVideoURL = %@", _url).first else { return }
                        let item = DownloadListItem(url: url!, session: session, task: task)
                        self.items.append(item)
                        self.tableView.insertRows(at: IndexSet(integer: self.items.count), withAnimation: .slideUp)
                    }
                }
            }
        }
        self.downloadFinishedHndl = nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadFinished), object: nil, queue: OperationQueue.main) { note in
            if let object = note.object as? String {
                let url = object as String
                let (item, idx) = self.listItemForURL(url)
                if item != nil {
                    self.items.remove(item!)
                    self.tableView.removeRows(at: IndexSet(integer: idx), withAnimation: .slideDown)
                }
            }
        }
        self.downloadChangedHndl = nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadProgressChanged), object: nil, queue: OperationQueue.main) { note in
            if let info = note.userInfo {
                if let object = note.object as? String {
                    let url = object as String
                    let (item, idx) = self.listItemForURL(url)
                    if let item = item {
                        if let expected = info["totalBytesExpectedToWrite"] as? Int,
                            let written = info["totalBytesWritten"] as? Int
                        {
                            item.downloadedSize = written
                            item.totalSize = expected
                            self.tableView.reloadData(forRowIndexes: IndexSet(integer: idx), columnIndexes: IndexSet(integer: 0))
                        }
                    }
                }
            }
        }
        self.downloadPausedHndl = nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadPaused), object: nil, queue: OperationQueue.main) { note in
            if let object = note.object as? String {
                let url = object as String
                let (item, idx) = self.listItemForURL(url)
                if item != nil {
                    self.tableView.reloadData(forRowIndexes: IndexSet(integer: idx), columnIndexes: IndexSet(integer: 0))
                }
            }
        }
        self.downloadResumedHndl = nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadResumed), object: nil, queue: OperationQueue.main) { note in
            if let object = note.object as? String {
                let url = object as String
                let (item, idx) = self.listItemForURL(url)
                if item != nil {
                    self.tableView.reloadData(forRowIndexes: IndexSet(integer: idx), columnIndexes: IndexSet(integer: 0))
                }
            }
        }
        self.downloadCancelledHndl = nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadCancelled), object: nil, queue: OperationQueue.main) { note in
            self.populateDownloadItems()
        }
        
        populateDownloadItems()
    }
    
    fileprivate func listItemForURL(_ url: String!) -> (DownloadListItem?, Int) {
        for (idx, item) in self.items.enumerated() {
            if item.url == url {
                return (item, idx)
            }
        }
        return (nil, NSNotFound)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self.downloadStartedHndl!)
        NotificationCenter.default.removeObserver(self.downloadFinishedHndl!)
        NotificationCenter.default.removeObserver(self.downloadChangedHndl!)
        NotificationCenter.default.removeObserver(self.downloadCancelledHndl!)
        NotificationCenter.default.removeObserver(self.downloadPausedHndl!)
        NotificationCenter.default.removeObserver(self.downloadResumedHndl!)
    }
    
    var videoStore: VideoStore {
        get {
            return VideoStore.SharedStore()
        }
    }
    
    convenience init() {
        self.init(windowNibName: "DownloadListWindowController")
    }
    
    fileprivate func populateDownloadItems() {
        self.items.removeAll(keepingCapacity: false)
        
        videoStore.allTasks().forEach { task in
            guard let taskURL = task.originalRequest?.url?.absoluteString else { return }
            guard let session = WWDCDatabase.sharedDatabase.realm.objects(Session.self).filter("hdVideoURL = %@", taskURL).first else { return }
            
            let item = DownloadListItem(url: taskURL, session: session, task: task)
            
            self.items.append(item)
        }
        
        self.tableView.reloadData()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier
        let cellView = tableView.make(withIdentifier: identifier!, owner: self) as! DownloadListCellView
        let item = self.items[row]
        
        let title = item.session.isExtra ? "\(item.session.event) - \(item.session.title)" : "\(item.session.event) \(item.session.year) - \(item.session.title)"
        cellView.textField?.stringValue = title
        
        if item.progress > 0 {
            if cellView.started == false {
                cellView.startProgress()
            }
            cellView.progressIndicator.doubleValue = item.progress * 100
        }
        cellView.item = item
        
        cellView.cancelBlock = { [weak self] item, cell in
            let listItem = item as! DownloadListItem
            let task = listItem.task
            switch task.state {
            case .running:
                self?.videoStore.pauseDownload(listItem.url)
            case .suspended:
                self?.videoStore.resumeDownload(listItem.url)
            default: break
            }
        };
        
        var statusText: String?
        
        switch item.task.state {
        case .running:
            cellView.progressIndicator.isIndeterminate = false
            cellView.cancelButton.image = NSImage(named: "NSStopProgressFreestandingTemplate")
            cellView.cancelButton.toolTip = NSLocalizedString("Pause", comment: "pause button tooltip in downloads window")
            
            statusText = NSLocalizedString("Downloading", comment: "video downloading status in downloads window")
        case .suspended:
            cellView.progressIndicator.isIndeterminate = true
            cellView.cancelButton.image = NSImage(named: "NSRefreshFreestandingTemplate")
            cellView.cancelButton.toolTip = NSLocalizedString("Resume", comment: "resume button tooltip in downloads window")
            
            statusText = NSLocalizedString("Paused", comment: "video paused status in downloads window")
        default: break
        }
        
        if let statusText = statusText {
            if let totalSize = item.totalSize {
                let downloaded = fileSizeFormatter.string(fromByteCount: Int64(item.downloadedSize))
                let total = fileSizeFormatter.string(fromByteCount: Int64(totalSize))
                let progress = percentFormatter.string(from: NSNumber(item.progress)) ?? "? %"
                
                cellView.statusLabel.stringValue = "\(statusText) – \(downloaded) / \(total) (\(progress))"
            } else {
                cellView.statusLabel.stringValue = statusText
            }
        }
        
        return cellView
    }
    
    func delete(_ sender: AnyObject?) {
        guard tableView.selectedRowIndexes.count > 0 else { return }
        
        var downloadsToCancel = [String]()
        
        (tableView.selectedRowIndexes as NSIndexSet).enumerate { index, _ in
            downloadsToCancel.append(self.items[index].url)
        }
        
        downloadsToCancel.forEach { self.videoStore.cancelDownload($0) }
    }
    
    // MARK: Menu Validation
    
    fileprivate enum MenuItemTags: Int {
        case delete = 1077
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let item = MenuItemTags(rawValue: menuItem.tag) else {
            return super.validateMenuItem(menuItem)
        }
        
        switch item {
        case .delete:
            return tableView.selectedRowIndexes.count > 0
        }
    }
    
}
