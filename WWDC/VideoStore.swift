//
//  VideoDownloader.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

public let VideoStoreStartedDownloadNotification = "VideoStoreStartedDownloadNotification"
public let VideoStoreFinishedDownloadNotification = "VideoStoreFinishedDownloadNotification"
public let VideoStoreDownloadProgressedNotification = "VideoStoreDownloadProgressedNotification"

private let _SharedVideoStore = VideoStore()
private let _BackgroundSessionIdentifier = "WWDC Video Downloader"

class VideoStore : NSObject, NSURLSessionDownloadDelegate {

    private let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(_BackgroundSessionIdentifier)
    private var backgroundSession: NSURLSession!
    private var downloadTasks: [String : NSURLSessionDownloadTask] = [:]
    private let defaults = NSUserDefaults.standardUserDefaults()
    
    let localVideoStoragePath = NSString.pathWithComponents([NSHomeDirectory(), "Library", "Application Support", "WWDC"])
    
    class func SharedStore() -> VideoStore
    {
        return _SharedVideoStore;
    }
    
    func initialize() {
        backgroundSession = NSURLSession(configuration: configuration, delegate: self, delegateQueue: NSOperationQueue.mainQueue())
        backgroundSession.getTasksWithCompletionHandler { _, _, pendingTasks in
            if let tasks = pendingTasks as? [NSURLSessionDownloadTask] {
                for task in tasks {
                    if let key = task.originalRequest.URL!.absoluteString {
                        self.downloadTasks[key] = task
                    }
                }
            }
        }
    }
    
    // MARK: Public interface
    
    func download(url: String) {
        if isDownloading(url) {
            return
        }
        
        let task = backgroundSession.downloadTaskWithURL(NSURL(string: url)!)
        task.resume()
        
        NSNotificationCenter.defaultCenter().postNotificationName(VideoStoreStartedDownloadNotification, object: url)
    }
    
    func pauseDownload(url: String) {
        if let task = downloadTasks[url] {
            println("VideoStore pauseDownload is not implemented yet")
        } else {
            println("VideoStore was asked to pause downloading URL \(url), but there's no task for that URL")
        }
    }
    
    func isDownloading(url: String) -> Bool {
        let downloading = downloadTasks.keys.filter { taskURL in
            return url == taskURL
        }
        
        return (downloading.array.count > 0)
    }
    
    func localVideoPath(remoteURL: String) -> String {
        return localVideoStoragePath.stringByAppendingPathComponent(remoteURL.lastPathComponent)
    }
    
    func localVideoAbsoluteURLString(remoteURL: String) -> String {
        return NSURL(fileURLWithPath: localVideoPath(remoteURL))!.absoluteString!
    }
    
    func hasVideo(url: String) -> Bool {
        return (NSFileManager.defaultManager().fileExistsAtPath(localVideoPath(url)))
    }
    
    // MARK: URL Session
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        let originalURL = downloadTask.originalRequest.URL!
        let originalAbsoluteURLString = originalURL.absoluteString!

        let fileManager = NSFileManager.defaultManager()
        
        if (fileManager.fileExistsAtPath(localVideoStoragePath) == false) {
            fileManager.createDirectoryAtPath(localVideoStoragePath, withIntermediateDirectories: false, attributes: nil, error: nil)
        }
        
        let localURL = NSURL(fileURLWithPath: localVideoPath(originalAbsoluteURLString))!
        
        if fileManager.moveItemAtURL(location, toURL: localURL, error: nil) == false {
            println("VideoStore was unable to move \(location) to \(localURL)")
        }
        
        downloadTasks.removeValueForKey(originalAbsoluteURLString)
        
        NSNotificationCenter.defaultCenter().postNotificationName(VideoStoreFinishedDownloadNotification, object: originalAbsoluteURLString)
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let originalURL = downloadTask.originalRequest.URL!.absoluteString!

        let info = ["totalBytesWritten": Int(totalBytesWritten), "totalBytesExpectedToWrite": Int(totalBytesExpectedToWrite)]
        NSNotificationCenter.defaultCenter().postNotificationName(VideoStoreDownloadProgressedNotification, object: originalURL, userInfo: info)
    }
    
}
