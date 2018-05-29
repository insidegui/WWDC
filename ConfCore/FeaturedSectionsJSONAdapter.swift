//
//  FeaturedSectionsJSONAdapter.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON
import RealmSwift

private enum FeaturedSectionKeys: String, JSONSubscriptType {
    case ordinal, format, title, description, content, author, published
    case colorA = "ios_color"
    case colorB = "tvos_light_style_color"
    case colorC = "tvos_dark_style_color"

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class FeaturedSectionsJSONAdapter: Adapter {
    typealias InputType = JSON
    typealias OutputType = FeaturedSection

    func adapt(_ input: JSON) -> Result<FeaturedSection, AdapterError> {
        guard let contentsJSON = input[FeaturedSectionKeys.content].array else {
            return .error(.missingKey(FeaturedSectionKeys.content))
        }

        guard case .success(let contents) = FeaturedContentJSONAdapter().adapt(contentsJSON) else {
            return .error(.invalidData)
        }

        guard let ordinal = input[FeaturedSectionKeys.ordinal].int else {
            return .error(.missingKey(FeaturedSectionKeys.ordinal))
        }

        guard let title = input[FeaturedSectionKeys.title].string else {
            return .error(.missingKey(FeaturedSectionKeys.title))
        }

        guard let summary = input[FeaturedSectionKeys.description].string else {
            return .error(.missingKey(FeaturedSectionKeys.description))
        }

        let section = FeaturedSection()

        if case .success(let author) = FeaturedAuthorJSONAdapter().adapt(input[FeaturedSectionKeys.author]) {
            section.author = author
        }

        section.content.append(objectsIn: contents)
        section.order = ordinal
        section.isPublished = input[FeaturedSectionKeys.published].bool ?? true
        section.rawFormat = input[FeaturedSectionKeys.format].string ?? FeaturedSectionFormat.largeGrid.rawValue
        section.title = title
        section.summary = summary
        section.colorA = input[FeaturedSectionKeys.colorA].string
        section.colorB = input[FeaturedSectionKeys.colorB].string
        section.colorC = input[FeaturedSectionKeys.colorC].string

        return .success(section)
    }
}
