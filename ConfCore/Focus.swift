//
//  Focus.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Focuses are basically platform names (ex: "macOS", "iOS")
public class Focus: Object {

    /// The name of the focus area
    public dynamic var name = ""

    /// Sessions containing this focus
    public let sessions = LinkingObjects(fromType: Session.self, property: "focuses")

    public override class func primaryKey() -> String? {
        return "name"
    }

    public override static func indexedProperties() -> [String] {
        return [
            "name"
        ]
    }

}
