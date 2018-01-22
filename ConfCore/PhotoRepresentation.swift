//
//  PhotoRepresentation.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

public enum PhotoRepresentationSize: Int {
    case mini = 256
    case small = 512
    case medium = 1024
    case large = 2048

    static let all: [PhotoRepresentationSize] = [
        .mini,
        .small,
        .medium,
        .large
    ]
}

/// Photo representations are assets for photos specifying widths and URLs for different photo sizes
public class PhotoRepresentation: Object {

    /// The path for the photo
    @objc public dynamic var remotePath = ""

    /// The width of the photo
    @objc public dynamic var width = 0

    /// The photo object this representation is associated with
    public let photo = LinkingObjects(fromType: Photo.self, property: "representations")

    public override class func primaryKey() -> String? {
        return "remotePath"
    }

}
