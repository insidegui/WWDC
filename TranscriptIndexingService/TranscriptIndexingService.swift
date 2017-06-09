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

final class TranscriptIndexingService: NSObject, TranscriptIndexingServiceProtocol {

    private var transcriptIndexer: TranscriptIndexer!

    func indexTranscriptsIfNeeded(storageURL: URL, schemaVersion: UInt64) {
        if transcriptIndexer == nil {
            do {
                let config = Realm.Configuration(fileURL: storageURL, schemaVersion: schemaVersion)
                let storage = try Storage(config)
                transcriptIndexer = TranscriptIndexer(storage)
            } catch {
                NSLog("[TranscriptIndexingService] Error initializing: \(error)")
                return
            }
        }

        transcriptIndexer.downloadTranscriptsIfNeeded()
    }

}
