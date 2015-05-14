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
        
        struct transcript {
            static let font = "transcript.font"
            static let textColor = "transcript.textColor"
            static let bgColor = "transcript.bgColor"
        }
        
        struct VideosController {
            static let selectedItem = "VideosController.selectedItem"
            static let searchTerm = "VideosController.searchTerm"
            static let sidebarWidth = "VideosController.sidebarWidth"
        }
    }
    
    // default values if preferences were not set
    private struct DefaultValues {
        static let localVideoStoragePath = NSString.pathWithComponents([NSHomeDirectory(), "Library", "Application Support", "WWDC"])
        static let lastVideoWindowScale = CGFloat(100.0)
        
        struct transcript {
            static let font = NSFont(name: "Avenir Next", size: 16.0)!
            static let textColor = NSColor.blackColor()
            static let bgColor = NSColor.whiteColor()
        }
        
        struct VideosController {
            static let selectedItem = -1
            static let searchTerm = ""
            static let sidebarWidth = 260.0
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
    
    // the sidebar's width
    var sidebarWidth: CGFloat {
        set {
            defaults.setObject(NSNumber(double: Double(newValue)), forKey: Keys.VideosController.sidebarWidth)
        }
        get {
            if let width = defaults.objectForKey(Keys.VideosController.sidebarWidth) as? NSNumber {
                return CGFloat(width.doubleValue)
            } else {
                return CGFloat(DefaultValues.VideosController.sidebarWidth)
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
    
}