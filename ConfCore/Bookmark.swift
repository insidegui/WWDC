//
//  Bookmark.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Bookmarks are notes the user can create while watching session videos to reference later, bookmarks can be private or shared with other users
class Bookmark: Object {

    /// Unique identifier
    dynamic var identifier = ""
    
    /// Date/time the bookmark was created
    dynamic var createdAt = Date.distantPast
    
    /// Date/time the bookmark was last modified
    dynamic var modifiedAt = Date.distantPast
    
    /// Whether other users can see this bookmark or only the user who created it can
    dynamic var isShared = false
    
    /// Plain text body
    dynamic var body = ""
    
    /// Formatted text body
    dynamic var attributedBody = Data()
    
    /// Time in the video this bookmark was created
    dynamic var timecode = 0.0
    
    /// Snapshot from the video at the time the bookmark was created
    dynamic var snapshot = Data()
    
    /// What the presenter was saying close to where the bookmark was created
    dynamic var annotation: TranscriptAnnotation?
    
    /// The session this bookmark is associated with
    let session = LinkingObjects(fromType: Session.self, property: "bookmarks")
    
    override class func primaryKey() -> String? {
        return "identifier"
    }
    
}
