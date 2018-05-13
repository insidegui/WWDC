//
//  SessionRelatedJSONAdapter.swift
//  ConfCore
//
//  Created by Ben Newcombe on 12/01/2018.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

final class SessionRelatedJSONAdapter: Adapter {
    typealias InputType = JSON
    typealias OutputType = RelatedResource

    func adapt(_ input: JSON) -> Result<RelatedResource, AdapterError> {
        guard let id = input.int else {
            return .error(.invalidData)
        }

        let resource = RelatedResource()
        resource.identifier = String(id)
        resource.type = RelatedResourceType.unknown.rawValue

        return .success(resource)
    }
}
