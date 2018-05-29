//
//  FeaturedAuthor.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

/// Specifies an author for a curated playlist
public class FeaturedAuthor: Object {

    @objc public dynamic var name: String = ""
    @objc public dynamic var bio: String = ""
    @objc public dynamic var avatar: String = ""
    @objc public dynamic var url: String = ""

    public override static func primaryKey() -> String? {
        return "name"
    }

}
