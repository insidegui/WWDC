//
//  Environment.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct Environment {
    
    let baseURL: String
    let videosPath: String
    let sessionsPath: String
    let newsPath: String
    let liveVideosPath: String
    
}

extension Environment {
    
    static let test = Environment(baseURL: "http://localhost:9042",
                                  videosPath: "/videos.json",
                                  sessionsPath: "/sessions.json",
                                  newsPath: "/news.json",
                                  liveVideosPath: "/videos_live.json")
    
}
