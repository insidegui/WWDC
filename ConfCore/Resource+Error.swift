//
//  Resource+Error.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import Siesta

public enum APIError: Error {
    case http(Error)
    case adapter
    case unknown
    
    public var localizedDescription: String {
        switch self {
        case .http(let error):
            return error.localizedDescription
        case .adapter:
            return "Unable to process the data returned by the server"
        case .unknown:
            return "An unknown networking error occurred"
        }
    }
}

extension Resource {
    
    var error: APIError {
        if let underlyingError = self.latestError {
            return .http(underlyingError)
        } else {
            return .unknown
        }
    }
    
}
