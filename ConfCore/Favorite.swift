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
public final class Favorite: Object, HasCloudKitFields, SoftDeletable {

    /// CloudKit system data
    @objc public dynamic var ckFields = Data()

    /// Unique identifier
    @objc public dynamic var identifier = UUID().uuidString

    /// When the favorite was created
    @objc public dynamic var createdAt = Date()

    /// Soft delete (for syncing)
    @objc public dynamic var isDeleted: Bool = false

    /// The session this favorite is associated with
    public let session = LinkingObjects(fromType: Session.self, property: "favorites")

    public override class func primaryKey() -> String? {
        return "identifier"
    }

}
