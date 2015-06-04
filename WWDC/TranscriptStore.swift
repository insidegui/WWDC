//
//  TranscriptStore.swift
//  WWDC
//
//  Created by Guilherme Rambo on 04/06/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Foundation
import ASCIIwwdc

private let _sharedStore = TranscriptStore()

class TranscriptStore {

    class var SharedStore: TranscriptStore {
        return _sharedStore
    }
    
    var hasIndex: Bool {
        return ASCIIWWDCBackgroundIndexingService.hasIndex()
    }
    
    private var ranOnce = false
    
    // run the transcript indexer only once per app launch
    func runIndexerIfNeeded(sessions: [Session]) {
        if ranOnce {
            return
        }
        
        ranOnce = true
        
        var outputSessions: [[String:Int]] = []
        for session in sessions {
            outputSessions.append(["year": session.year, "id": session.id])
        }
        
        ASCIIWWDCBackgroundIndexingService.runWithSessions(outputSessions)
    }
    
}