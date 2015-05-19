//
//  LiveEventObserver.swift
//  WWDC
//
//  Created by Guilherme Rambo on 16/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

public let LiveEventWillStartPlayingNotification = "LiveEventWillStartPlayingNotification"
private let _sharedInstance = LiveEventObserver()

class LiveEventObserver: NSObject {

    private var timer: NSTimer?
    private var liveEventPlayerController: VideoWindowController?
    
    class func SharedObserver() -> LiveEventObserver {
        return _sharedInstance
    }
    
    func start() {
        timer = NSTimer.scheduledTimerWithTimeInterval(Preferences.SharedPreferences().liveEventCheckInterval, target: self, selector: "checkNow", userInfo: nil, repeats: true)
        checkNow()
    }
    
    func checkNow() {
        DataStore.SharedStore.checkForLiveEvent { available, event in
            dispatch_async(dispatch_get_main_queue()) {
                // if we are currently playing an event and the event becomes unavailable, close the player
                if !available && self.liveEventPlayerController != nil {
                    self.liveEventPlayerController?.close()
                    return
                }
                
                // an event is available
                if available && event != nil {
                    self.playEvent(event!)
                }
            }
        }
    }
    
    func playEvent(event: LiveEvent) {
        if Preferences.SharedPreferences().autoplayLiveEvents {
            doPlayEvent(event)
        } else {
            // TODO: show a notification and let the user choose whether to play the event or not
            println("[LiveEventObserver] autoplayLiveEvents == false not handled")
        }
    }
    
    private func doPlayEvent(event: LiveEvent) {
        // we already have a live event playing, just return
        if liveEventPlayerController != nil {
            return
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(LiveEventWillStartPlayingNotification, object: nil)
        
        liveEventPlayerController = VideoWindowController(event: event, videoURL: event.stream!.absoluteString!)
        liveEventPlayerController?.showWindow(nil)
    }
    
}
