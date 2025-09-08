//
//  TextualFilter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import ConfCore

struct TextualFilter: FilterType {

    var identifier: FilterIdentifier
    var value: String?
    var predicateBuilder: (String?) -> NSPredicate?

    var isEmpty: Bool {
        return predicate == nil
    }

    var predicate: NSPredicate? {
        return predicateBuilder(value)
    }

    mutating func reset() {
        value = nil
    }

    var state: State {
        State(value: value)
    }

    struct State: Codable {
        let value: String?
    }
}
