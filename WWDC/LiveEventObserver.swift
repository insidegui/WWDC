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
            NotificationCenter.default.post(name: Notification.Name(rawValue: LiveEventNextInfoChangedNotification), object: nil)
        }
    }
    fileprivate var lastEventFound: LiveSession?
    fileprivate var timer: Timer?
    fileprivate var liveEventPlayerController: VideoPlayerWindowController?
    
    class func SharedObserver() -> LiveEventObserver {
        return _sharedInstance
    }
    
    func start() {
        NSUserNotificationCenter.default.delegate = self
        
        timer = Timer.scheduledTimer(timeInterval: Preferences.SharedPreferences().liveEventCheckInterval, target: self, selector: #selector(LiveEventObserver.checkNow), userInfo: nil, repeats: true)
        checkNow()
    }
    
    var liveSessions = [LiveSession]() {
        didSet {
            NotificationCenter.default.post(name: Notification.Name(rawValue: LiveSessionsListDidChangeNotification), object: self)
        }
    }
    
    func checkNow() {
        checkForLiveWWDCSessions { sessions in
            DispatchQueue.main.async {
                self.liveSessions = sessions
            }
        }
        
        checkForLiveEvent { available, event in
            DispatchQueue.main.async {
                if !available && self.liveEventPlayerController != nil {
                    self.liveEventPlayerController?.close()
                    self.liveEventPlayerController = nil
                    return
                }
                
                if let lastEvent = self.lastEventFound, let currentEvent = event, lastEvent.streamURL != currentEvent.streamURL {
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
    
    func playEvent(_ event: LiveSession) {
        if Preferences.SharedPreferences().autoplayLiveEvents || overrideAutoplayPreference {
            doPlayEvent(event)
        }
        
        showNotification(event)
    }
    
    fileprivate func doPlayEvent(_ event: LiveSession, ignoreExisting: Bool = false) {
        if liveEventPlayerController != nil && !ignoreExisting {
            NotificationCenter.default.post(name: Notification.Name(rawValue: LiveEventTitleAvailableNotification), object: event.title)
            liveEventPlayerController?.window?.title = event.title
            return
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: LiveEventWillStartPlayingNotification), object: nil)
        
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
    
    func showNotification(_ event: LiveSession) {
        let notification = NSUserNotification()
        notification.title = "\(event.title) is live!"
        notification.informativeText = "Watch \(event.title) right now!"
        notification.hasActionButton = true
        notification.actionButtonTitle = "Watch"
        notification.deliveryDate = Date()
        notification.identifier = liveEventNotificationIdentifier
        NSUserNotificationCenter.default.scheduleNotification(notification)
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        if notification.identifier == liveEventNotificationIdentifier {
            checkNowAndPlay()
        }
    }
    
    fileprivate var specialLiveURL: URL {
        return URL(string: WWDCEnvironment.specialLiveEventURL)!
    }
    
    fileprivate var liveSessionsURL: URL {
        return URL(string: WWDCEnvironment.liveSessionsURL)!
    }
    
    let URLSession2 = URLSession(configuration: URLSessionConfiguration.ephemeral)
    
    func checkForLiveEvent(_ completionHandler: @escaping (Bool, LiveSession?) -> ()) {
        let task = URLSession2.dataTask(with: specialLiveURL, completionHandler: { data, response, error in
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
        }) 
        task.resume()
    }
    
    func checkForLiveWWDCSessions(_ completionHandler: @escaping (_ liveSessions: [LiveSession]) -> ()) {
        let task = URLSession2.dataTask(with: liveSessionsURL, completionHandler: { data, response, error in
            guard let data = data, data.count > 0 else {
                completionHandler([])
                return
            }
            
            let jsonData = JSON(data: data)
            guard let sessionsJSON = jsonData["live_sessions"].array else {
                completionHandler([])
                return
            }
            
            completionHandler(sessionsJSON.map({ LiveSessionAdapter.adapt($0) }))
        }) 
        task.resume()
    }
    
}
