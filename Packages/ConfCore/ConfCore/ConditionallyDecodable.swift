//
//  ConditionallyDecodable.swift
//  ConfCore
//
//  Created by Allen Humphreys on 3/24/19.
//  Copyright © 2019 Guilherme Rambo. All rights reserved.
//

import Foundation

enum ConditionallyDecodableError: Error {
    case unsupported
    case missingKey(DecodingError)
}

protocol ConditionallyDecodable: Decodable {
    init?(conditionallyFrom decoder: Decoder) throws
}

extension ConditionallyDecodable {
    public init?(conditionallyFrom decoder: Decoder) throws {
        do {
            try self.init(from: decoder)
        } catch is ConditionallyDecodableError {
            return nil
        }
    }
}
