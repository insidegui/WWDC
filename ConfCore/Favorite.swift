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
public class Favorite: Object {

    /// Unique identifier
    public dynamic var identifier = UUID().uuidString
    
    /// When the favorite was created
    public dynamic var createdAt = Date()
    
    /// The session this favorite is associated with
    public let session = LinkingObjects(fromType: Session.self, property: "favorites")
    
    public override class func primaryKey() -> String? {
        return "identifier"
    }
    
}
