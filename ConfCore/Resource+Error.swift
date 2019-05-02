//
//  Resource+Error.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import Siesta

public enum APIError: Error, CustomNSError {
    case http(Error)
    case adapter
    case unknown

    public var localizedDescription: String {
        switch self {
        case let .http(error as RequestError):
            return error.userMessage
        case let .http(error):
            return error.localizedDescription
        case .adapter:
            return "Unable to process the data returned by the server"
        case .unknown:
            return "An unknown networking error occurred"
        }
    }

    public static var errorDomain: String {
        return "io.wwdc.error"
    }

    public var errorCode: Int {
        switch self {
        case .http: return 0
        case .adapter: return 1
        case .unknown: return 2
        }
    }

    /// The user-info dictionary.
    public var errorUserInfo: [String: Any] {
        var userInfo = [NSLocalizedDescriptionKey: localizedDescription]

        switch self {
        case let .http(underlying as RequestError) where underlying.cause != nil && (underlying.cause! as NSError).domain == NSURLErrorDomain:
            let underlyingUserInfo = (underlying.cause! as NSError).userInfo.compactMapValues { $0 as? String }
            userInfo.merge(underlyingUserInfo, uniquingKeysWith: { $1 })
            userInfo[NSLocalizedRecoverySuggestionErrorKey] = "Please try again"
        case let .http(underlying as RequestError) where underlying.cause != nil && underlying.cause! is DecodingError:
            userInfo[NSLocalizedRecoverySuggestionErrorKey] = "Please report this error"
        case .adapter, .unknown, .http:
            ()
        }

        return userInfo
    }
}

extension Resource {

    var error: APIError {
        if let underlyingError = latestError {
            return .http(underlyingError)
        } else {
            return .unknown
        }
    }

}
