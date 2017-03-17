//
//  Track.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Tracks represent a specific are of interest (ex: "System Frameworks", "Graphics and Games")
public class Track: Object {
    
    /// The name of the track
    public dynamic var name = ""
    
    /// Dark theme color
    public dynamic var darkColor = ""
    
    /// Color for light backgrounds
    public dynamic var lightBackgroundColor = ""
    
    /// Color for light contexts
    public dynamic var lightColor = ""
    
    /// Theme title color
    public dynamic var titleColor = ""
    
    /// Sessions related to this track
    public let sessions = List<Session>()
    
    public override class func primaryKey() -> String? {
        return "name"
    }
    
    public static func make(name: String,
                     darkColor: String,
                     lightBackgroundColor: String,
                     lightColor: String,
                     titleColor: String) -> Track {
        let track = Track()
        
        track.name = name
        track.darkColor = darkColor
        track.lightBackgroundColor = lightBackgroundColor
        track.lightColor = lightColor
        track.titleColor = titleColor
        
        return track
    }
    
}
