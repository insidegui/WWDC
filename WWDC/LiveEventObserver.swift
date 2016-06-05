//
//  LiveEventObserver.swift
//  WWDC
//
//  Created by Guilherme Rambo on 16/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import WWDCPlayer

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
    private var liveEventPlayerController: VideoPlayerWindowController?
    
    class func SharedObserver() -> LiveEventObserver {
        return _sharedInstance
    }
    
    func start() {
        NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self
        
        timer = NSTimer.scheduledTimerWithTimeInterval(Preferences.SharedPreferences().liveEventCheckInterval, target: self, selector: #selector(LiveEventObserver.checkNow), userInfo: nil, repeats: true)
        checkNow()
    }
    
    func checkNow() {
        checkForLiveEvent { available, event in
            dispatch_async(dispatch_get_main_queue()) {
                if !available && self.liveEventPlayerController != nil {
                    self.liveEventPlayerController?.close()
                    self.liveEventPlayerController = nil
                    return
                }
                
                if let lastEvent = self.lastEventFound, currentEvent = event where lastEvent.streamURL != currentEvent.streamURL {
                    // event streaming URL changed
                    self.doPlayEvent(currentEvent, ignoreExisting: true)
                } else {
                    // an event is available
                    if available && event != nil {
                        self.playEvent(event!)
                    }
                }
                
                self.lastEventFound = event
            }
        }
    }
    
    func playEvent(event: LiveSession) {
        if Preferences.SharedPreferences().autoplayLiveEvents || overrideAutoplayPreference {
            doPlayEvent(event)
        }
        
        showNotification(event)
    }
    
    private func doPlayEvent(event: LiveSession, ignoreExisting: Bool = false) {
        if liveEventPlayerController != nil && !ignoreExisting {
            NSNotificationCenter.defaultCenter().postNotificationName(LiveEventTitleAvailableNotification, object: event.title)
            liveEventPlayerController?.window?.title = event.title
            return
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(LiveEventWillStartPlayingNotification, object: nil)
        
        if liveEventPlayerController != nil {
            liveEventPlayerController?.close()
            liveEventPlayerController = nil
        }
        
        let viewController = VideoPlayerViewController.withLiveSession(event)
        liveEventPlayerController = VideoPlayerWindowController(playerViewController: viewController)
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
    
    private let _liveServiceURL = WWDCEnvironment.specialLiveEventURL
    
    private var liveURL: NSURL {
        get {
            sranddev()
            // adds a random number as a parameter to completely prevent any caching
            return NSURL(string: "\(_liveServiceURL)?t=\(rand())&s=\(NSDate.timeIntervalSinceReferenceDate())")!
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
    
}
