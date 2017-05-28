//
//  DownloadManager.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import ConfCore
import RealmSwift

extension Notification.Name {
    
    static let DownloadManagerFileAddedNotification = Notification.Name("DownloadManagerFileAddedNotification")
    static let DownloadManagerFileDeletedNotification = Notification.Name("DownloadManagerFileDeletedNotification")
    static let DownloadManagerDownloadStarted = Notification.Name("DownloadManagerDownloadStarted")
    static let DownloadManagerDownloadCancelled = Notification.Name("DownloadManagerDownloadCancelled")
    static let DownloadManagerDownloadPaused = Notification.Name("DownloadManagerDownloadPaused")
    static let DownloadManagerDownloadResumed = Notification.Name("DownloadManagerDownloadResumed")
    static let DownloadManagerDownloadFailed = Notification.Name("DownloadManagerDownloadFailed")
    static let DownloadManagerDownloadFinished = Notification.Name("DownloadManagerDownloadFinished")
    static let DownloadManagerDownloadProgressChanged = Notification.Name("DownloadManagerDownloadProgressChanged")
    
}

enum DownloadStatus {
    case none
    case downloading(Double)
    case paused
    case cancelled
    case finished
    case failed(Error?)
}

extension URL {
    
    var isDirectory: Bool {
        guard isFileURL else { return false }
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &directory) ? directory.boolValue : false
    }
    
    var subDirectories: [URL] {
        guard isDirectory else { return [] }
        return (try? FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).filter{ $0.isDirectory }) ?? []
    }
    
}

final class DownloadManager: NSObject {
    
    fileprivate let configuration = URLSessionConfiguration.background(withIdentifier: "WWDC Video Downloader")
    fileprivate var backgroundSession: Foundation.URLSession!
    fileprivate var downloadTasks: [String : URLSessionDownloadTask] = [:]
    fileprivate let defaults = UserDefaults.standard
    
    fileprivate var storage: Storage!
    
    static let shared: DownloadManager = DownloadManager()
    
    override init() {
        super.init()
        
        self.backgroundSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    func start(with storage: Storage) {
        self.storage = storage
        
        backgroundSession.getTasksWithCompletionHandler { _, _, pendingTasks in
            for task in pendingTasks {
                if let key = task.originalRequest?.url!.absoluteString {
                    self.downloadTasks[key] = task
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: .LocalVideoStoragePathPreferenceDidChange, object: nil, queue: nil) { _ in
            self.monitorDownloadsFolder()
        }
        
        monitorDownloadsFolder()
    }
    
    fileprivate func localStoragePath(for asset: SessionAsset) -> String {
        return Preferences.shared.localVideoStorageURL.appendingPathComponent(asset.relativeLocalURL).path
    }
    
    func allTasks() -> [URLSessionDownloadTask] {
        return Array(self.downloadTasks.values)
    }
    
    func download(_ asset: SessionAsset) {
        downloadRemoteUrl(asset.remoteURL)
    }
    
    private func downloadRemoteUrl(_ url: String) {
        if isDownloading(url) || hasVideo(url) {
            return
        }
        
        let task = backgroundSession.downloadTask(with: URL(string: url)!)
        if let key = task.originalRequest?.url!.absoluteString {
            self.downloadTasks[key] = task
        }
        task.resume()
        
        NotificationCenter.default.post(name: .DownloadManagerDownloadStarted, object: url)
    }
    
    func pauseDownload(_ url: String) -> Bool {
        if let task = downloadTasks[url] {
            task.suspend()
            NotificationCenter.default.post(name: .DownloadManagerDownloadPaused, object: url)
            return true
        }
        print("VideoStore was asked to pause downloading URL \(url), but there's no task for that URL")
        return false
    }
    
    func resumeDownload(_ url: String) -> Bool {
        if let task = downloadTasks[url] {
            task.resume()
            NotificationCenter.default.post(name: .DownloadManagerDownloadResumed, object: url)
            return true
        }
        print("VideoStore was asked to resume downloading URL \(url), but there's no task for that URL")
        return false
    }
    
    func cancelDownload(_ url: String) -> Bool {
        if let task = downloadTasks[url] {
            task.cancel()
            self.downloadTasks.removeValue(forKey: url)
            NotificationCenter.default.post(name: Notification.Name.DownloadManagerDownloadCancelled, object: url)
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
    
    func localVideoPath(_ remoteURL: String) -> String? {
        guard let url = URL(string: remoteURL) else { return nil }
        
        guard let asset = storage.asset(with: url) else {
            return nil
        }
        
        let path = localStoragePath(for: asset)
        
        return path
    }
    
    func localFileURL(for session: Session) -> URL? {
        guard let asset = session.asset(of: .hdVideo) else { return nil }
        
        let path = self.localStoragePath(for: asset)
        
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        
        return URL(fileURLWithPath: path)
    }
    
    func localVideoAbsoluteURLString(_ remoteURL: String) -> String? {
        guard let localPath = localVideoPath(remoteURL) else { return nil }
        
        return URL(fileURLWithPath: localPath).absoluteString
    }
    
    func hasVideo(_ url: String) -> Bool {
        guard let path = self.localVideoPath(url) else { return false }
        
        return FileManager.default.fileExists(atPath: path)
    }
    
    enum RemoveDownloadError: Error {
        case notDownloaded
        case fileSystem(Error)
        case internalError(String)
    }
    
    func removeDownload(_ url: String) throws {
        if isDownloading(url) {
            _ = cancelDownload(url)
            return
        }
        
        if hasVideo(url) {
            guard let path = localVideoPath(url) else {
                throw RemoveDownloadError.internalError("Unable to generate local video path from remote URL")
            }
            
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                throw RemoveDownloadError.fileSystem(error)
            }
        } else {
            throw RemoveDownloadError.notDownloaded
        }
    }
    
    func deleteDownload(for asset: SessionAsset) {
        do {
            try removeDownload(asset.remoteURL)
        } catch {
            WWDCAlert.show(with: error)
        }
    }
    
    func downloadedFileURL(for session: Session) -> URL? {
        guard let asset = session.assets.filter("rawAssetType == %@", SessionAssetType.hdVideo.rawValue).first else {
            return nil
        }
        
        let path = self.localStoragePath(for: asset)
        
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        
        return URL(fileURLWithPath: path)
    }
    
    func downloadStatusObservable(for session: Session) -> Observable<DownloadStatus>? {
        guard let asset = session.asset(of: .hdVideo) else { return nil }
        
        return Observable<DownloadStatus>.create { observer -> Disposable in
            let nc = NotificationCenter.default
            let q = OperationQueue.main
            
            let checkDownloadedState = {
                if self.isDownloading(asset.remoteURL) {
                    observer.onNext(.downloading(-1))
                } else if self.hasVideo(asset.remoteURL) {
                    observer.onNext(.finished)
                } else {
                    observer.onNext(.none)
                }
            }
            
            checkDownloadedState()
            
            let fileDeleted = nc.addObserver(forName: .DownloadManagerFileDeletedNotification, object: nil, queue: q) { note in
                guard asset.relativeLocalURL == note.object as? String else { return }
                
                observer.onNext(.none)
            }
            
            let fileAdded = nc.addObserver(forName: .DownloadManagerFileAddedNotification, object: nil, queue: q) { note in
                guard asset.relativeLocalURL == note.object as? String else { return }
                
                observer.onNext(.finished)
            }
            
            let started = nc.addObserver(forName: .DownloadManagerDownloadStarted, object: nil, queue: q) { note in
                guard asset.remoteURL == note.object as? String else { return }
                
                observer.onNext(.downloading(-1))
            }
            
            let cancelled = nc.addObserver(forName: .DownloadManagerDownloadCancelled, object: nil, queue: q) { note in
                guard asset.remoteURL == note.object as? String else { return }
                
                observer.onNext(.cancelled)
            }
            
            let paused = nc.addObserver(forName: .DownloadManagerDownloadPaused, object: nil, queue: q) { note in
                guard asset.remoteURL == note.object as? String else { return }
                
                observer.onNext(.paused)
            }
            
            let resumed = nc.addObserver(forName: .DownloadManagerDownloadResumed, object: nil, queue: q) { note in
                guard asset.remoteURL == note.object as? String else { return }
                
                observer.onNext(.downloading(-1))
            }
            
            let failed = nc.addObserver(forName: .DownloadManagerDownloadFailed, object: nil, queue: q) { note in
                guard asset.remoteURL == note.object as? String else { return }
                
                let error = note.userInfo?["error"] as? Error
                observer.onNext(.failed(error))
            }
            
            let finished = nc.addObserver(forName: .DownloadManagerDownloadFinished, object: nil, queue: q) { note in
                guard asset.remoteURL == note.object as? String else { return }
                
                observer.onNext(.finished)
            }
            
            let progress = nc.addObserver(forName: .DownloadManagerDownloadProgressChanged, object: nil, queue: q) { note in
                guard asset.remoteURL == note.object as? String else { return }
                
                if let info = note.userInfo?["info"] as? DownloadInfo {
                    observer.onNext(.downloading(info.progress))
                } else {
                    observer.onNext(.downloading(-1))
                }
            }
            
            return Disposables.create {
                nc.removeObserver(fileDeleted)
                nc.removeObserver(fileAdded)
                nc.removeObserver(started)
                nc.removeObserver(cancelled)
                nc.removeObserver(paused)
                nc.removeObserver(resumed)
                nc.removeObserver(failed)
                nc.removeObserver(finished)
                nc.removeObserver(progress)
            }
        }
    }
    
    // MARK: File observation
    
    fileprivate var topFolderMonitor: DTFolderMonitor!
    fileprivate var subfoldersMonitors: [DTFolderMonitor] = []
    fileprivate var existingVideoFiles = [String]()
    
    func monitorDownloadsFolder() {
        if topFolderMonitor != nil {
            topFolderMonitor.stopMonitoring()
            topFolderMonitor = nil
        }
        
        let videosPath = Preferences.shared.localVideoStorageURL.path
        enumerateVideoFiles(videosPath)
        let mainDirURL = URL(fileURLWithPath: videosPath)
        
        topFolderMonitor = DTFolderMonitor(for: mainDirURL) { [unowned self] in
            self.enumerateVideoFiles(videosPath)
            
            self.setupSubdirectoryMonitors(on: mainDirURL)
        }
        
        setupSubdirectoryMonitors(on: mainDirURL)
        
        topFolderMonitor.startMonitoring()
    }
    
    private func setupSubdirectoryMonitors(on mainDirURL: URL) {
        subfoldersMonitors.forEach({ $0.stopMonitoring() })
        subfoldersMonitors.removeAll()
        
        mainDirURL.subDirectories.forEach { subdir in
            guard let monitor = DTFolderMonitor(for: subdir, block: { [unowned self] in
                self.enumerateVideoFiles(mainDirURL.path)
            }) else { return }
            
            subfoldersMonitors.append(monitor)
            
            monitor.startMonitoring()
        }
    }
    
    /// Updates the downloaded status for the sessions on the database based on the existence of the downloaded video file
    fileprivate func enumerateVideoFiles(_ path: String) {
        guard let enumerator = FileManager.default.enumerator(atPath: path) else { return }
        guard let files = enumerator.allObjects as? [String] else { return }
        
        // existing/added files
        for file in files {
            storage.updateDownloadedFlag(true, forAssetWithRelativeLocalURL: file)
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .DownloadManagerFileAddedNotification, object: file)
            }
        }
        
        if existingVideoFiles.count == 0 {
            existingVideoFiles = files
            return
        }
        
        // removed files
        let removedFiles = existingVideoFiles.filter { !files.contains($0) }
        for file in removedFiles {
            storage.updateDownloadedFlag(false, forAssetWithRelativeLocalURL: file)
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .DownloadManagerFileDeletedNotification, object: file)
            }
        }
    }
    
    // MARK: Teardown
    
    deinit {
        if topFolderMonitor != nil {
            topFolderMonitor.stopMonitoring()
        }
    }
    
}

extension DownloadManager: URLSessionDownloadDelegate, URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let originalURL = downloadTask.originalRequest?.url else { return }
        
        let originalAbsoluteURLString = originalURL.absoluteString
        
        guard let localPath = self.localVideoPath(originalAbsoluteURLString) else { return }
        let destinationUrl = URL(fileURLWithPath: localPath)
        let destinationDir = destinationUrl.deletingLastPathComponent()
        
        do {
            if !FileManager.default.fileExists(atPath: destinationDir.path) {
                try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            try FileManager.default.moveItem(at: location, to: destinationUrl)
            
            downloadTasks.removeValue(forKey: originalAbsoluteURLString)
            
            NotificationCenter.default.post(name: .DownloadManagerDownloadFinished, object: originalAbsoluteURLString)
        } catch {
            NotificationCenter.default.post(name: .DownloadManagerDownloadFailed, object: originalAbsoluteURLString, userInfo: ["error": error])
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let originalURL = task.originalRequest?.url else { return }
        
        let originalAbsoluteURLString = originalURL.absoluteString
        
        let info: [String: Error]?
        
        if let error = error {
            info = ["error": error]
        } else {
            info = nil
        }
        
        NotificationCenter.default.post(name: .DownloadManagerDownloadFailed, object: originalAbsoluteURLString, userInfo: info)
    }
    
    fileprivate struct DownloadInfo {
        let totalBytesWritten: Int64
        let totalBytesExpectedToWrite: Int64
        let progress: Double
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let originalURL = downloadTask.originalRequest?.url?.absoluteString else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let info = DownloadInfo(totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite, progress: progress)
        NotificationCenter.default.post(name: .DownloadManagerDownloadProgressChanged, object: originalURL, userInfo: ["info": info])
    }
    
}
