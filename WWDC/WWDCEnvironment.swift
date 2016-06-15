//
//  WWDCEnvironment.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation

struct WWDCEnvironment {
    
    // MARK: - Configuration
    
    static let liveTolerance = 60.0 * 15.0
    
    private static var shouldUseTestServer: Bool {
        #if DEBUG
            NSLog("Using localhost!")
            return NSProcessInfo.processInfo().arguments.contains("--use-localhost")
        #else
            return false
        #endif
    }
    
    private static var shouldUseFakeTestData: Bool {
        #if DEBUG
            NSLog("Using fake data!")
            return NSProcessInfo.processInfo().arguments.contains("--use-fake-data")
        #else
            return false
        #endif
    }
    
    private static var cacheAvoidingToken: String {
        return "?t=\(rand())&s=\(NSDate.timeIntervalSinceReferenceDate())"
    }
    
    private static var server: String {
        if shouldUseTestServer {
            return "http://localhost"
        } else {
            return "http://wwdc.guilhermerambo.me"
        }
    }
    
    private static func URL(path: String) -> String {
        sranddev()
        
        return server + path + cacheAvoidingToken
    }
    
    // MARK: - Paths
    
    static var indexURL: String {
        if shouldUseFakeTestData {
            return URL("/fake_index.json")
        } else {
            return URL("/index.json")
        }
    }
    
    static var extraURL: String {
        return URL("/extra.json")
    }
    
    static let asciiWWDCURL = "http://asciiwwdc.com/"
    
    static var specialLiveEventURL: String {
        return URL("/live.json")
    }
    
    static var liveSessionsURL: String {
        return URL("/videos_live.php")
    }
    
    // MARK: - Transcript ignore
    
    static let yearsToIgnoreTranscript = [2011, 2016]
    
}