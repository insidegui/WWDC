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
public class Keyword: Object, Decodable {

    /// The keyword
    @objc public dynamic var name = ""

    public override class func primaryKey() -> String? {
        return "name"
    }

    // MARK: Decodable

    public convenience required init(from decoder: Decoder) throws {
        self.init()

        name = try decoder.singleValueContainer().decode()
    }

}
