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
            return NSProcessInfo.processInfo().arguments.contains("--use-localhost")
        #else
            return false
        #endif
    }
    
    private static var shouldUseFakeTestData: Bool {
        #if DEBUG
            return NSProcessInfo.processInfo().arguments.contains("--use-fake-data")
        #else
            return false
        #endif
    }
    
    private static var server: String {
        if shouldUseTestServer {
            return "http://localhost"
        } else {
            return "http://wwdc.guilhermerambo.me"
        }
    }
    
    private static func URL(path: String) -> String {
        return server + path
    }
    
    // MARK: - Paths
    
    static var indexURL: String {
        if shouldUseFakeTestData {
            return URL("/fake_index.json")
        } else {
            return "https://devimages-cdn.apple.com/wwdc-services/g7tk3guq/xhgbpyutb6wvn2xcrbcz/wwdc.json"
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
        return URL("/videos_live.json")
    }
    
    // MARK: - Transcript ignore
    
    static let yearsToIgnoreTranscript = [2011]
    static let reloadableYears = [2016]
    
}