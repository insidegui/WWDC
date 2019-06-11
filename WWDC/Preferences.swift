//
//  Preferences.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import ThrowBack
import SwiftyJSON

extension Notification.Name {
    static let LocalVideoStoragePathPreferenceDidChange = Notification.Name("LocalVideoStoragePathPreferenceDidChange")
    static let RefreshPeriodicallyPreferenceDidChange = Notification.Name("RefreshPeriodicallyPreferenceDidChange")
    static let SkipBackAndForwardBy30SecondsPreferenceDidChange = Notification.Name("SkipBackAndForwardBy30SecondsPreferenceDidChange")
    static let SyncUserDataPreferencesDidChange = Notification.Name("SyncUserDataPreferencesDidChange")
    static let AutoDeletePreferenceDidChange = Notification.Name("AutoDeletePreferenceDidChange")
}

final class Preferences {

    static let shared: Preferences = Preferences()

    private let defaults = UserDefaults.standard

    /// The URL for the folder where downloaded videos will be saved
    var localVideoStorageURL: URL {
        get {
            return URL(fileURLWithPath: TBPreferences.shared.localVideoStoragePath)
        }
        set {
            TBPreferences.shared.localVideoStoragePath = newValue.path

            defaults.set(newValue.path, forKey: #function)

            defaults.synchronize()

            NotificationCenter.default.post(name: .LocalVideoStoragePathPreferenceDidChange, object: nil)
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

    var filtersState: JSON? {
        get {
            if let string = defaults.object(forKey: #function) as? String {
                return JSON(parseJSON: string)
            } else {
                return nil
            }
        }
        set {
            if let myString = newValue?.rawString() {
                defaults.set(myString, forKey: #function)
            }
        }
    }

    var showedAccountPromptAtStartup: Bool {
        get {
            return defaults.bool(forKey: #function)
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

    var skipBackAndForwardBy30Seconds: Bool {
        get {
            return defaults.bool(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)

            NotificationCenter.default.post(name: .SkipBackAndForwardBy30SecondsPreferenceDidChange, object: nil)
        }
    }

    var autoDeleteVideosWhenWatched: Bool {
        get {
            return defaults.bool(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)

            NotificationCenter.default.post(name: .AutoDeletePreferenceDidChange, object: nil)
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

}
