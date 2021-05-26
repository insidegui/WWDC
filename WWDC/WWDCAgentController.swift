//
//  WWDCAgentController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 26/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ServiceManagement

extension Notification.Name {
    static let WWDCAgentEnabledPreferenceChanged = Notification.Name("io.wwdc.app.AgentEnabledPreferenceChanged")
}

final class WWDCAgentController: NSObject {
    
    private(set) var isAgentEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: #function) }
        set {
            guard newValue != isAgentEnabled else { return }
            
            UserDefaults.standard.set(newValue, forKey: #function)
            
            DistributedNotificationCenter.default().postNotificationName(
                .WWDCAgentEnabledPreferenceChanged,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }
    
    private lazy var agentBundleIdentifier: String = {
        let agentURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LoginItems", isDirectory: true)
            .appendingPathComponent("WWDCAgent.app")
        
        guard let bundle = Bundle(url: agentURL) else {
            preconditionFailure("Couldn't instatiate agent bundle")
        }
        
        guard let identifier = bundle.bundleIdentifier else {
            preconditionFailure("Failed to read identifier for agent bundle")
        }
        
        return identifier
    }()
    
    func enableAgent() -> Bool {
        isAgentEnabled = SMLoginItemSetEnabled(agentBundleIdentifier as CFString, true)
        
        return isAgentEnabled
    }
    
    func disableAgent() {
        SMLoginItemSetEnabled(agentBundleIdentifier as CFString, false)
        
        isAgentEnabled = false
    }

}
