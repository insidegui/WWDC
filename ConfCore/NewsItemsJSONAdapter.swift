//
//  NewsItemsJSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 16/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum NewsItemKeys: String, JSONSubscriptType {
    case id, title, body, timestamp, visibility, photos, type
    
    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class NewsItemsJSONAdapter: Adapter {
    
    typealias InputType = JSON
    typealias OutputType = NewsItem
    
    func adapt(_ input: JSON) -> Result<NewsItem, AdapterError> {
        if let type = input[NewsItemKeys.type].string {
            guard type != "pass" else { return .error(.unsupported) }
        }
        
        guard let id = input[NewsItemKeys.id].string else {
            return .error(.missingKey(NewsItemKeys.id))
        }
        
        guard let title = input[NewsItemKeys.title].string else {
            return .error(.missingKey(NewsItemKeys.title))
        }
        
        guard let timestamp = input[NewsItemKeys.timestamp].double else {
            return .error(.missingKey(NewsItemKeys.timestamp))
        }
        
        let visibility = input[NewsItemKeys.visibility].stringValue
        
        let item = NewsItem()
        
        if let photosJson = input[NewsItemKeys.photos].array {
            if case .success(let photos) = PhotosJSONAdapter().adapt(photosJson) {
                item.photos.append(objectsIn: photos)
            }
        }
        
        item.identifier = id
        item.title = title
        item.body = input[NewsItemKeys.body].stringValue
        item.visibility = visibility
        item.date = Date(timeIntervalSince1970: timestamp)
        item.newsType = item.photos.count > 0 ? NewsType.gallery.rawValue : NewsType.news.rawValue
        
        return .success(item)
    }
    
}

