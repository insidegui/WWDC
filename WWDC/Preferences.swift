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
    
    private let defaults = NSUserDefaults.standardUserDefaults()
    private let nc = NSNotificationCenter.defaultCenter()
    
    // keys for NSUserDefault's dictionary
    private struct Keys {
        static let mainWindowFrame = "mainWindowFrame"
        static let localVideoStoragePath = "localVideoStoragePath"
        static let lastVideoWindowScale = "lastVideoWindowScale"
        static let autoplayLiveEvents = "autoplayLiveEvents"
        static let liveEventCheckInterval = "liveEventCheckInterval"
        static let userKnowsLiveEventThing = "userKnowsLiveEventThing"
        static let automaticRefreshEnabled = "automaticRefreshEnabled"
        
        struct transcript {
            static let font = "transcript.font"
            static let textColor = "transcript.textColor"
            static let bgColor = "transcript.bgColor"
        }
        
        struct VideosController {
            static let selectedItem = "VideosController.selectedItem"
            static let searchTerm = "VideosController.searchTerm"
            static let searchFilter = "VideosController.searchFilter"
            static let dividerPosition = "VideosController.dividerPosition"
        }
    }
    
    // default values if preferences were not set
    private struct DefaultValues {
        static let localVideoStoragePath = NSString.pathWithComponents([NSHomeDirectory(), "Library", "Application Support", "WWDC"])
        static let lastVideoWindowScale = CGFloat(100.0)
        static let autoplayLiveEvents = true
        static let liveEventCheckInterval = 15.0
        static let userKnowsLiveEventThing = false
        static let automaticRefreshEnabled = true
        static let automaticRefreshInterval = 60.0
        
        struct transcript {
            static let font = NSFont(name: "Avenir Next", size: 16.0)!
            static let textColor = NSColor.blackColor()
            static let bgColor = NSColor.whiteColor()
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
            defaults.setObject(NSStringFromRect(newValue), forKey: Keys.mainWindowFrame)
        }
        get {
            if let rectString = defaults.objectForKey(Keys.mainWindowFrame) as? String {
                return NSRectFromString(rectString)
            } else {
                return NSZeroRect
            }
        }
    }
    
    // the selected session on the list
    var selectedSession: Int {
        set {
            defaults.setObject(newValue, forKey: Keys.VideosController.selectedItem)
        }
        get {
            if let item = defaults.objectForKey(Keys.VideosController.selectedItem) as? Int {
                return item
            } else {
                return DefaultValues.VideosController.selectedItem
            }
        }
    }
    
    // the splitView's divider position
    var dividerPosition: CGFloat {
        set {
            defaults.setObject(NSNumber(double: Double(newValue)), forKey: Keys.VideosController.dividerPosition)
        }
        get {
            if let width = defaults.objectForKey(Keys.VideosController.dividerPosition) as? NSNumber {
                return CGFloat(width.doubleValue)
            } else {
                return CGFloat(DefaultValues.VideosController.dividerPosition)
            }
        }
    }
    
    // the search term
    var searchTerm: String {
        set {
            defaults.setObject(newValue, forKey: Keys.VideosController.searchTerm)
        }
        get {
            if let term = defaults.objectForKey(Keys.VideosController.searchTerm) as? String {
                return term
            } else {
                return DefaultValues.VideosController.searchTerm
            }
        }
    }

    // the search filter
    var searchFilter: SearchFilter {
        set {
            defaults.setInteger(newValue.rawValue, forKey: Keys.VideosController.searchFilter)
        }
        get {
            // No need for a default value because integerForKey returns 0 which maps to All if not found
            let rawFilter = defaults.integerForKey(Keys.VideosController.searchFilter)
            return SearchFilter(rawValue: rawFilter)!
        }
    }
    
    // where to save downloaded videos
    var localVideoStoragePath: String {
        set {
            defaults.setObject(newValue, forKey: Keys.localVideoStoragePath)
            nc.postNotificationName(LocalVideoStoragePathPreferenceChangedNotification, object: newValue)
        }
        get {
            if let path = defaults.objectForKey(Keys.localVideoStoragePath) as? String {
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
            let data = NSKeyedArchiver.archivedDataWithRootObject(newValue)
            defaults.setObject(data, forKey: Keys.transcript.font)
            nc.postNotificationName(TranscriptPreferencesChangedNotification, object: nil)
        }
        get {
            if let fontData = defaults.dataForKey(Keys.transcript.font) {
                if let font = NSKeyedUnarchiver.unarchiveObjectWithData(fontData) as? NSFont {
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
            let colorData = NSKeyedArchiver.archivedDataWithRootObject(newValue)
            defaults.setObject(colorData, forKey: Keys.transcript.textColor)
            nc.postNotificationName(TranscriptPreferencesChangedNotification, object: nil)
        }
        get {
            if let colorData = defaults.dataForKey(Keys.transcript.textColor) {
                if let color = NSKeyedUnarchiver.unarchiveObjectWithData(colorData) as? NSColor {
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
            let colorData = NSKeyedArchiver.archivedDataWithRootObject(newValue)
            defaults.setObject(colorData, forKey: Keys.transcript.bgColor)
            nc.postNotificationName(TranscriptPreferencesChangedNotification, object: nil)
        }
        get {
            if let colorData = defaults.dataForKey(Keys.transcript.bgColor) {
                if let color = NSKeyedUnarchiver.unarchiveObjectWithData(colorData) as? NSColor {
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
            if let scale = defaults.objectForKey(Keys.lastVideoWindowScale) as? NSNumber {
                return CGFloat(scale.doubleValue)
            } else {
                return DefaultValues.lastVideoWindowScale
            }
        }
        set {
            defaults.setObject(NSNumber(double: Double(newValue)), forKey: Keys.lastVideoWindowScale)
        }
    }
    
    // play live events automatically or not
    // TODO: expose this preference to the user
    var autoplayLiveEvents: Bool {
        get {
            if let object = defaults.objectForKey(Keys.autoplayLiveEvents) as? NSNumber {
                return object.boolValue
            } else {
                return DefaultValues.autoplayLiveEvents
            }
        }
        set {
            defaults.setObject(NSNumber(bool: newValue), forKey: Keys.autoplayLiveEvents)
        }
    }
    
    // how often to check for live events (in seconds)
    var liveEventCheckInterval: Double {
        get {
            if let object = defaults.objectForKey(Keys.liveEventCheckInterval) as? NSNumber {
                return object.doubleValue
            } else {
                return DefaultValues.liveEventCheckInterval
            }
        }
        set {
            defaults.setObject(NSNumber(double: newValue), forKey: Keys.liveEventCheckInterval)
        }
    }
    
    // user was informed about the possibility to watch the live keynote here :)
    var userKnowsLiveEventThing: Bool {
        get {
            if let object = defaults.objectForKey(Keys.userKnowsLiveEventThing) as? NSNumber {
                return object.boolValue
            } else {
                return DefaultValues.userKnowsLiveEventThing
            }
        }
        set {
            defaults.setObject(NSNumber(bool: newValue), forKey: Keys.userKnowsLiveEventThing)
        }
    }
    
    // periodically refresh the list of sessions
    var automaticRefreshEnabled: Bool {
        get {
            if let object = defaults.objectForKey(Keys.automaticRefreshEnabled) as? NSNumber {
                return object.boolValue
            } else {
                return DefaultValues.automaticRefreshEnabled
            }
        }
        set {
            defaults.setObject(NSNumber(bool: newValue), forKey: Keys.automaticRefreshEnabled)
            nc.postNotificationName(AutomaticRefreshPreferenceChangedNotification, object: nil)
        }
    }
    
    var automaticRefreshInterval: Double {
        get {
            return DefaultValues.automaticRefreshInterval
        }
    }
    
}