//
//  Adapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

// This is needed to keep the same behavior that adapters had before
// Where it could adapt array of items even if some of the individual items failed to adapt
struct FailableItemArrayWrapper<T: Decodable>: Decodable {

    private struct Empty: Codable {}

    let items: [T]

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var items = [T]()

        while !container.isAtEnd {
            if let item = try? container.decode(T.self) {
                items.append(item)
            } else {
                // container.currentIndex is not incremented unless something is decoded
                _ = try? container.decode(Empty.self)
            }
        }

        self.items = items
    }
}
