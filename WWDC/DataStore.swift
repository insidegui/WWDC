//
//  DataStore.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Foundation

private let _internalServiceURL = "http://wwdc.guilhermerambo.me/index.json"
private let _SharedStore = DataStore()

class DataStore: NSObject {
    
    class var SharedStore: DataStore {
        return _SharedStore
    }
    
    typealias fetchSessionsCompletionHandler = (Bool, [Session]) -> Void
    
//    var cachedAppleURL: NSURL? = NSUserDefaults.standardUserDefaults().URLForKey("Apple URL")
    var cachedAppleURL: NSURL? = nil
    
    let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
    
    func fetchSessions(completionHandler: fetchSessionsCompletionHandler) {
        if let appleURL = cachedAppleURL {
            doFetchSessions(completionHandler)
        } else {
            let internalServiceURL = NSURL(string: _internalServiceURL)
            
            session.dataTaskWithURL(internalServiceURL!, completionHandler: { [unowned self] data, response, error in
                if data == nil {
                    completionHandler(false, [])
                    return
                }
                
                let internalServiceJSON = JSON(data: data!).dictionary!
                let appleURL = internalServiceJSON["url"]!.string!
                
                NSUserDefaults.standardUserDefaults().setURL(NSURL(string: appleURL)!, forKey: "Apple URL")
                NSUserDefaults.standardUserDefaults().synchronize()
                self.cachedAppleURL = NSURL(string: appleURL)!
                
                self.doFetchSessions(completionHandler)
            }).resume()
        }
    }
    
    func doFetchSessions(completionHandler: fetchSessionsCompletionHandler) {
        session.dataTaskWithURL(cachedAppleURL!, completionHandler: { data, response, error in
            if data == nil {
                completionHandler(false, [])
                return
            }
            
            if let container = JSON(data: data).dictionary {
                let jsonSessions = container["sessions"]!.array!
                
                var sessions: [Session] = []
                
                for jsonSession:JSON in jsonSessions {
                    var focuses:[String] = []
                    for focus:JSON in jsonSession["focus"].array! {
                        focuses.append(focus.string!)
                    }
                    
                    let session = Session(date: jsonSession["date"].string,
                        description: jsonSession["description"].string!,
                        focus: focuses,
                        id: jsonSession["id"].int!,
                        slides: jsonSession["slides"].string,
                        title: jsonSession["title"].string!,
                        track: jsonSession["track"].string!,
                        url: jsonSession["url"].string!,
                        year: jsonSession["year"].int!)
                    
                    sessions.append(session)
                }
                
                completionHandler(true, sessions)
            } else {
                completionHandler(false, [])
            }
        }).resume()
    }
    
    let defaults = NSUserDefaults.standardUserDefaults()
    
    func fetchSessionProgress(session: Session) -> Double {
        return defaults.doubleForKey(session.progressKey)
    }
    
    func putSessionProgress(session: Session, progress: Double) {
        defaults.setDouble(progress, forKey: session.progressKey)
    }
    
    func fetchSessionCurrentPosition(session: Session) -> Double {
        return defaults.doubleForKey(session.currentPositionKey)
    }
    
    func putSessionCurrentPosition(session: Session, position: Double) {
        defaults.setDouble(position, forKey: session.currentPositionKey)
    }
    
}
