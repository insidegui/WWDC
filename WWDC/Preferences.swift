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
    static let SkipBackAndForwardDurationPreferenceDidChange = Notification.Name("SkipBackAndForwardDurationPreferenceDidChange")
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
            "includeAppBannerInSharedClips": true,
            "preferHLSVideoDownload": false
        ])
    }

    /// The URL for the folder where downloaded videos will be saved
    var localVideoStorageURL: URL {
        get { URL(fileURLWithPath: localVideoStoragePath) }
        set { localVideoStoragePath = newValue.path }
    }

    /// Prioritizes downloading the HLS version of the video if available.
    /// The default is `true`. When `false`, downloads the HD variant (mp4) instead.
    var preferHLSVideoDownload: Bool {
        get { defaults.bool(forKey: #function) }
        set { defaults.set(newValue, forKey: #function) }
    }

    /// Directory where in-flight download metadata is kept.
    var downloadMetadataStorageURL: URL {
        let baseURL = URL(fileURLWithPath: Self.defaultLocalVideoStoragePath)
        let dirURL = baseURL.appendingPathComponent(".DownloadMetadata")
        if !FileManager.default.fileExists(atPath: dirURL.path) {
            do {
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            } catch {
                assertionFailure("Error creating download metadata storage directory: \(error)")
                return URL(fileURLWithPath: NSTemporaryDirectory())
            }
        }
        return dirURL
    }

    private var localVideoStoragePath: String {
        get {
            if let path = defaults.object(forKey: #function) as? String {
                return path
            } else {
                return Self.defaultLocalVideoStoragePath
            }
        }
        set {
            defaults.set(newValue, forKey: #function)
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

    var skipBackAndForwardDuration: BackForwardSkipDuration {
        get {
            // Migrate from legacy 30/15 preference if needed.
            let migrationKey = "backForwardSkipMigrated"
            if !defaults.bool(forKey: migrationKey) {
                let duration: BackForwardSkipDuration = defaults.bool(forKey: "skipBackAndForwardBy30Seconds") ? .thirtySeconds : .fifteenSeconds
                defaults.set(duration.rawValue, forKey: #function)

                defaults.set(true, forKey: migrationKey)
            }
            return BackForwardSkipDuration(seconds: defaults.double(forKey: #function))
        }
        set {
            defaults.set(newValue.rawValue, forKey: #function)
            
            NotificationCenter.default.post(name: .SkipBackAndForwardDurationPreferenceDidChange, object: nil)
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
