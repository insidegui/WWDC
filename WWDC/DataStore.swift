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
private let _MemoryCacheSize = 500*1024*1024
private let _DiskCacheSize = 1024*1024*1024

class DataStore: NSObject {
    
    class var SharedStore: DataStore {
        return _SharedStore
    }
    
    private let sharedCache = NSURLCache(memoryCapacity: _MemoryCacheSize, diskCapacity: _DiskCacheSize, diskPath: nil)
    
    override init() {
        NSURLCache.setSharedURLCache(sharedCache)
    }
    
    typealias fetchSessionsCompletionHandler = (Bool, [Session]) -> Void
    
    var appleSessionsURL: NSURL? = nil
    
    let URLSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
    
    func fetchSessions(completionHandler: fetchSessionsCompletionHandler) {
        if let appleURL = appleSessionsURL {
            doFetchSessions(completionHandler)
        } else {
            let internalServiceURL = NSURL(string: _internalServiceURL)
            
            URLSession.dataTaskWithURL(internalServiceURL!, completionHandler: { [unowned self] data, response, error in
                if data == nil {
                    completionHandler(false, [])
                    return
                }
                
                let internalServiceJSON = JSON(data: data!).dictionary!
                let appleURL = internalServiceJSON["url"]!.string!

                self.appleSessionsURL = NSURL(string: appleURL)!
                
                self.doFetchSessions(completionHandler)
            }).resume()
        }
    }
    
    func doFetchSessions(completionHandler: fetchSessionsCompletionHandler) {
        URLSession.dataTaskWithURL(appleSessionsURL!, completionHandler: { data, response, error in
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
                        year: jsonSession["year"].int!,
                        hd_url: jsonSession["download_hd"].string)
                    
                    sessions.append(session)
                }
                
                completionHandler(true, sessions)
            } else {
                completionHandler(false, [])
            }
        }).resume()
    }
    
    func downloadSessionSlides(session: Session, completionHandler: (Bool, NSData?) -> Void) {
        if session.slides == nil {
            completionHandler(false, nil)
            return
        }
        
        let task = URLSession.dataTaskWithURL(NSURL(string: session.slides!)!) { data, response, error in
            if data != nil {
                completionHandler(true, data)
            } else {
                completionHandler(false, nil)
            }
        }
        task.resume()
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
