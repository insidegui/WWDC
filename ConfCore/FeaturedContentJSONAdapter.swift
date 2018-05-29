//
//  FeaturedContentJSONAdapter.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON
import RealmSwift

private enum FeaturedContentKeys: String, JSONSubscriptType {
    case sessionId = "identifier"
    case essay, bookmarks

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class FeaturedContentJSONAdapter: Adapter {
    typealias InputType = JSON
    typealias OutputType = FeaturedContent

    func adapt(_ input: JSON) -> Result<FeaturedContent, AdapterError> {
        guard let sessionId = input[FeaturedContentKeys.sessionId].string else {
            return .error(.missingKey(FeaturedContentKeys.sessionId))
        }

        let content = FeaturedContent()

        content.sessionId = sessionId

        if let encodedEssay = input[FeaturedContentKeys.essay].string {
            content.essay = Data(base64Encoded: encodedEssay)
        }

        if let bookmarksJSON = input[FeaturedContentKeys.bookmarks].array,
            case .success(let bookmarks) = BookmarkJSONAdapter().adapt(bookmarksJSON) {
            content.bookmarks.append(objectsIn: bookmarks)
        }

        return .success(content)
    }
}
