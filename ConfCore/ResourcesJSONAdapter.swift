//
//  ResourcesJSONAdapter.swift
//  ConfCore
//
//  Created by Ben Newcombe on 14/01/2018.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

enum ResourceKeys: String, JSONSubscriptType {
    case title, id, url, description
    case type = "resource_type"

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

class ResourcesJSONAdapter: Adapter {
    typealias InputType = JSON
    typealias OutputType = ResourceRepresentation

    func adapt(_ input: JSON) -> Result<ResourceRepresentation, AdapterError> {
        guard let id = input[ResourceKeys.id].int else {
            return .error(.missingKey(ResourceKeys.id))
        }

        guard let title = input[ResourceKeys.title].string else {
            return .error(.missingKey(ResourceKeys.title))
        }

        guard let url = input[ResourceKeys.url].string else {
            return .error(.missingKey(ResourceKeys.url))
        }

        guard let rawType = input[ResourceKeys.type].string else {
            return .error(.missingKey(ResourceKeys.type))
        }

        let resource = ResourceRepresentation()
        resource.identifier = String(id)
        resource.title = title
        resource.url = url
        resource.type = ResourceType(rawSessionType: rawType)?.rawValue ?? ""

        if let description = input[ResourceKeys.description].string {
            resource.descriptor = description
        }

        return .success(resource)
    }
}
