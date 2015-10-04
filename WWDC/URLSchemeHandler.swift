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
        let sessionKey = "#\(year)-\(id)"
        guard let session = WWDCDatabase.sharedDatabase.realm.objectForPrimaryKey(Session.self, key: sessionKey) else { return }
        
        // session has HD video
        if let url = session.hd_url {
            if VideoStore.SharedStore().hasVideo(url) {
                // HD video is available locally
                let url = VideoStore.SharedStore().localVideoAbsoluteURLString(url)
                launchVideo(session, url: url)
            } else {
                // HD video is not available locally
                launchVideo(session, url: url)
            }
        } else {
            // session has only SD video
            launchVideo(session, url: session.videoURL)
        }
    }
    
    private func launchVideo(session: Session, url: String) {
        let controller = VideoWindowController(session: session, videoURL: url)
        controller.showWindow(self)
    }
    
}