//
//  Environment.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

public extension Notification.Name {
    public static let WWDCEnvironmentDidChange = Notification.Name("WWDCEnvironmentDidChange")
}

public struct Environment {

    public let baseURL: String
    public let videosPath: String
    public let sessionsPath: String
    public let newsPath: String
    public let liveVideosPath: String

    public static func setCurrent(_ environment: Environment) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let shouldNotify = (environment != Environment.current)

        _storedEnvironment = environment

        UserDefaults.standard.set(environment.baseURL, forKey: _storedEnvDefaultsKey)

        if shouldNotify {
            DispatchQueue.main.async {
                NSLog("ENVIRONMENT CHANGED! New base URL: \(environment.baseURL)")

                NotificationCenter.default.post(name: .WWDCEnvironmentDidChange, object: environment)
            }
        }
    }

}

fileprivate let _storedEnvDefaultsKey = "_confCoreEnvironmentBaseURL"

fileprivate var _storedEnvironment: Environment? = Environment.readFromDefaults()

extension Environment {

    static func readFromDefaults() -> Environment? {
        guard let baseURL = UserDefaults.standard.object(forKey: _storedEnvDefaultsKey) as? String else { return nil }

        return Environment(
            baseURL: baseURL,
            videosPath: "/videos.json",
            sessionsPath: "/sessions.json",
            newsPath: "/news.json",
            liveVideosPath: "/videos_live.json"
        )
    }

    public static var current: Environment {
        if ProcessInfo.processInfo.arguments.contains("--test") {
            return .test
        } else {
            if let stored = _storedEnvironment {
                return stored
            } else {
                return .production
            }
        }
    }

    public static let test = Environment(baseURL: "http://localhost:9042",
                                         videosPath: "/videos.json",
                                         sessionsPath: "/contents.json",
                                         newsPath: "/news.json",
                                         liveVideosPath: "/videos_live.json")

    public static let production = Environment(baseURL: "https://api2017.wwdc.io",
                                               videosPath: "/videos.json",
                                               sessionsPath: "/contents.json",
                                               newsPath: "/news.json",
                                               liveVideosPath: "/videos_live.json")

}

extension Environment: Equatable {

    public static func ==(lhs: Environment, rhs: Environment) -> Bool {
        return lhs.baseURL == rhs.baseURL
            && lhs.videosPath == rhs.videosPath
            && lhs.sessionsPath == rhs.sessionsPath
            && lhs.newsPath == rhs.newsPath
            && lhs.liveVideosPath == rhs.liveVideosPath
    }
    
}
