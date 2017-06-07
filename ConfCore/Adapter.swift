//
//  Adapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

enum AdapterError: Error {
    case invalidData
    case unsupported
    case missingKey(JSONSubscriptType)
    
    var localizedDescription: String {
        switch self {
        case .invalidData:
            return "Invalid input data"
        case .unsupported:
            return "This type of entity is not supported"
        case .missingKey(let key):
            return "Input is missing a required key: \"\(key)\""
        }
    }
}

protocol Adapter {
    associatedtype InputType
    associatedtype OutputType
    
    func adapt(_ input: InputType) -> Result<OutputType, AdapterError>
    func adapt(_ input: [InputType]) -> Result<[OutputType], AdapterError>
}

extension Adapter {
    
    func adapt(_ input: [InputType]) -> Result<[OutputType], AdapterError> {
        let collection = input.flatMap { (item: InputType) -> OutputType? in
            let itemResult = self.adapt(item)
            switch itemResult {
            case .success(let resultingItem):
                return resultingItem
            default: return nil
            }
        }
        
        return .success(collection)
    }
    
}
