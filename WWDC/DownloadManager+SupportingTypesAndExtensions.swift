//
//  DownloadManager+SupportingTypesAndExtensions.swift
//  WWDC
//
//  Created by Allen Humphreys on 10/19/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

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

extension URL {

    var isDirectory: Bool {
        guard isFileURL else { return false }
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &directory) ? directory.boolValue : false
    }

    var subDirectories: [URL] {
        guard isDirectory else { return [] }
        return (try? FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).filter { $0.isDirectory }) ?? []
    }

}
