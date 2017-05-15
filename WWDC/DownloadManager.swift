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

final class DownloadManager: NSObject {
    
    fileprivate let storage: Storage
    
    fileprivate var tasks: [String: URLSessionDownloadTask] = [:]
    
    fileprivate lazy var downloadQueue: OperationQueue = {
        let q = OperationQueue()
        
        q.underlyingQueue = DispatchQueue(label: "DownloadManager", qos: .background)
        
        return q
    }()
    
    fileprivate lazy var downloadSession: URLSession = {
        let s = URLSession(configuration: .default, delegate: self, delegateQueue: self.downloadQueue)
        
        return s
    }()
    
    init(_ storage: Storage) {
        self.storage = storage
    }
    
    fileprivate func localStoragePath(for asset: SessionAsset) -> String? {
        guard let dir = NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true).first else { return nil }
        
        return dir + "/WWDC/" + asset.relativeLocalURL
    }
    
    func download(_ asset: SessionAsset) {
        guard let url = URL(string: asset.remoteURL) else { return }
        
        storage.createDownload(for: asset)
        
        let task = downloadSession.downloadTask(with: url)
        
        self.tasks[asset.remoteURL] = task
        
        task.resume()
    }
    
    func deleteDownload(for asset: SessionAsset) {
        guard let download = asset.downloads.first else { return }
        
        guard let filePath = self.localStoragePath(for: asset) else { return }
        
        guard FileManager.default.fileExists(atPath: filePath) else { return }
        
        do {
            try FileManager.default.removeItem(atPath: filePath)
            
            storage.unmanagedUpdate { realm in
                realm.delete(download)
            }
        } catch {
            WWDCAlert.show(with: error)
        }
    }
    
    func localFileURL(for session: Session) -> URL? {
        guard let asset = session.assets.filter("rawAssetType == %@", SessionAssetType.hdVideo.rawValue).first else {
            return nil
        }
        
        let url = Preferences.shared.localVideoStorageURL.appendingPathComponent(asset.relativeLocalURL)
        
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        
        return url
    }
    
    fileprivate var lastStorageUpdate = Date.distantPast
    
}

extension DownloadManager: URLSessionDelegate, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    
    private func download(for url: URL) -> Download? {
        let predicate = NSPredicate(format: "remoteURL == %@", url.absoluteString)
        
        return storage.unmanagedObjects(of: SessionAsset.self, with: predicate)?.first?.downloads.first
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // limit storage writes to 1 per second
        guard Date().timeIntervalSince(lastStorageUpdate) > 1 else { return }
        
        defer { lastStorageUpdate = Date() }
        
        guard let url = downloadTask.originalRequest?.url else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        guard let download = self.download(for: url) else {
            return
        }
        
        storage.unmanagedUpdate { realm in
            download.status = .downloading
            download.progress = progress
            realm.add(download, update: true)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let url = downloadTask.originalRequest?.url else { return }
        
        guard let download = self.download(for: url) else {
            return
        }
        
        guard let asset = download.asset.first else { return }

        guard let finalPath = self.localStoragePath(for: asset) else { return }
        
        do {
            let finalURL = URL(fileURLWithPath: finalPath)
            let finalDirURL = finalURL.deletingLastPathComponent()
            
            try FileManager.default.createDirectory(at: finalDirURL, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.moveItem(at: location, to: finalURL)
            
            storage.unmanagedUpdate { realm in
                download.status = .completed
                download.progress = 1
                realm.add(download, update: true)
            }
        } catch {
            NSLog("Error copying file downloaded for \(asset): \(error)")
            
            storage.unmanagedUpdate { realm in
                download.status = .failed
                realm.add(download, update: true)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let url = task.originalRequest?.url else { return }
        
        guard let download = self.download(for: url) else { return }
        
        storage.unmanagedUpdate { realm in
            download.status = error != nil ? .failed : .completed
            realm.add(download, update: true)
        }
    }
    
}
