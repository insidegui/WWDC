//
//  SearchController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/06/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class SearchController: NSObject {
    
    private var finishedSetup = false
    
    var sessions: [Session]? {
        didSet {
            if sessions == nil {
                return
            }
            
            if !finishedSetup {
                finishedSetup = true
                
                let savedTerm = Preferences.SharedPreferences().searchTerm
                if savedTerm != "" {
                    searchFor(savedTerm)
                } else {
                    displayedSessions = sessions
                }
            }
        }
    }
    var displayedSessions: [Session]? {
        didSet {
            if finishedSetup {
                searchDidFinishCallback()
            }
        }
    }
    
    var searchDidStartCallback: () -> Void = {}
    var searchDidFinishCallback: () -> Void = {}
    
    private let searchQ = dispatch_queue_create("Search Queue", DISPATCH_QUEUE_CONCURRENT)
    private var searchOperationQueue: NSOperationQueue!
    private var currentSearchOperation: SearchOperation?
    
    func searchFor(term: String?) {
        if term == nil || sessions == nil {
            return
        }
        
        if ((term!).characters.count <= 3) && ((term!).characters.count != 0) {
            return
        }
        
        searchDidStartCallback()
        
        if searchOperationQueue == nil {
            searchOperationQueue = NSOperationQueue()
            searchOperationQueue.underlyingQueue = searchQ
        }
        
        if let operation = currentSearchOperation {
            operation.cancel()
        }
        
        if let term = term {
            currentSearchOperation = SearchOperation(sessions: sessions!, term: term) {
                self.displayedSessions = self.currentSearchOperation!.result
            }
            searchOperationQueue.addOperation(currentSearchOperation!)
        } else {
            displayedSessions = sessions
        }
    }
    
}