//
//  URLSchemeHandler.swift
//  WWDC
//
//  Created by Guilherme Rambo on 29/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Foundation

private let _sharedInstance = URLSchemeHandler()

class URLSchemeHandler: NSObject {
    
    class func SharedHandler() -> URLSchemeHandler {
        return _sharedInstance
    }
    
    func register() {
        NSAppleEventManager.sharedAppleEventManager().setEventHandler(self, andSelector: "handleURLEvent:replyEvent:", forEventClass: UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))
    }
    
    func handleURLEvent(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptorForKeyword(UInt32(keyDirectObject))?.stringValue {
            if let url = NSURL(string: urlString) {
                if let host = url.host {
                    if let path = url.path {
                        findAndOpenSession(host,path.stringByReplacingOccurrencesOfString("/", withString: "", options: .CaseInsensitiveSearch, range: nil))
                    }
                }
            }
        }
    }
    
    private func findAndOpenSession(year: String, _ id: String) {
        if let sessions = DataStore.SharedStore.cachedSessions {
            println("Year: \(year) | id: \(id)")
            let foundSession = sessions.filter { session in
                if session.year == year.toInt()! && session.id == id.toInt()! {
                    return true
                } else {
                    return false
                }
            }
            
            if foundSession.count > 0 {
                let session = foundSession[0]

                if let url = session.hd_url {
                    if VideoStore.SharedStore().hasVideo(url) {
                        let url = VideoStore.SharedStore().localVideoAbsoluteURLString(url)
                        launchVideo(session, url: url)
                    } else {
                        launchVideo(session, url: url)
                    }
                } else {
                    launchVideo(session, url: session.url)
                }
            }
        }
    }
    
    private func launchVideo(session: Session, url: String) {
        let controller = VideoWindowController(session: session, videoURL: url)
        controller.showWindow(self)
    }
    
}