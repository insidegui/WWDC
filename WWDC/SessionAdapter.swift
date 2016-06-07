//
//  SessionAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

class SessionAdapter: JSONAdapter {
    
    typealias ModelType = Session
    
    static func adapt(json: JSON) -> ModelType {
        let session = Session()
        
        session.id = json["id"].intValue
        session.year = json["year"].intValue
        session.uniqueId = "#" + String(session.year) + "-" + String(session.id)
        session.title = json["title"].stringValue
        session.summary = json["description"].stringValue
        session.date = json["date"].stringValue
        session.track = json["track"].stringValue
        session.videoURL = json["url"].stringValue
        session.hdVideoURL = json["download_hd"].stringValue
        session.slidesURL = json["slides"].stringValue
        session.track = json["track"].stringValue
        
        if let focus = json["focus"].arrayObject as? [String] {
            session.focus = focus.joinWithSeparator(", ")
        }
        
        if let images = json["images"].dictionaryObject as? [String: String] {
            session.shelfImageURL = images["shelf"] ?? ""
        }
        
        return session
    }
    
}