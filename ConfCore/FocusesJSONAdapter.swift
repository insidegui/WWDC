//
//  FocusesJSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 08/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

final class FocusesJSONAdapter: Adapter {
    
    typealias InputType = JSON
    typealias OutputType = Focus
    
    func adapt(_ input: JSON) -> Result<Focus, AdapterError> {
        guard let name = input.string else {
            return .error(.invalidData)
        }
        
        let focus = Focus()
        focus.name = name
        
        return .success(focus)
    }
    
}
