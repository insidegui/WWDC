//
//  Preferences.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import ConfCore

extension Notification.Name {
    static let LocalVideoStoragePathPreferenceDidChange = Notification.Name("LocalVideoStoragePathPreferenceDidChange")
    static let RefreshPeriodicallyPreferenceDidChange = Notification.Name("RefreshPeriodicallyPreferenceDidChange")
    static let SkipBackAndForwardBy30SecondsPreferenceDidChange = Notification.Name("SkipBackAndForwardBy30SecondsPreferenceDidChange")
    static let SyncUserDataPreferencesDidChange = Notification.Name("SyncUserDataPreferencesDidChange")
    static let PreferredTranscriptLanguageDidChange = Notification.Name("PreferredTranscriptLanguageDidChange")
}

final class Preferences {

    static let shared: Preferences = Preferences()

    private let defaults = UserDefaults.standard

    private static let defaultLocalVideoStoragePath = NSString.path(withComponents: [NSHomeDirectory(), "Library", "Application Support", "WWDC"])

    init() {
        defaults.register(defaults: [
            "localVideoStoragePath": Self.defaultLocalVideoStoragePath,
            "includeAppBannerInSharedClips": true
        ])
    }

    /// The URL for the folder where downloaded videos will be saved
    var localVideoStorageURL: URL {
        set { localVideoStoragePath = newValue.path }
        get { URL(fileURLWithPath: localVideoStoragePath) }
    }

    private var localVideoStoragePath: String {
        set {
            defaults.set(newValue, forKey: #function)
        }
        get {
            if let path = defaults.object(forKey: #function) as? String {
                return path
            } else {
                return Self.defaultLocalVideoStoragePath
            }
        }
    }

    var activeTab: MainWindowTab {
        get {
            let rawValue = defaults.integer(forKey: #function)

            return MainWindowTab(rawValue: rawValue) ?? .schedule
        }
        set {
            defaults.set(newValue.rawValue, forKey: #function)
        }
    }

    var selectedScheduleItemIdentifier: String? {
        get {
            return defaults.object(forKey: #function) as? String
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }

    var selectedVideoItemIdentifier: String? {
        get {
            return defaults.object(forKey: #function) as? String
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }

    var filtersState: String? {
        get {
            defaults.object(forKey: #function) as? String
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }

    var userOptedOutOfCrashReporting: Bool {
        get {
            return defaults.bool(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }

    var searchInTranscripts: Bool {
        get {
            return defaults.bool(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }

    var searchInBookmarks: Bool {
        get {
            return defaults.bool(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }

    var refreshPeriodically: Bool {
        get {
            return defaults.bool(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)

            NotificationCenter.default.post(name: .RefreshPeriodicallyPreferenceDidChange, object: nil)
        }
    }

    var skipIntro: Bool {
        get { defaults.bool(forKey: #function) }
        set { defaults.set(newValue, forKey: #function) }
    }

    var includeAppBannerInSharedClips: Bool {
        get { defaults.bool(forKey: #function) }
        set { defaults.set(newValue, forKey: #function) }
    }

    var skipBackAndForwardBy30Seconds: Bool {
        get {
            return defaults.bool(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)

            NotificationCenter.default.post(name: .SkipBackAndForwardBy30SecondsPreferenceDidChange, object: nil)
        }
    }

    var syncUserData: Bool {
        get {
            return defaults.bool(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)

            NotificationCenter.default.post(name: .SyncUserDataPreferencesDidChange, object: nil)
        }
    }

    public static let fallbackTranscriptLanguageCode = "en"

    var transcriptLanguageCode: String {
        get { defaults.string(forKey: #function) ?? ConfigResponse.fallbackFeedLanguage }
        set {
            let notify = newValue != transcriptLanguageCode

            defaults.set(newValue, forKey: #function)

            guard notify else { return }

            NotificationCenter.default.post(name: .PreferredTranscriptLanguageDidChange, object: newValue)
        }
    }

}
