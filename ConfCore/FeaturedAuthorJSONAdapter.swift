//
//  FeaturedAuthorJSONAdapter.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum FeaturedAuthorKeys: String, JSONSubscriptType {
    case name, bio, avatar, url

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class FeaturedAuthorJSONAdapter: Adapter {
    typealias InputType = JSON
    typealias OutputType = FeaturedAuthor

    func adapt(_ input: JSON) -> Result<FeaturedAuthor, AdapterError> {
        guard let name = input[FeaturedAuthorKeys.name].string else {
            return .error(.missingKey(FeaturedAuthorKeys.name))
        }

        guard let bio = input[FeaturedAuthorKeys.bio].string else {
            return .error(.missingKey(FeaturedAuthorKeys.bio))
        }

        guard let avatar = input[FeaturedAuthorKeys.avatar].string else {
            return .error(.missingKey(FeaturedAuthorKeys.avatar))
        }

        guard let url = input[FeaturedAuthorKeys.url].string else {
            return .error(.missingKey(FeaturedAuthorKeys.url))
        }

        let author = FeaturedAuthor()

        author.name = name
        author.bio = bio
        author.avatar = avatar
        author.url = url

        return .success(author)
    }
}
