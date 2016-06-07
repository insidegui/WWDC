//
//  LiveEventObserver.swift
//  WWDC
//
//  Created by Guilherme Rambo on 16/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import WWDCPlayer
import SwiftyJSON

public let LiveSessionsListDidChangeNotification = "LiveSessionsListDidChangeNotification"
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
    
    var liveSessions = [LiveSession]() {
        didSet {
            NSNotificationCenter.defaultCenter().postNotificationName(LiveSessionsListDidChangeNotification, object: self)
        }
    }
    
    func checkNow() {
        checkForLiveWWDCSessions { sessions in
            dispatch_async(dispatch_get_main_queue()) {
                self.liveSessions = sessions
            }
        }
        
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
    
    private var specialLiveURL: NSURL {
        return NSURL(string: WWDCEnvironment.specialLiveEventURL)!
    }
    
    private var liveSessionsURL: NSURL {
        return NSURL(string: WWDCEnvironment.liveSessionsURL)!
    }
    
    let URLSession2 = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())
    
    func checkForLiveEvent(completionHandler: (Bool, LiveSession?) -> ()) {
        let task = URLSession2.dataTaskWithURL(specialLiveURL) { data, response, error in
            if data == nil {
                completionHandler(false, nil)
                return
            }
            
            let jsonData = JSON(data: data!)
            let event = LiveSessionAdapter.adaptSpecial(jsonData)
            
            if event.isLiveRightNow {
                completionHandler(true, event)
            } else {
                completionHandler(false, nil)
            }
        }
        task.resume()
    }
    
    func checkForLiveWWDCSessions(completionHandler: (liveSessions: [LiveSession]) -> ()) {
        let task = URLSession2.dataTaskWithURL(liveSessionsURL) { data, response, error in
            guard let data = data where data.length > 0 else {
                completionHandler(liveSessions: [])
                return
            }
            
            let jsonData = JSON(data: data)
            guard let sessionsJSON = jsonData["live_sessions"].array else {
                completionHandler(liveSessions: [])
                return
            }
            
            completionHandler(liveSessions: sessionsJSON.map({ LiveSessionAdapter.adapt($0) }))
        }
        task.resume()
    }
    
}
