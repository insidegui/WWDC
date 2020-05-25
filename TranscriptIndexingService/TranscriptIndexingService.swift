//
//  TranscriptIndexingService.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import ConfCore
import RealmSwift
import os.log

final class TranscriptIndexingService: NSObject, TranscriptIndexingServiceProtocol {

    private var transcriptIndexer: TranscriptIndexer!
    private let log = OSLog(subsystem: "TranscriptIndexingService", category: "TranscriptIndexingService")

    func indexTranscriptsIfNeeded(manifestURL: URL, storageURL: URL, schemaVersion: UInt64) {
        if transcriptIndexer == nil {
            do {
                let config = Realm.Configuration(fileURL: storageURL, schemaVersion: schemaVersion)
                let storage = try Storage(config)
                transcriptIndexer = TranscriptIndexer(storage)
            } catch {
                os_log("Error initializing indexing service: %{public}@", log: self.log, type: .fault, String(describing: error))
                return
            }
        }

        transcriptIndexer.downloadTranscriptsIfNeeded()
    }

}
