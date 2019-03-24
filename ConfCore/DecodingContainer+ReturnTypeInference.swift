//
//  DecodingContainer+ReturnTypeInference.swift
//  ConfCore
//
//  Created by Allen Humphreys on 3/24/19.
//  Copyright © 2019 Guilherme Rambo. All rights reserved.
//

import Foundation

extension KeyedDecodingContainer {

    func decode<T: Decodable>(key: KeyedDecodingContainer.Key) throws -> T {
        return try decode(T.self, forKey: key)
    }

    func decodeIfPresent<T: Decodable>(key: KeyedDecodingContainer.Key) throws -> T? {
        return try decodeIfPresent(T.self, forKey: key)
    }
}

extension SingleValueDecodingContainer {

    public func decode<T: Decodable>() throws -> T {
        return try decode(T.self)
    }
}

extension UnkeyedDecodingContainer {

    public mutating func decode<T: Decodable>() throws -> T {
        return try decode(T.self)
    }
}
