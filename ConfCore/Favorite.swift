//
//  Favorite.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Defines the user action of adding a session as favorite
class Favorite: Object {

    /// Unique identifier
    dynamic var identifier = ""
    
    /// When the favorite was created
    dynamic var createdAt = Date.distantPast
    
    /// The session this favorite is associated with
    let session = LinkingObjects(fromType: Session.self, property: "favorites")
    
    override class func primaryKey() -> String? {
        return "identifier"
    }
    
}
