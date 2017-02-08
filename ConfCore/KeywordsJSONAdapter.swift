//
//  KeywordsJSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 08/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

final class KeywordsJSONAdapter: Adapter {

    typealias InputType = JSON
    typealias OutputType = Keyword
    
    func adapt(_ input: JSON) -> Result<Keyword, AdapterError> {
        guard let name = input.string else {
            return .error(.invalidData)
        }
        
        let keyword = Keyword()
        keyword.name = name
        
        return .success(keyword)
    }
    
}
