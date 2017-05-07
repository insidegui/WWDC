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

final class DownloadManager: NSObject {
    
    fileprivate let storage: Storage
    
    fileprivate var tasks: [String: URLSessionDownloadTask] = [:]
    
    fileprivate lazy var downloadSession: URLSession = {
        let s = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue.main)
        
        return s
    }()
    
    init(_ storage: Storage) {
        self.storage = storage
    }
    
    func download(_ asset: SessionAsset) {
        guard let url = URL(string: asset.remoteURL) else { return }
        
        storage.createDownload(for: asset)
        
        let task = downloadSession.downloadTask(with: url)
        
        self.tasks[asset.remoteURL] = task
        
        task.resume()
    }
    
}

extension DownloadManager: URLSessionDelegate, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let url = downloadTask.originalRequest?.url else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        let download = storage.asset(with: url)?.downloads.first
        storage.update {
            download?.status = .downloading
            download?.progress = progress
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let url = downloadTask.originalRequest?.url else { return }
        guard let asset = storage.asset(with: url) else { return }
        guard let dir = NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true).first else { return }
        
        let finalPath = dir + "/" + asset.relativeLocalURL
        
        let download = asset.downloads.first
        
        do {
            let finalURL = URL(fileURLWithPath: finalPath)
            let finalDirURL = finalURL.deletingLastPathComponent()
            
            try FileManager.default.createDirectory(at: finalDirURL, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.moveItem(at: location, to: finalURL)
            
            storage.update {
                download?.status = .completed
                download?.progress = 1
            }
        } catch {
            NSLog("Error copying file downloaded for \(asset): \(error)")
            
            storage.update {
                download?.status = .failed
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let url = task.originalRequest?.url else { return }
        
        let download = storage.asset(with: url)?.downloads.first
        storage.update {
            download?.status = error != nil ? .failed : .completed
        }
    }
    
}
