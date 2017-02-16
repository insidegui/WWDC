//
//  Session.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Specifies a session in an event, with its related keywords, assets, instances, user favorites and user bookmarks
class Session: Object {

    /// Unique identifier
    dynamic var identifier = ""
    
    /// Session number
    dynamic var number = ""
    
    /// Title
    dynamic var title = ""
    
    /// Description
    dynamic var summary = ""
    
    /// Event identifier (only using during JSON adapting)
    dynamic var eventIdentifier = ""
    
    /// Track name (only using during JSON adapting)
    dynamic var trackName = ""
    
    /// The session's focuses
    let focuses = List<Focus>()
    
    /// The session's assets (videos, slides, links)
    let assets = List<SessionAsset>()
    
    /// Session favorite
    let favorites = List<Favorite>()
    
    /// Session bookmarks
    let bookmarks = List<Bookmark>()
    
    /// Transcript for the session
    dynamic var transcript: Transcript?
    
    /// The session's track
    let track = LinkingObjects(fromType: Track.self, property: "sessions")
    
    /// The event this session belongs to
    let event = LinkingObjects(fromType: Event.self, property: "sessions")
    
    /// Instances of this session
    let instances = LinkingObjects(fromType: SessionInstance.self, property: "session")
    
    override static func primaryKey() -> String? {
        return "identifier"
    }
    
    override static func ignoredProperties() -> [String] {
        return ["trackName", "eventIdentifier"]
    }
    
}
