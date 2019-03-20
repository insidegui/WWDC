//
//  Adapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

extension KeyedDecodingContainer {

    func decode<T: Decodable>(forKey key: KeyedDecodingContainer.Key) throws -> T {
        return try decode(T.self, forKey: key)
    }

    func decodeIfPresent<T: Decodable>(forKey key: KeyedDecodingContainer.Key) throws -> T? {
        return try decodeIfPresent(T.self, forKey: key)
    }
}

enum ConditionallyDecodableError: Error {
    case unsupported
    case missingKey(DecodingError)
}

protocol ConditionallyDecodable: Decodable {}

// A wrapper that allows items within the collection to fail to decode for specific reasons
struct ConditionallyDecodableCollection<T: ConditionallyDecodable>: Decodable {

    private struct Empty: Codable {}

    fileprivate let items: [T]

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var items = [T]()

        while !container.isAtEnd {
            do {
                items.append(try container.decode(T.self))
            } catch is ConditionallyDecodableError {
                // Advance the container
                _ = try container.decode(Empty.self)
            }
        }

        self.items = items
    }
}

extension ConditionallyDecodableCollection: Collection {
    typealias Element = T
    typealias Index = Int

    var startIndex: Int { return items.startIndex }

    var endIndex: Int { return items.endIndex }

    func index(after i: Int) -> Int {
        return items.index(after: i)
    }

    subscript(position: Int) -> T {
        return items[position]
    }
}

extension Array where Element: ConditionallyDecodable {
    init(_ conditionallyDecodableCollection: ConditionallyDecodableCollection<Element>) {
        self.init(conditionallyDecodableCollection.items)
    }
}
