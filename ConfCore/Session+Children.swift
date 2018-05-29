//
//  Session+Children.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 25/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

extension Session {

    func addChild(object: Object) {
        if let favorite = object as? Favorite {
            guard !favorites.contains(favorite) else { return }
            favorites.append(favorite)
        } else if let bookmark = object as? Bookmark {
            guard !bookmarks.contains(bookmark) else { return }
            bookmarks.append(bookmark)
        } else if let progress = object as? SessionProgress {
            guard !progresses.contains(progress) else { return }
            progresses.append(progress)
        }
    }

}
