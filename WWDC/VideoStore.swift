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

class VideoStore : NSObject, NSURLSessionDownloadDelegate {

    private let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(_BackgroundSessionIdentifier)
    private var backgroundSession: NSURLSession!
    private var downloadTasks: [String : NSURLSessionDownloadTask] = [:]
    private let defaults = NSUserDefaults.standardUserDefaults()
    
    class func SharedStore() -> VideoStore
    {
        return _SharedVideoStore;
    }
    
    override init() {
        super.init()
        backgroundSession = NSURLSession(configuration: configuration, delegate: self, delegateQueue: NSOperationQueue.mainQueue())
    }
    
    func initialize() {
        backgroundSession.getTasksWithCompletionHandler { _, _, pendingTasks in
            for task in pendingTasks {
                if let key = task.originalRequest?.URL!.absoluteString {
                    self.downloadTasks[key] = task
                }
            }
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName(LocalVideoStoragePathPreferenceChangedNotification, object: nil, queue: nil) { _ in
            self.monitorDownloadsFolder()
            NSNotificationCenter.defaultCenter().postNotificationName(VideoStoreDownloadedFilesChangedNotification, object: nil)
        }
        
        monitorDownloadsFolder()
    }
    
    // MARK: Public interface
	
	func allTasks() -> [NSURLSessionDownloadTask] {
		return Array(self.downloadTasks.values)
	}
	
    func download(url: String) {
        if isDownloading(url) {
            return
        }
        
        let task = backgroundSession.downloadTaskWithURL(NSURL(string: url)!)
		if let key = task.originalRequest?.URL!.absoluteString {
			self.downloadTasks[key] = task
		}
        task.resume()
		
        NSNotificationCenter.defaultCenter().postNotificationName(VideoStoreNotificationDownloadStarted, object: url)
    }
    
    func pauseDownload(url: String) -> Bool {
        if let task = downloadTasks[url] {
			task.suspend()
			NSNotificationCenter.defaultCenter().postNotificationName(VideoStoreNotificationDownloadPaused, object: url)
			return true
        }
		print("VideoStore was asked to pause downloading URL \(url), but there's no task for that URL")
		return false
    }
	
	func resumeDownload(url: String) -> Bool {
		if let task = downloadTasks[url] {
			task.resume()
			NSNotificationCenter.defaultCenter().postNotificationName(VideoStoreNotificationDownloadResumed, object: url)
			return true
		}
		print("VideoStore was asked to resume downloading URL \(url), but there's no task for that URL")
		return false
	}
	
	func cancelDownload(url: String) -> Bool {
		if let task = downloadTasks[url] {
			task.cancel()
			self.downloadTasks.removeValueForKey(url)
			NSNotificationCenter.defaultCenter().postNotificationName(VideoStoreNotificationDownloadCancelled, object: url)
			return true
		}
		print("VideoStore was asked to cancel downloading URL \(url), but there's no task for that URL")
		return false
	}
	
    func isDownloading(url: String) -> Bool {
        let downloading = downloadTasks.keys.filter { taskURL in
            return url == taskURL
        }

        return (downloading.count > 0)
    }
    
    func localVideoPath(remoteURL: String) -> String {
        return (Preferences.SharedPreferences().localVideoStoragePath as NSString).stringByAppendingPathComponent((remoteURL as NSString).lastPathComponent)
    }
    
    func localVideoAbsoluteURLString(remoteURL: String) -> String {
        return NSURL(fileURLWithPath: localVideoPath(remoteURL)).absoluteString
    }
    
    func hasVideo(url: String) -> Bool {
        return (NSFileManager.defaultManager().fileExistsAtPath(localVideoPath(url)))
    }
    
    // MARK: URL Session
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        let originalURL = downloadTask.originalRequest!.URL!
        let originalAbsoluteURLString = originalURL.absoluteString

        let fileManager = NSFileManager.defaultManager()
        
        if (fileManager.fileExistsAtPath(Preferences.SharedPreferences().localVideoStoragePath) == false) {
            do {
                try fileManager.createDirectoryAtPath(Preferences.SharedPreferences().localVideoStoragePath, withIntermediateDirectories: false, attributes: nil)
            } catch _ {
            }
        }
        
        let localURL = NSURL(fileURLWithPath: localVideoPath(originalAbsoluteURLString))
        
        do {
            try fileManager.moveItemAtURL(location, toURL: localURL)
        } catch _ {
            print("VideoStore was unable to move \(location) to \(localURL)")
        }
        
        downloadTasks.removeValueForKey(originalAbsoluteURLString)
        
        NSNotificationCenter.defaultCenter().postNotificationName(VideoStoreNotificationDownloadFinished, object: originalAbsoluteURLString)
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let originalURL = downloadTask.originalRequest!.URL!.absoluteString

        let info = ["totalBytesWritten": Int(totalBytesWritten), "totalBytesExpectedToWrite": Int(totalBytesExpectedToWrite)]
        NSNotificationCenter.defaultCenter().postNotificationName(VideoStoreNotificationDownloadProgressChanged, object: originalURL, userInfo: info)
    }
    
    // MARK: File observation
    
    var folderMonitor: DTFolderMonitor!
    
    func monitorDownloadsFolder() {
        if folderMonitor != nil {
            folderMonitor.stopMonitoring()
            folderMonitor = nil
        }
        
        folderMonitor = DTFolderMonitor(forURL: NSURL(fileURLWithPath: Preferences.SharedPreferences().localVideoStoragePath)) {
            NSNotificationCenter.defaultCenter().postNotificationName(VideoStoreDownloadedFilesChangedNotification, object: nil)
        }
        folderMonitor.startMonitoring()
    }
    
    // MARK: Teardown
    
    deinit {
        if folderMonitor != nil {
            folderMonitor.stopMonitoring()
        }
    }
    
}
