//
//  Sequence+GroupedBy.swift
//  WWDC
//
//  Created by Allen Humphreys on 6/28/23.
//  Copyright © 2023 Guilherme Rambo. All rights reserved.
//

import Foundation

extension Sequence {
    @inline(__always)
    func grouped<Key>(by keyForValue: (Element) -> Key) -> [Key: [Element]] {
        Dictionary(grouping: self, by: keyForValue)
    }
}
