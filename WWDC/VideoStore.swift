//
//  VideoDownloader.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa


public let VideoStoreDownloadedFilesChangedNotification = "VideoStoreDownloadedFilesChangedNotification"
public let VideoStoreNotificationDownloadStarted = "VideoStoreNotificationDownloadStarted"
public let VideoStoreNotificationDownloadCancelled = "VideoStoreNotificationDownloadCancelled"
public let VideoStoreNotificationDownloadPaused = "VideoStoreNotificationDownloadPaused"
public let VideoStoreNotificationDownloadResumed = "VideoStoreNotificationDownloadResumed"
public let VideoStoreNotificationDownloadFinished = "VideoStoreNotificationDownloadFinished"
public let VideoStoreNotificationDownloadProgressChanged = "VideoStoreNotificationDownloadProgressChanged"

private let _SharedVideoStore = VideoStore()
private let _BackgroundSessionIdentifier = "WWDC Video Downloader"

class VideoStore : NSObject, URLSessionDownloadDelegate {

    fileprivate let configuration = URLSessionConfiguration.background(withIdentifier: _BackgroundSessionIdentifier)
    fileprivate var backgroundSession: Foundation.URLSession!
    fileprivate var downloadTasks: [String : URLSessionDownloadTask] = [:]
    fileprivate let defaults = UserDefaults.standard
    
    class func SharedStore() -> VideoStore
    {
        return _SharedVideoStore;
    }
    
    override init() {
        super.init()
        backgroundSession = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    func initialize() {
        backgroundSession.getTasksWithCompletionHandler { _, _, pendingTasks in
            for task in pendingTasks {
                if let key = task.originalRequest?.url!.absoluteString {
                    self.downloadTasks[key] = task
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: LocalVideoStoragePathPreferenceChangedNotification), object: nil, queue: nil) { _ in
            self.monitorDownloadsFolder()
            NotificationCenter.default.post(name: Notification.Name(rawValue: VideoStoreDownloadedFilesChangedNotification), object: nil)
        }
        
        monitorDownloadsFolder()
    }
    
    // MARK: Public interface
	
	func allTasks() -> [URLSessionDownloadTask] {
		return Array(self.downloadTasks.values)
	}
	
    func download(_ url: String) {
        if isDownloading(url) || hasVideo(url) {
            return
        }
        
        let task = backgroundSession.downloadTask(with: URL(string: url)!)
		if let key = task.originalRequest?.url!.absoluteString {
			self.downloadTasks[key] = task
		}
        task.resume()
		
        NotificationCenter.default.post(name: Notification.Name(rawValue: VideoStoreNotificationDownloadStarted), object: url)
    }
    
    func pauseDownload(_ url: String) -> Bool {
        if let task = downloadTasks[url] {
			task.suspend()
			NotificationCenter.default.post(name: Notification.Name(rawValue: VideoStoreNotificationDownloadPaused), object: url)
			return true
        }
		print("VideoStore was asked to pause downloading URL \(url), but there's no task for that URL")
		return false
    }
	
	func resumeDownload(_ url: String) -> Bool {
		if let task = downloadTasks[url] {
			task.resume()
			NotificationCenter.default.post(name: Notification.Name(rawValue: VideoStoreNotificationDownloadResumed), object: url)
			return true
		}
		print("VideoStore was asked to resume downloading URL \(url), but there's no task for that URL")
		return false
	}
	
	func cancelDownload(_ url: String) -> Bool {
		if let task = downloadTasks[url] {
			task.cancel()
			self.downloadTasks.removeValue(forKey: url)
			NotificationCenter.default.post(name: Notification.Name(rawValue: VideoStoreNotificationDownloadCancelled), object: url)
			return true
		}
		print("VideoStore was asked to cancel downloading URL \(url), but there's no task for that URL")
		return false
	}
	
    func isDownloading(_ url: String) -> Bool {
        let downloading = downloadTasks.keys.filter { taskURL in
            return url == taskURL
        }

        return (downloading.count > 0)
    }
    
    func localVideoPath(_ remoteURL: String) -> String {
        return (Preferences.SharedPreferences().localVideoStoragePath as NSString).appendingPathComponent((remoteURL as NSString).lastPathComponent)
    }
    
    func localVideoAbsoluteURLString(_ remoteURL: String) -> String {
        return URL(fileURLWithPath: localVideoPath(remoteURL)).absoluteString
    }
    
    func hasVideo(_ url: String) -> Bool {
        return (FileManager.default.fileExists(atPath: localVideoPath(url)))
    }
    
    enum RemoveDownloadResponse {
        case notDownloaded, removed, error(_:Error)
    }
    
    func removeDownload(_ url: String) -> RemoveDownloadResponse {
        if isDownloading(url) {
            cancelDownload(url)
            return .removed
        }
        
        if hasVideo(url) {
            let path = localVideoPath(url)
            let absolute = localVideoAbsoluteURLString(url)
            do {
                try FileManager.default.removeItem(atPath: path)
                WWDCDatabase.sharedDatabase.updateDownloadedStatusForSessionWithURL(absolute, downloaded: false)
                return .removed
            } catch let e {
                return .error(e)
            }
        } else {
            return .notDownloaded
        }
    }
    
    // MARK: URL Session
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let originalURL = downloadTask.originalRequest!.url!
        let originalAbsoluteURLString = originalURL.absoluteString

        let fileManager = FileManager.default
        
        if (fileManager.fileExists(atPath: Preferences.SharedPreferences().localVideoStoragePath) == false) {
            do {
                try fileManager.createDirectory(atPath: Preferences.SharedPreferences().localVideoStoragePath, withIntermediateDirectories: false, attributes: nil)
            } catch _ {
            }
        }
        
        let localURL = URL(fileURLWithPath: localVideoPath(originalAbsoluteURLString))
        
        do {
            try fileManager.moveItem(at: location, to: localURL)
            WWDCDatabase.sharedDatabase.updateDownloadedStatusForSessionWithURL(originalAbsoluteURLString, downloaded: true)
        } catch _ {
            print("VideoStore was unable to move \(location) to \(localURL)")
        }
        
        downloadTasks.removeValue(forKey: originalAbsoluteURLString)
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: VideoStoreNotificationDownloadFinished), object: originalAbsoluteURLString)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let originalURL = downloadTask.originalRequest!.url!.absoluteString

        let info = ["totalBytesWritten": Int(totalBytesWritten), "totalBytesExpectedToWrite": Int(totalBytesExpectedToWrite)]
        NotificationCenter.default.post(name: Notification.Name(rawValue: VideoStoreNotificationDownloadProgressChanged), object: originalURL, userInfo: info)
    }
    
    // MARK: File observation
    
    fileprivate var folderMonitor: DTFolderMonitor!
    fileprivate var existingVideoFiles = [String]()
    
    func monitorDownloadsFolder() {
        if folderMonitor != nil {
            folderMonitor.stopMonitoring()
            folderMonitor = nil
        }
        
        let videosPath = Preferences.SharedPreferences().localVideoStoragePath
        enumerateVideoFiles(videosPath)
        
        folderMonitor = DTFolderMonitor(for: URL(fileURLWithPath: videosPath)) {
            self.enumerateVideoFiles(videosPath)
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: VideoStoreDownloadedFilesChangedNotification), object: nil)
        }
        folderMonitor.startMonitoring()
    }
    
    /// Updates the downloaded status for the sessions on the database based on the existence of the downloaded video file
    fileprivate func enumerateVideoFiles(_ path: String) {
        guard let enumerator = FileManager.default.enumerator(atPath: path) else { return }
        guard let files = enumerator.allObjects as? [String] else { return }
        
        // existing/added files
        for file in files {
            WWDCDatabase.sharedDatabase.updateDownloadedStatusForSessionWithLocalFileName(file, downloaded: true)
        }
        
        if existingVideoFiles.count == 0 {
            existingVideoFiles = files
            return
        }
        
        // removed files
        let removedFiles = existingVideoFiles.filter { !files.contains($0) }
        for file in removedFiles {
            WWDCDatabase.sharedDatabase.updateDownloadedStatusForSessionWithLocalFileName(file, downloaded: false)
        }
    }
    
    // MARK: Teardown
    
    deinit {
        if folderMonitor != nil {
            folderMonitor.stopMonitoring()
        }
    }
    
}
