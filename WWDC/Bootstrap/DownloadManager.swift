//
//  DownloadManager.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Combine
import ConfCore
import RealmSwift
import OSLog

extension MediaDownloadManager {
    static let shared = MediaDownloadManager(
        directoryURL: Preferences.shared.localVideoStorageURL,
        engines: [URLSessionMediaDownloadEngine.self, AVAssetMediaDownloadEngine.self],
        metadataStorage: FSMediaDownloadMetadataStore(directoryURL: Preferences.shared.downloadMetadataStorageURL)
    )
}
