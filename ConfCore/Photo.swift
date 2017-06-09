//
//  Photo.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Photos are pictures associated with news items
public class Photo: Object {

    /// Unique identifier
    public dynamic var identifier = ""

    /// The photo's aspect ratio
    public dynamic var aspectRatio = 0.0

    /// The news item this photo is associated with
    public let newsItem = LinkingObjects(fromType: NewsItem.self, property: "photos")

    /// The representations this photo has
    public let representations = List<PhotoRepresentation>()

    public override class func primaryKey() -> String? {
        return "identifier"
    }

}
