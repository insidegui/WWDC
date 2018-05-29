//
//  BookmarkJSONAdapter.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum BookmarkKeys: String, JSONSubscriptType {
    case body, attributedBody, timecode, duration

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class BookmarkJSONAdapter: Adapter {
    typealias InputType = JSON
    typealias OutputType = Bookmark

    func adapt(_ input: JSON) -> Result<Bookmark, AdapterError> {
        guard let body = input[BookmarkKeys.body].string else {
            return .error(.missingKey(BookmarkKeys.body))
        }

        guard let timecode = input[BookmarkKeys.timecode].double else {
            return .error(.missingKey(BookmarkKeys.timecode))
        }

        guard let duration = input[BookmarkKeys.duration].double else {
            return .error(.missingKey(BookmarkKeys.duration))
        }

        let bookmark = Bookmark()

        if let attributedBody = input[BookmarkKeys.attributedBody].string,
            let attributedBodyData = Data(base64Encoded: attributedBody) {
            bookmark.attributedBody = attributedBodyData
        }

        bookmark.body = body
        bookmark.timecode = timecode
        bookmark.duration = duration
        bookmark.isShared = true

        return .success(bookmark)
    }
}
