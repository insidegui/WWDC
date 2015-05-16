//
//  LiveEventObserver.swift
//  WWDC
//
//  Created by Guilherme Rambo on 16/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

private let _sharedInstance = LiveEventObserver()

class LiveEventObserver: NSObject {

    private var timer: NSTimer?
    
    class func SharedObserver() -> LiveEventObserver {
        return _sharedInstance
    }
    
    func start() {
        timer = NSTimer.scheduledTimerWithTimeInterval(30.0, target: self, selector: "checkNow", userInfo: nil, repeats: true)
        checkNow()
    }
    
    func checkNow() {
        DataStore.SharedStore.checkForLiveEvent { available, event in
            // TODO: do something when available == true (maybe just open a player window and start streaming)
            println("Live event: \(available)")
        }
    }
    
}
