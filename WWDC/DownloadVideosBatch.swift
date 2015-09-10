//
//  DownloadVideosBatch.swift
//  WWDC
//
//  Created by Andreas Neusüß on 11.06.15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
/*private let _SharedVideoStore = VideoStore()
private let _BackgroundSessionIdentifier = "WWDC Video Downloader"

class VideoStore : NSObject, NSURLSessionDownloadDelegate {

private let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(_BackgroundSessionIdentifier)
private var backgroundSession: NSURLSession!
private var downloadTasks: [String : NSURLSessionDownloadTask] = [:]
private let defaults = NSUserDefaults.standardUserDefaults()

class func SharedStore() -> VideoStore
{
return _SharedVideoStore;
}*/
private let _sharedDownloader = DownloadVideosBatch()

class DownloadVideosBatch: NSObject {
    var sessions = [Session]()
    var currentlyDownloadedSession : String = ""
    
    private var downloadStartedHndl: AnyObject?
    private var downloadFinishedHndl: AnyObject?
    private var downloadChangedHndl: AnyObject?
    private var downloadCancelledHndl: AnyObject?
    private var downloadPausedHndl: AnyObject?
    private var downloadResumedHndl: AnyObject?
    
    class func SharedDownloader() -> DownloadVideosBatch {
        return _sharedDownloader
    }
    
    override init() {
        super.init()
        addNotifications()
    }

    
    func startDownloading() {
        if self.sessions.count == 0 {
            print("ALL VIDEOS DOWNLOADED")
            currentlyDownloadedSession = ""
            return
        }
        if let firstSession = sessions.first, let url = firstSession.hd_url {
            self.currentlyDownloadedSession = firstSession.title
            
            VideoStore.SharedStore().download(url)
        }
        
    }
    
    func addNotifications() {
        
                let nc = NSNotificationCenter.defaultCenter()
        
                self.downloadStartedHndl = nc.addObserverForName(VideoStoreNotificationDownloadStarted, object: nil, queue: NSOperationQueue.mainQueue()) { note in
                    let url = note.object as! String?
                    if url != nil {
                        print("Start downloading session '\(self.currentlyDownloadedSession)'")
                    }
                }
                self.downloadFinishedHndl = nc.addObserverForName(VideoStoreNotificationDownloadFinished, object: nil, queue: NSOperationQueue.mainQueue()) { note in
                    if let _ = note.object as? String {
                        print("Finished downloading session '\(self.currentlyDownloadedSession)'")
                        self.sessions.removeAtIndex(0)
                        _sharedDownloader.startDownloading()
                    }
                }
                self.downloadChangedHndl = nc.addObserverForName(VideoStoreNotificationDownloadProgressChanged, object: nil, queue: NSOperationQueue.mainQueue()) { note in
                    if let info = note.userInfo {
                        if let _ = note.object as? String {
                            if let expected = info["totalBytesExpectedToWrite"] as? Int,
                                let written = info["totalBytesWritten"] as? Int
                            {
                                let progress = Double(written) / Double(expected)
                                
                                print("Downloading \(self.currentlyDownloadedSession): \(progress*100.0)%")
                            }
                        }
                    }
                }
                self.downloadCancelledHndl = nc.addObserverForName(VideoStoreNotificationDownloadCancelled, object: nil, queue: NSOperationQueue.mainQueue()) { note in
                    if let object = note.object as? String {
                        _ = object as String
                        print("Download of session \(self.currentlyDownloadedSession) was cancelled.")
                    }
                }
                self.downloadPausedHndl = nc.addObserverForName(VideoStoreNotificationDownloadPaused, object: nil, queue: NSOperationQueue.mainQueue()) { note in
                    if let object = note.object as? String {
                        _ = object as String
                        print("Download of session \(self.currentlyDownloadedSession) was paused.")
                        
                    }
                }
                self.downloadResumedHndl = nc.addObserverForName(VideoStoreNotificationDownloadResumed, object: nil, queue: NSOperationQueue.mainQueue()) { note in
                    if let object = note.object as? String {
                        _ = object as String
                        print("Download of session \(self.currentlyDownloadedSession) was resumed.")
                    }
                }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self.downloadStartedHndl!)
        NSNotificationCenter.defaultCenter().removeObserver(self.downloadFinishedHndl!)
        NSNotificationCenter.defaultCenter().removeObserver(self.downloadChangedHndl!)
        NSNotificationCenter.defaultCenter().removeObserver(self.downloadCancelledHndl!)
        NSNotificationCenter.defaultCenter().removeObserver(self.downloadPausedHndl!)
        NSNotificationCenter.defaultCenter().removeObserver(self.downloadResumedHndl!)
    }
}
