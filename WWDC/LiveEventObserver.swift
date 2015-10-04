//
//  LiveEventObserver.swift
//  WWDC
//
//  Created by Guilherme Rambo on 16/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

public let LiveEventNextInfoChangedNotification = "LiveEventNextInfoChangedNotification"
public let LiveEventTitleAvailableNotification = "LiveEventTitleAvailableNotification"
public let LiveEventWillStartPlayingNotification = "LiveEventWillStartPlayingNotification"
private let _sharedInstance = LiveEventObserver()

class LiveEventObserver: NSObject, NSUserNotificationCenterDelegate {

    var nextEvent: LiveSession? {
        didSet {
            NSNotificationCenter.defaultCenter().postNotificationName(LiveEventNextInfoChangedNotification, object: nil)
        }
    }
    private var lastEventFound: LiveSession?
    private var timer: NSTimer?
    private var liveEventPlayerController: VideoWindowController?
    
    class func SharedObserver() -> LiveEventObserver {
        return _sharedInstance
    }
    
    func start() {
        NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self
        
        timer = NSTimer.scheduledTimerWithTimeInterval(Preferences.SharedPreferences().liveEventCheckInterval, target: self, selector: "checkNow", userInfo: nil, repeats: true)
        checkNow()
    }
    
    func checkNow() {
        checkForLiveEvent { available, event in
            dispatch_async(dispatch_get_main_queue()) {
                if !available && self.liveEventPlayerController != nil {
                    self.liveEventPlayerController?.close()
                    return
                }
                
                // an event is available
                if available && event != nil {
                    self.lastEventFound = event
                    self.playEvent(event!)
                }
            }
        }
        
        fetchNextLiveEvent { available, event in
            dispatch_async(dispatch_get_main_queue()) {
                self.nextEvent = event
            }
        }
    }
    
    func playEvent(event: LiveSession) {
        if Preferences.SharedPreferences().autoplayLiveEvents || overrideAutoplayPreference {
            doPlayEvent(event)
        }
        
        showNotification(event)
    }
    
    private func doPlayEvent(event: LiveSession) {
        // we already have a live event playing, just return
        if liveEventPlayerController != nil {
            NSNotificationCenter.defaultCenter().postNotificationName(LiveEventTitleAvailableNotification, object: event.title)
            return
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(LiveEventWillStartPlayingNotification, object: nil)
        
        liveEventPlayerController = VideoWindowController(event: event, videoURL: event.streamURL!.absoluteString)
        liveEventPlayerController?.showWindow(nil)
    }
    
    // MARK: User notifications

    let liveEventNotificationIdentifier = "LiveEvent"
    var overrideAutoplayPreference = false
    
    func checkNowAndPlay() {
        overrideAutoplayPreference = true
        
        if let event = lastEventFound {
            doPlayEvent(event)
        } else {
            checkNow()
        }
    }
    
    func showNotification(event: LiveSession) {
        let notification = NSUserNotification()
        notification.title = "\(event.title) is live!"
        notification.informativeText = "Watch \(event.title) right now!"
        notification.hasActionButton = true
        notification.actionButtonTitle = "Watch"
        notification.deliveryDate = NSDate()
        notification.identifier = liveEventNotificationIdentifier
        NSUserNotificationCenter.defaultUserNotificationCenter().scheduleNotification(notification)
    }
    
    func userNotificationCenter(center: NSUserNotificationCenter, didActivateNotification notification: NSUserNotification) {
        if notification.identifier == liveEventNotificationIdentifier {
            checkNowAndPlay()
        }
    }
    
    private let _liveServiceURL = "http://wwdc.guilhermerambo.me/live.json"
    private let _liveNextServiceURL = "http://wwdc.guilhermerambo.me/next.json"
    
    private var liveURL: NSURL {
        get {
            sranddev()
            // adds a random number as a parameter to completely prevent any caching
            return NSURL(string: "\(_liveServiceURL)?t=\(rand())&s=\(NSDate.timeIntervalSinceReferenceDate())")!
        }
    }
    
    private var liveNextURL: NSURL {
        get {
            sranddev()
            // adds a random number as a parameter to completely prevent any caching
            return NSURL(string: "\(_liveNextServiceURL)?t=\(rand())&s=\(NSDate.timeIntervalSinceReferenceDate())")!
        }
    }
    
    let URLSession2 = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())
    
    func checkForLiveEvent(completionHandler: (Bool, LiveSession?) -> ()) {
        let task = URLSession2.dataTaskWithURL(liveURL) { data, response, error in
            if data == nil {
                completionHandler(false, nil)
                return
            }
            
            let jsonData = JSON(data: data!)
            let event = LiveSession(jsonObject: jsonData)
            
            if event.isLiveRightNow {
                completionHandler(true, event)
            } else {
                completionHandler(false, nil)
            }
        }
        task.resume()
    }
    
    func fetchNextLiveEvent(completionHandler: (Bool, LiveSession?) -> ()) {
        let task = URLSession2.dataTaskWithURL(liveNextURL) { data, response, error in
            if data == nil {
                completionHandler(false, nil)
                return
            }
            
            let jsonData = JSON(data: data!)
            let event = LiveSession(jsonObject: jsonData)
            
            if event.title != "" {
                completionHandler(true, event)
            } else {
                completionHandler(false, nil)
            }
        }
        task.resume()
    }
    
}
