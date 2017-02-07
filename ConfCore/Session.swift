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
    
    /// Type of session (0 = regular session, 1 = lab, 2 = video-only session)
    dynamic var sessionType = 0
    
    /// Title
    dynamic var title = ""
    
    /// Description
    dynamic var summary = ""
    
    /// Keywords associated with this session
    let keywords = List<Keyword>()
    
    /// The session's assets (videos, slides, links)
    let assets = List<SessionAsset>()
    
    /// The session's instances (when and where the session will occur)
    let instances = List<SessionInstance>()
    
    /// Session favorite
    let favorites = List<Favorite>()
    
    /// Session bookmarks
    let bookmarks = List<Bookmark>()
    
    /// Transcript for the session
    dynamic var transcript: Transcript?
    
    /// The session's focuses
    let focuses = LinkingObjects(fromType: Focus.self, property: "sessions")
    
    /// The session's track
    let track = LinkingObjects(fromType: Track.self, property: "sessions")
    
    /// The event this session belongs to
    let event = LinkingObjects(fromType: Event.self, property: "sessions")
    
}
