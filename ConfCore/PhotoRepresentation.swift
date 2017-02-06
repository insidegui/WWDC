//
//  PhotoRepresentation.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Photo representations are assets for photos specifying widths and URLs for different photo sizes
class PhotoRepresentation: Object {

    /// The URL for the photo
    dynamic var remoteURL = ""
    
    /// The width of the photo
    dynamic var width = 0
    
    /// The photo object this representation is associated with
    let photo = LinkingObjects(fromType: Photo.self, property: "representations")
    
    override class func primaryKey() -> String? {
        return "remoteURL"
    }
    
}
