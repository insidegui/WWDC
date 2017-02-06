//
//  SessionInstance.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// A session instance represents a specific occurence of a session, associated with a room and possibly a live stream asset
class SessionInstance: Object {
    
    /// The start date and time for this instance
    dynamic var startTime = Date.distantPast
    
    /// The end date and time for this instance
    dynamic var endTime = Date.distantPast
    
    /// When the live stream ends
    dynamic var liveStreamEndTime = Date.distantPast
    
    /// Whether this instance is live now or not
    dynamic var isStreamingLive = false
    
    /// The live stream asset for this instance
    var liveStreamAsset: SessionAsset?
    
    /// The live stream photo for this instance
    var liveStreamPhotoRep: PhotoRepresentation?
    
    /// The room where this session will be held
    let room = LinkingObjects(fromType: Room.self, property: "instances")
    
    /// The session this instance belongs to
    let session = LinkingObjects(fromType: Session.self, property: "instances")
    
}
