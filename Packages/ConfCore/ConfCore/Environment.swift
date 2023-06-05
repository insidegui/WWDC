//
//  Environment.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import OSLog

public extension Notification.Name {
    static let WWDCEnvironmentDidChange = Notification.Name("WWDCEnvironmentDidChange")
}

public struct Environment: Equatable {

    public let baseURL: String
    public let configPath: String
    public let sessionsPath: String
    public let newsPath: String
    public let liveVideosPath: String
    public let featuredSectionsPath: String

    public init(baseURL: String,
                configPath: String,
                sessionsPath: String,
                newsPath: String,
                liveVideosPath: String,
                featuredSectionsPath: String) {
        self.baseURL = baseURL
        self.configPath = configPath
        self.sessionsPath = sessionsPath
        self.newsPath = newsPath
        self.liveVideosPath = liveVideosPath
        self.featuredSectionsPath = featuredSectionsPath
    }

    public static func setCurrent(_ environment: Environment) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let shouldNotify = (environment != Environment.current)

        _storedEnvironment = environment

        UserDefaults.standard.set(environment.baseURL, forKey: _storedEnvDefaultsKey)

        if shouldNotify {
            DispatchQueue.main.async {
                log.info("Environment base URL: \(environment.baseURL)")

                NotificationCenter.default.post(name: .WWDCEnvironmentDidChange, object: environment)
            }
        }
    }

}

private let _storedEnvDefaultsKey = "_confCoreEnvironmentBaseURL"

private var _storedEnvironment: Environment? = Environment.readFromDefaults()

extension Environment {

    static func readFromDefaults() -> Environment? {
        guard let baseURL = UserDefaults.standard.object(forKey: _storedEnvDefaultsKey) as? String else { return nil }

        return Environment(
            baseURL: baseURL,
            configPath: "/config.json",
            sessionsPath: "/sessions.json",
            newsPath: "/news.json",
            liveVideosPath: "/videos_live.json",
            featuredSectionsPath: "/explore.json"
        )
    }

    public static var current: Environment {
        #if DEBUG
        if let baseURL = UserDefaults.standard.string(forKey: "WWDCEnvironmentBaseURL") {
            return Environment(baseURL: baseURL,
                               configPath: "/config.json",
                               sessionsPath: "/contents.json",
                               newsPath: "/news.json",
                               liveVideosPath: "/videos_live.json",
                               featuredSectionsPath: "/explore.json")
        }
        #endif
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
                                         configPath: "/config.json",
                                         sessionsPath: "/contents.json",
                                         newsPath: "/news.json",
                                         liveVideosPath: "/videos_live.json",
                                         featuredSectionsPath: "/explore.json")

    public static let production = Environment(baseURL: "https://api2021.wwdc.io",
                                               configPath: "/config.json",
                                               sessionsPath: "/contents.json",
                                               newsPath: "/news.json",
                                               liveVideosPath: "/videos_live.json",
                                               featuredSectionsPath: "/explore.json")

}

extension Environment: Logging {
    public static let log = makeLogger()
}
