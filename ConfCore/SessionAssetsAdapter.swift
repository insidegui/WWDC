//
//  SessionAssetsAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 08/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

final class SessionAssetsJSONAdapter: Adapter {
    
    typealias InputType = JSON
    typealias OutputType = [SessionAsset]
    
    func adapt(_ input: JSON) -> Result<[SessionAsset], AdapterError> {
        return .error(.invalidData)
    }
    
}
