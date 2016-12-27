//
//  Preferences.swift
//  WWDC
//
//  Created by Guilherme Rambo on 01/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

let LocalVideoStoragePathPreferenceChangedNotification = "LocalVideoStoragePathPreferenceChangedNotification"
let TranscriptPreferencesChangedNotification = "TranscriptPreferencesChangedNotification"
let AutomaticRefreshPreferenceChangedNotification = "AutomaticRefreshPreferenceChangedNotification"

private let _SharedPreferences = Preferences();

class Preferences {
    
    class func SharedPreferences() -> Preferences {
        return _SharedPreferences
    }
    
    fileprivate let defaults = UserDefaults.standard
    fileprivate let nc = NotificationCenter.default
    
    // keys for NSUserDefault's dictionary
    fileprivate struct Keys {
        static let mainWindowFrame = "mainWindowFrame"
        static let localVideoStoragePath = "localVideoStoragePath"
        static let lastVideoWindowScale = "lastVideoWindowScale"
        static let autoplayLiveEvents = "autoplayLiveEvents"
        static let liveEventCheckInterval = "liveEventCheckInterval"
        static let userKnowsLiveEventThing = "userKnowsLiveEventThing"
        static let tvTechTalksAlerted = "tvTechTalksAlerted"
        static let automaticRefreshEnabled = "automaticRefreshEnabled"
		static let floatOnTopEnabled = "floatOnTopEnabled"
        static let automaticRefreshSuggestionPresentedAt = "automaticRefreshSuggestionPresentedAt"
        
        struct transcript {
            static let font = "transcript.font"
            static let textColor = "transcript.textColor"
            static let bgColor = "transcript.bgColor"
        }
        
        struct VideosController {
            static let selectedItem = "VideosController.selectedItem"
            static let searchTerm = "VideosController.searchTerm"
            static let dividerPosition = "VideosController.dividerPosition"
        }
    }
    
    // default values if preferences were not set
    fileprivate struct DefaultValues {
        static let localVideoStoragePath = NSString.path(withComponents: [NSHomeDirectory(), "Library", "Application Support", "WWDC"])
        static let lastVideoWindowScale = CGFloat(100.0)
        static let autoplayLiveEvents = true
        static let liveEventCheckInterval = 15.0
        static let userKnowsLiveEventThing = false
        static let tvTechTalksAlerted = false
        static let automaticRefreshEnabled = true
        static let automaticRefreshIntervalOnWWDCWeek = 900.0
        static let automaticRefreshIntervalRegular = 3600.0
        static let floatOnTopEnabled = false
        static let automaticRefreshSuggestionPresentedAt = Date.distantPast
        
        struct transcript {
            static let font = NSFont(name: "Avenir Next", size: 16.0)!
            static let textColor = NSColor.black
            static let bgColor = NSColor.white
        }
        
        struct VideosController {
            static let selectedItem = -1
            static let searchTerm = ""
            static let dividerPosition = 260.0
        }
    }
    
    // the main window's frame
    var mainWindowFrame: NSRect {
        set {
            defaults.set(NSStringFromRect(newValue), forKey: Keys.mainWindowFrame)
        }
        get {
            if let rectString = defaults.object(forKey: Keys.mainWindowFrame) as? String {
                return NSRectFromString(rectString)
            } else {
                return NSZeroRect
            }
        }
    }
    
    // the selected session on the list
    var selectedSession: Int {
        set {
            defaults.set(newValue, forKey: Keys.VideosController.selectedItem)
        }
        get {
            if let item = defaults.object(forKey: Keys.VideosController.selectedItem) as? Int {
                return item
            } else {
                return DefaultValues.VideosController.selectedItem
            }
        }
    }
    
    // the splitView's divider position
    var dividerPosition: CGFloat {
        set {
            defaults.set(NSNumber(value: Double(newValue) as Double), forKey: Keys.VideosController.dividerPosition)
        }
        get {
            if let width = defaults.object(forKey: Keys.VideosController.dividerPosition) as? NSNumber {
                return CGFloat(width.doubleValue)
            } else {
                return CGFloat(DefaultValues.VideosController.dividerPosition)
            }
        }
    }
    
    // the search term
    var searchTerm: String {
        set {
            defaults.set(newValue, forKey: Keys.VideosController.searchTerm)
        }
        get {
            if let term = defaults.object(forKey: Keys.VideosController.searchTerm) as? String {
                return term
            } else {
                return DefaultValues.VideosController.searchTerm
            }
        }
    }
    
    // where to save downloaded videos
    var localVideoStoragePath: String {
        set {
            defaults.set(newValue, forKey: Keys.localVideoStoragePath)
            nc.post(name: Notification.Name(rawValue: LocalVideoStoragePathPreferenceChangedNotification), object: newValue)
        }
        get {
            if let path = defaults.object(forKey: Keys.localVideoStoragePath) as? String {
                return path
            } else {
                return DefaultValues.localVideoStoragePath
            }
        }
    }
    
    // the transcript font
    var transcriptFont: NSFont {
        set {
            // NSFont can't be put into NSUserDefaults directly, so we archive It and store as a NSData blob
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            defaults.set(data, forKey: Keys.transcript.font)
            nc.post(name: Notification.Name(rawValue: TranscriptPreferencesChangedNotification), object: nil)
        }
        get {
            if let fontData = defaults.data(forKey: Keys.transcript.font) {
                if let font = NSKeyedUnarchiver.unarchiveObject(with: fontData) as? NSFont {
                    return font
                } else {
                    return DefaultValues.transcript.font
                }
            } else {
                return DefaultValues.transcript.font
            }
        }
    }
    
    // the transcript's text color
    var transcriptTextColor: NSColor {
        // NSColor can't be put into NSUserDefaults directly, so we archive It and store as a NSData blob
        set {
            let colorData = NSKeyedArchiver.archivedData(withRootObject: newValue)
            defaults.set(colorData, forKey: Keys.transcript.textColor)
            nc.post(name: Notification.Name(rawValue: TranscriptPreferencesChangedNotification), object: nil)
        }
        get {
            if let colorData = defaults.data(forKey: Keys.transcript.textColor) {
                if let color = NSKeyedUnarchiver.unarchiveObject(with: colorData) as? NSColor {
                    return color
                } else {
                    return DefaultValues.transcript.textColor
                }
            } else {
                return DefaultValues.transcript.textColor
            }
        }
    }
    
    // the transcript's background color
    var transcriptBgColor: NSColor {
        // NSColor can't be put into NSUserDefaults directly, so we archive It and store as a NSData blob
        set {
            let colorData = NSKeyedArchiver.archivedData(withRootObject: newValue)
            defaults.set(colorData, forKey: Keys.transcript.bgColor)
            nc.post(name: Notification.Name(rawValue: TranscriptPreferencesChangedNotification), object: nil)
        }
        get {
            if let colorData = defaults.data(forKey: Keys.transcript.bgColor) {
                if let color = NSKeyedUnarchiver.unarchiveObject(with: colorData) as? NSColor {
                    return color
                } else {
                    return DefaultValues.transcript.bgColor
                }
            } else {
                return DefaultValues.transcript.bgColor
            }
        }
    }
    
    // the last scale selected for the video window
    var lastVideoWindowScale: CGFloat {
        get {
            if let scale = defaults.object(forKey: Keys.lastVideoWindowScale) as? NSNumber {
                return CGFloat(scale.doubleValue)
            } else {
                return DefaultValues.lastVideoWindowScale
            }
        }
        set {
            defaults.set(NSNumber(value: Double(newValue) as Double), forKey: Keys.lastVideoWindowScale)
        }
    }
    
    // play live events automatically or not
    // TODO: expose this preference to the user
    var autoplayLiveEvents: Bool {
        get {
            if let object = defaults.object(forKey: Keys.autoplayLiveEvents) as? NSNumber {
                return object.boolValue
            } else {
                return DefaultValues.autoplayLiveEvents
            }
        }
        set {
            defaults.set(NSNumber(value: newValue as Bool), forKey: Keys.autoplayLiveEvents)
        }
    }
    
    // how often to check for live events (in seconds)
    var liveEventCheckInterval: Double {
        get {
            if let object = defaults.object(forKey: Keys.liveEventCheckInterval) as? NSNumber {
                return object.doubleValue
            } else {
                return DefaultValues.liveEventCheckInterval
            }
        }
        set {
            defaults.set(NSNumber(value: newValue as Double), forKey: Keys.liveEventCheckInterval)
        }
    }
    
    // user was informed about the possibility to watch the live keynote here :)
    var userKnowsLiveEventThing: Bool {
        get {
            if let object = defaults.object(forKey: Keys.userKnowsLiveEventThing) as? NSNumber {
                return object.boolValue
            } else {
                return DefaultValues.userKnowsLiveEventThing
            }
        }
        set {
            defaults.set(NSNumber(value: newValue as Bool), forKey: Keys.userKnowsLiveEventThing)
        }
    }
    
    // user was informed about the possibility to watch the 2016 Apple TV Tech Talks
    var tvTechTalksAlerted: Bool {
        get {
            if let object = defaults.object(forKey: Keys.tvTechTalksAlerted) as? NSNumber {
                return object.boolValue
            } else {
                return DefaultValues.tvTechTalksAlerted
            }
        }
        set {
            defaults.set(NSNumber(value: newValue as Bool), forKey: Keys.tvTechTalksAlerted)
        }
    }
    
    // periodically refresh the list of sessions
    var automaticRefreshEnabled: Bool {
        get {
            if let object = defaults.object(forKey: Keys.automaticRefreshEnabled) as? NSNumber {
                return object.boolValue
            } else {
                return DefaultValues.automaticRefreshEnabled
            }
        }
        set {
            defaults.set(NSNumber(value: newValue as Bool), forKey: Keys.automaticRefreshEnabled)
            nc.post(name: Notification.Name(rawValue: AutomaticRefreshPreferenceChangedNotification), object: nil)
        }
    }
    
    var automaticRefreshInterval: Double {
        get {
            return WWDCDatabase.sharedDatabase.config.isWWDCWeek ? DefaultValues.automaticRefreshIntervalOnWWDCWeek : DefaultValues.automaticRefreshIntervalRegular
        }
    }

	var floatOnTopEnabled: Bool {
		get {
			if let object = defaults.object(forKey: Keys.floatOnTopEnabled) as? NSNumber {
				return object.boolValue
			} else {
				return DefaultValues.floatOnTopEnabled
			}
		}
		set {
			defaults.set(NSNumber(value: newValue as Bool), forKey: Keys.floatOnTopEnabled)
		}
	}
    
    var automaticRefreshSuggestionPresentedAt: Date? {
        get {
            if let object = defaults.object(forKey: Keys.automaticRefreshSuggestionPresentedAt) as? Date {
                return object
            } else {
                return DefaultValues.automaticRefreshSuggestionPresentedAt
            }
        }
        set {
            defaults.set(newValue, forKey: Keys.automaticRefreshSuggestionPresentedAt)
        }
    }

}
