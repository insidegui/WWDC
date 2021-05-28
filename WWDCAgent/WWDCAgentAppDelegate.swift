//
//  WWDCAgentAppDelegate.swift
//  WWDCAgent
//
//  Created by Guilherme Rambo on 24/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Cocoa
@_exported import os.log

extension OSLog {
    static func agentLog(with category: String) -> OSLog {
        OSLog(subsystem: "io.wwdc.agent", category: category)
    }
}

@main
final class WWDCAgentAppDelegate: NSObject, NSApplicationDelegate {
    
    private let log = OSLog.agentLog(with: String(describing: WWDCAgentAppDelegate.self))
    
    private let service = WWDCAgentService()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("Agent running", log: self.log, type: .debug)
        
        // We want to read from the main app's storage, not our own.
        PathUtil.bundleIdentifier = "io.wwdc.app"
        
        service.start()
    }

}
