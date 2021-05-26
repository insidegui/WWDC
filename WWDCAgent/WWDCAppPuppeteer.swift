//
//  WWDCAppPuppeteer.swift
//  WWDCAgent
//
//  Created by Guilherme Rambo on 26/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Cocoa
import os.log

final class WWDCAppPuppeteer {
    
    private let log = OSLog.agentLog(with: String(describing: WWDCAppPuppeteer.self))
    
    func sendCommand(_ command: WWDCAppCommand, completion: @escaping (Bool) -> Void) {
        guard let commandURL = command.url else {
            assertionFailure("Failed to generate URL for command")
            os_log("Failed to generate URL for command %@", log: self.log, type: .fault, String(describing: command))
            completion(false)
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--background"]
        config.activates = false
        config.addsToRecentItems = false
        
        NSWorkspace.shared.open(commandURL, configuration: config) { _, error in
            if let error = error {
                os_log("Failed to open command URL: %{public}@", log: self.log, type: .error, String(describing: error))
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
}
