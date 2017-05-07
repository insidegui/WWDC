//
//  Environment.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

public struct Environment {
    
    let baseURL: String
    let videosPath: String
    let sessionsPath: String
    let newsPath: String
    let liveVideosPath: String
    
}

extension Environment {
    
    public static var current: Environment {
        if ProcessInfo.processInfo.arguments.contains("--test") {
            return .test
        } else if ProcessInfo.processInfo.arguments.contains("--contingency") {
            return .contingencyTest
        } else if ProcessInfo.processInfo.arguments.contains("--post-contingency") {
            return .postContingencyTest
        } else {
            return .production
        }
    }
    
    public static let test = Environment(baseURL: "http://localhost:9042",
                                         videosPath: "/videos.json",
                                         sessionsPath: "/sessions.json",
                                         newsPath: "/news.json",
                                         liveVideosPath: "/videos_live.json")
    
    public static let contingencyTest = Environment(baseURL: "http://localhost:9042",
                                                    videosPath: "/videos_contingency.json",
                                                    sessionsPath: "/sessions_contingency.json",
                                                    newsPath: "/news.json",
                                                    liveVideosPath: "/videos_live.json")
    
    public static let postContingencyTest = Environment(baseURL: "http://localhost:9042",
                                                        videosPath: "/videos_post_contingency.json",
                                                        sessionsPath: "/sessions_post_contingency.json",
                                                        newsPath: "/news.json",
                                                        liveVideosPath: "/videos_live.json")
    
    public static let production = Environment(baseURL: "https://devimages-cdn.apple.com/wwdc-services/g7tk3guq/xhgbpyutb6wvn2xcrbcz",
                                         videosPath: "/videos.json",
                                         sessionsPath: "/sessions.json",
                                         newsPath: "/news.json",
                                         liveVideosPath: "/videos_live.json")
    
}
