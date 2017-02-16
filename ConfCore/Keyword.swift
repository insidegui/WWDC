//
//  Keyword.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Keywords used when searching sessions
class Keyword: Object {

    /// The keyword
    dynamic var name = ""
    
    /// Sessions containing this keyword
    let sessionInstances = LinkingObjects(fromType: SessionInstance.self, property: "keywords")
    
    override class func primaryKey() -> String? {
        return "name"
    }
    
}
