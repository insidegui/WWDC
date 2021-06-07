//
//  WWDCAgentController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 26/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ServiceManagement
import os.log

extension Notification.Name {
    static let WWDCAgentEnabledPreferenceChanged = Notification.Name("io.wwdc.app.AgentEnabledPreferenceChanged")
}

final class WWDCAgentController: NSObject {
    
    private let log = OSLog(subsystem: "io.wwdc.app", category: String(describing: WWDCAgentController.self))
    
    static private(set) var isAgentEnabled: Bool {
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
    
    private(set) var lastRunAgentBuild: String? {
        get { UserDefaults.standard.string(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    private lazy var agentBundle: Bundle = {
        let agentURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LoginItems", isDirectory: true)
            .appendingPathComponent("WWDCAgent.app")
        
        guard let bundle = Bundle(url: agentURL) else {
            preconditionFailure("Couldn't instatiate agent bundle")
        }
        
        return bundle
    }()
    
    private lazy var agentBundleIdentifier: String = {
        guard let identifier = agentBundle.bundleIdentifier else {
            preconditionFailure("Failed to read identifier for agent bundle")
        }
        
        return identifier
    }()
    
    private lazy var currentAgentBundleBuild: String = {
        guard let build = agentBundle.infoDictionary?["CFBundleVersion"] as? String else {
            preconditionFailure("Failed to read CFBundleVersion for agent bundle")
        }
        
        return build
    }()
    
    func enableAgent() -> Bool {
        Self.isAgentEnabled = SMLoginItemSetEnabled(agentBundleIdentifier as CFString, true)
        
        return Self.isAgentEnabled
    }
    
    func disableAgent() {
        SMLoginItemSetEnabled(agentBundleIdentifier as CFString, false)
        
        Self.isAgentEnabled = false
    }
    
    func registerAgentVersion() {
        guard currentAgentBundleBuild != lastRunAgentBuild else {
            os_log("Agent bundle build has not changed", log: self.log, type: .debug)
            return
        }
        
        if let build = lastRunAgentBuild {
            os_log("Registering new agent build: %{public}@", log: self.log, type: .debug, build)
        } else {
            os_log("Registering agent build for the first time: %{public}@", log: self.log, type: .debug, currentAgentBundleBuild)
        }
        
        lastRunAgentBuild = currentAgentBundleBuild
        
        guard let agentApp = NSRunningApplication.runningApplications(withBundleIdentifier: agentBundleIdentifier).first else {
            os_log("Couldn't find agent app running, ignoring", log: self.log, type: .debug)
            return
        }
        
        os_log("Found old agent running with pid %{public}d, restarting", log: self.log, type: .debug, agentApp.processIdentifier)
        
        if !agentApp.forceTerminate() {
            os_log("Failed to terminate agent", log: self.log, type: .fault)
        }
    }

}
