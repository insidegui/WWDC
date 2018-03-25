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
    typealias OutputType = SessionResource

    func adapt(_ input: JSON) -> Result<SessionResource, AdapterError> {
        guard let id = input.int else {
            return .error(.invalidData)
        }

        let resource = SessionResource()
        resource.identifier = String(id)
        resource.type = .resource

        return .success(resource)
    }
}
