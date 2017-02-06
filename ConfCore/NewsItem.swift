//
//  NewsItem.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// NewsItem can be a simple news text or a photo gallery
class NewsItem: Object {

    /// Unique identifier
    dynamic var identifier = ""
    
    /// The type of news (0 = regular news, 2 = photo gallery)
    dynamic var newsType = 0
    
    /// The location of the news (seems to always be zero)
    dynamic var location = 0
    
    /// The condition that must be true so the user can see this item (used to limit some items to only attendees)
    dynamic var visibility = ""
    
    /// When this news item got published
    dynamic var date = Date.distantPast
    
    /// Title
    dynamic var title = ""
    
    /// Text
    dynamic var body = ""
    
    /// Photos for this news item, only present when `newsType == 2`
    let photos = List<Photo>()
    
    override class func primaryKey() -> String? {
        return "identifier"
    }
    
}
